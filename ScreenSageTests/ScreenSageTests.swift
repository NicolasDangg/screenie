import XCTest
@testable import ScreenSage

final class ScreenSageTests: XCTestCase {
    @MainActor
    func testHistoryRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let fileURL = directory.appending(path: "history.json")
        let message = ChatMessage(role: .user, text: "Explain this code")
        let conversation = Conversation(title: "SwiftUI Overlay", messages: [message])

        let store = ChatHistoryStore(fileURL: fileURL)
        store.upsert(conversation)
        let reloaded = ChatHistoryStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.conversations, [conversation])
        let json = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(json.contains("imageData"))
        XCTAssertFalse(json.contains("ocrText"))
    }

    func testConversationTitleCleanup() {
        XCTAssertEqual(
            Conversation.cleanedTitle("\"SwiftUI overlay corners\"", fallbackPrompt: "Explain this"),
            "SwiftUI overlay corners"
        )
        XCTAssertEqual(
            Conversation.cleanedTitle("", fallbackPrompt: "Explain why this SwiftUI overlay has corners today"),
            "Explain why this SwiftUI overlay has"
        )
    }

    @MainActor
    func testOverlayPanelTogglesPresentedState() {
        let controller = OverlayPanelController(model: AppModel(settings: AppSettings()))

        XCTAssertFalse(controller.isPresented)
        controller.toggle()
        XCTAssertTrue(controller.isPresented)
        controller.toggle()
        XCTAssertFalse(controller.isPresented)
    }

    func testSuggestionsHaveConcretePrompts() {
        XCTAssertEqual(PromptSuggestion.explain.prompt, "Explain this question")
        XCTAssertEqual(PromptSuggestion.summarize.prompt, "Summarize what is on my screen")
        XCTAssertEqual(PromptSuggestion.findBug.prompt, "Find the bug in the code on my screen and explain the fix")
    }

    func testOpenAIPayloadDisablesStorageAndIncludesBothContexts() throws {
        let body = ProviderRequestBuilder.requestBody(
            provider: .openAI,
            model: "gpt-4.1-mini",
            prompt: "Explain this question",
            ocrText: "What is 2 + 2?",
            imageData: Data([1, 2, 3])
        )

        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: body).count > 0)
        let json = String(data: try JSONSerialization.data(withJSONObject: body), encoding: .utf8)!
        XCTAssertTrue(json.contains("What is 2 + 2?"))
        let input = body["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        let imageURL = content?.last?["image_url"] as? String
        XCTAssertTrue(imageURL?.hasPrefix("data:image/jpeg;base64,") == true)
    }

    func testSSEDecoderReadsProviderDeltas() {
        let openAI = #"{"type":"response.output_text.delta","delta":"Hello"}"#
        let openRouter = #"{"choices":[{"delta":{"content":"World"}}]}"#

        XCTAssertEqual(SSEDecoder.delta(from: openAI, provider: .openAI), "Hello")
        XCTAssertEqual(SSEDecoder.delta(from: openRouter, provider: .openRouter), "World")
        XCTAssertNil(SSEDecoder.delta(from: "[DONE]", provider: .openAI))
    }
}
