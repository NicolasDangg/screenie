import AppKit
import Foundation
import Observation
import Security

struct AppRelease: Equatable, Sendable {
    let version: String
    let notes: String
    let pageURL: URL
    let downloadURL: URL

    /// Decodes GitHub's "latest release" payload, picking the macOS zip asset.
    static func decode(_ data: Data) throws -> AppRelease {
        struct Payload: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: URL
            }
            let tag_name: String
            let body: String?
            let html_url: URL
            let assets: [Asset]
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let asset = payload.assets.first(where: { $0.name.hasSuffix("-macos.zip") }) else {
            throw AppUpdater.UpdateError.missingDownload
        }
        return AppRelease(
            version: normalizedVersion(payload.tag_name),
            notes: payload.body ?? "",
            pageURL: payload.html_url,
            downloadURL: asset.browser_download_url
        )
    }

    static func normalizedVersion(_ version: String) -> String {
        version.hasPrefix("v") ? String(version.dropFirst()) : version
    }

    /// Compares dotted numeric versions, treating missing components as zero.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = normalizedVersion(candidate).split(separator: ".").map { Int($0) ?? 0 }
        let rhs = normalizedVersion(current).split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}

@MainActor
@Observable
final class AppUpdater {
    enum UpdateError: LocalizedError {
        case missingDownload
        case requestFailed
        case invalidBundle
        case signatureMismatch
        case notWritable

        var errorDescription: String? {
            switch self {
            case .missingDownload: "The latest release has no macOS download."
            case .requestFailed: "Couldn't reach GitHub."
            case .invalidBundle: "The download didn't contain screenie.app."
            case .signatureMismatch: "The download isn't signed by the same developer, so it wasn't installed."
            case .notWritable: "screenie can't replace itself here. Move it to /Applications and try again."
            }
        }
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case installing
        case failed(String)
    }

    static let shared = AppUpdater()
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/NicolasDangg/screenie/releases/latest")!

    private(set) var state = State.idle

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func checkForUpdates() async {
        state = .checking
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError.requestFailed
            }
            let release = try AppRelease.decode(data)
            state = AppRelease.isVersion(release.version, newerThan: currentVersion) ? .available(release) : .upToDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func install(_ release: AppRelease) async {
        state = .installing
        do {
            let installedApp = Bundle.main.bundleURL
            let folder = installedApp.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: folder.path) else { throw UpdateError.notWritable }

            let (zip, _) = try await URLSession.shared.download(from: release.downloadURL)
            let staging = FileManager.default.temporaryDirectory
                .appending(path: "screenie-update-\(UUID().uuidString)", directoryHint: .isDirectory)
            try await Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, staging.path])

            let newApp = staging.appending(path: installedApp.lastPathComponent)
            guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw UpdateError.invalidBundle
            }
            guard Self.isSignedLikeRunningApp(newApp) else { throw UpdateError.signatureMismatch }

            // Stage beside the installed app so the final swap is a same-volume move.
            let pending = folder.appending(path: ".\(installedApp.lastPathComponent).update")
            try? FileManager.default.removeItem(at: pending)
            try await Self.run("/usr/bin/ditto", [newApp.path, pending.path])
            try? FileManager.default.removeItem(at: staging)

            try Self.relaunch(replacing: installedApp, with: pending)
            (NSApp.delegate as? AppDelegate)?.requestTermination()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Accepts only code that satisfies the running app's designated requirement,
    /// so an update must come from the same signing identity and bundle identifier.
    private static func isSignedLikeRunningApp(_ url: URL) -> Bool {
        var selfCode: SecCode?
        var selfStatic: SecStaticCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
              SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic,
              SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(url as CFURL, [], &candidate) == errSecSuccess, let candidate
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidityWithErrors(candidate, flags, requirement, nil) == errSecSuccess
    }

    /// Waits for this process to exit, swaps the bundles, and reopens the app.
    private static func relaunch(replacing installedApp: URL, with pending: URL) throws {
        let script = """
        while /bin/kill -0 "$0" 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf "$1" && /bin/mv "$2" "$1" && /usr/bin/open "$1"
        """
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script, "\(ProcessInfo.processInfo.processIdentifier)", installedApp.path, pending.path]
        try process.run()
    }

    private static func run(_ executable: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(filePath: executable)
            process.arguments = arguments
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError.invalidBundle)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
