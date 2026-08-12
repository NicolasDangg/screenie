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

    @MainActor
    func testStartingNewConversationClearsTransientState() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "history.json")
        let model = AppModel(settings: AppSettings(), history: ChatHistoryStore(fileURL: fileURL))
        model.prompt = "Draft"
        model.conversation = Conversation(
            title: "Old topic",
            messages: [ChatMessage(role: .assistant, text: "Old answer")]
        )
        model.streamingResponse = "Partial"
        model.errorMessage = "Error"

        model.startNewConversation()

        XCTAssertEqual(model.prompt, "")
        XCTAssertEqual(model.conversation.title, "New Chat")
        XCTAssertTrue(model.conversation.messages.isEmpty)
        XCTAssertEqual(model.streamingResponse, "")
        XCTAssertEqual(model.errorMessage, "")
    }

    func testSuggestionsHaveConcretePrompts() {
        XCTAssertEqual(PromptSuggestion.explain.prompt, "Explain this question")
        XCTAssertEqual(PromptSuggestion.summarize.prompt, "Summarize what is on my screen")
        XCTAssertEqual(PromptSuggestion.findBug.prompt, "Find the bug in the code on my screen and explain the fix")
    }

    func testOpenAIPayloadDisablesStorageAndIncludesBothContexts() throws {
        let messages = [
            ChatMessage(role: .user, text: "What does this function do?"),
            ChatMessage(role: .assistant, text: "It parses a response."),
            ChatMessage(role: .user, text: "Explain the selected line")
        ]
        let body = ProviderRequestBuilder.requestBody(
            provider: .openAI,
            model: "gpt-4.1-mini",
            messages: messages,
            ocrText: "What is 2 + 2?",
            imageData: Data([1, 2, 3])
        )

        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: body).count > 0)
        let json = String(data: try JSONSerialization.data(withJSONObject: body), encoding: .utf8)!
        XCTAssertTrue(json.contains("What is 2 + 2?"))
        XCTAssertTrue(json.contains("It parses a response."))
        let input = body["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        let imageURL = content?.last?["image_url"] as? String
        XCTAssertTrue(imageURL?.hasPrefix("data:image/jpeg;base64,") == true)

        let titleBody = ProviderRequestBuilder.requestBody(
            provider: .openAI,
            model: "gpt-4.1-mini",
            messages: [ChatMessage(role: .user, text: "Generate a short title")]
        )
        let titleJSON = String(data: try JSONSerialization.data(withJSONObject: titleBody), encoding: .utf8)!
        XCTAssertFalse(titleJSON.contains("data:image"))
    }

    func testSSEDecoderReadsProviderDeltas() {
        let openAI = #"{"type":"response.output_text.delta","delta":"Hello"}"#
        let openRouter = #"{"choices":[{"delta":{"content":"World"}}]}"#

        XCTAssertEqual(SSEDecoder.delta(from: openAI, provider: .openAI), "Hello")
        XCTAssertEqual(SSEDecoder.delta(from: openRouter, provider: .openRouter), "World")
        XCTAssertNil(SSEDecoder.delta(from: "[DONE]", provider: .openAI))
    }
}
