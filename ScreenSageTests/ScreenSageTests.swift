import XCTest
@testable import ScreenSage

final class ScreenSageTests: XCTestCase {
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
