import Foundation

struct StreamingDeltaBuffer {
    private let interval: Duration
    private var lastYield: ContinuousClock.Instant
    private var pending = ""

    init(now: ContinuousClock.Instant, interval: Duration = .milliseconds(50)) {
        self.interval = interval
        lastYield = now
    }

    mutating func append(_ delta: String, now: ContinuousClock.Instant) -> String? {
        pending += delta
        guard lastYield.duration(to: now) >= interval else { return nil }
        lastYield = now
        return flush()
    }

    mutating func flush() -> String? {
        guard !pending.isEmpty else { return nil }
        defer { pending = "" }
        return pending
    }
}

struct ProviderClient: Sendable {
    func taskSchedule(
        model: String,
        apiKey: String,
        tasks: [ScreenieTask]
    ) async throws -> TaskSchedule {
        var request = URLRequest(url: AIProvider.openRouter.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ProviderRequestBuilder.taskScheduleRequestBody(
            model: model,
            tasks: tasks
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.requestFailed(String(data: data, encoding: .utf8) ?? "Request failed")
        }
        return try TaskSchedule.decodeOpenRouterResponse(data)
    }

    func stream(
        provider: AIProvider,
        model: String,
        apiKey: String,
        messages: [ChatMessage],
        ocrText: String = "",
        imageData: Data? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                var buffer = StreamingDeltaBuffer(now: clock.now)
                do {
                    var request = URLRequest(url: provider.endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: ProviderRequestBuilder.requestBody(
                        provider: provider,
                        model: model,
                        messages: messages,
                        ocrText: ocrText,
                        imageData: imageData
                    ))

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        let message = String(data: body, encoding: .utf8) ?? "Request failed"
                        throw ProviderError.requestFailed(message)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let dataLine = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if let delta = SSEDecoder.delta(from: dataLine, provider: provider),
                           let chunk = buffer.append(delta, now: clock.now) {
                            continuation.yield(chunk)
                        }
                    }
                    if let chunk = buffer.flush() {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    if let chunk = buffer.flush() {
                        continuation.yield(chunk)
                    }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
