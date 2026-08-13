import Foundation

enum ProviderRequestBuilder {
    static let selfStudyPeriods = """
    Monday: Period 4 (10:45-11:30), Period 5B-7 (12:45-15:25), each period 45 minutes
    Tuesday: Period 1 (08:00-08:45), Period 5B (12:45-13:30)
    Thursday: Period 3-4 (09:55-11:30)
    Friday: Period 6 (13:35-14:20)
    """

    static func requestBody(
        provider: AIProvider,
        model: String,
        messages: [ChatMessage],
        ocrText: String = "",
        imageData: Data? = nil
    ) -> [String: Any] {
        var text = messages.map { message in
            "\(message.role == .user ? "User" : "Assistant"): \(message.text)"
        }.joined(separator: "\n\n")
        if !ocrText.isEmpty {
            text += "\n\nText recognized locally from the current screen:\n\(ocrText)"
        }
        let imageURL = imageData.map { "data:image/jpeg;base64,\($0.base64EncodedString())" }

        switch provider {
        case .openAI:
            var content: [[String: Any]] = [["type": "input_text", "text": text]]
            if let imageURL {
                content.append(["type": "input_image", "image_url": imageURL, "detail": "auto"])
            }
            return [
                "model": model,
                "store": false,
                "stream": true,
                "input": [[
                    "role": "user",
                    "content": content
                ]]
            ]
        case .openRouter:
            var content: [[String: Any]] = [["type": "text", "text": text]]
            if let imageURL {
                content.append(["type": "image_url", "image_url": ["url": imageURL]])
            }
            return [
                "model": model,
                "stream": true,
                "messages": [[
                    "role": "user",
                    "content": content
                ]]
            ]
        }
    }

    static func taskScheduleRequestBody(
        model: String,
        tasks: [ScreenieTask],
        now: Date = .now,
        timeZone: TimeZone = .current
    ) -> [String: Any] {
        let incompleteTasks = tasks.filter { !$0.isCompleted }.map { task in
            if let dueDate = task.dueDate {
                "- \(task.title), due \(dueDate.ISO8601Format())"
            } else {
                "- \(task.title), no due date"
            }
        }.joined(separator: "\n")
        let prompt = """
        Suggest concrete study blocks for these tasks using only the available self-study periods. Respect due dates and do not schedule in the past.

        Current time: \(now.ISO8601Format())
        Time zone: \(timeZone.identifier)

        Available self-study periods:
        \(selfStudyPeriods)

        Incomplete tasks:
        \(incompleteTasks)
        """
        let suggestionSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "taskTitle": ["type": "string", "description": "Exact task title"],
                "start": ["type": "string", "format": "date-time"],
                "end": ["type": "string", "format": "date-time"],
                "note": ["type": "string", "description": "Why this block fits"]
            ],
            "required": ["taskTitle", "start", "end", "note"],
            "additionalProperties": false
        ]
        return [
            "model": model,
            "stream": false,
            "provider": ["require_parameters": true],
            "messages": [["role": "user", "content": prompt]],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "task_schedule",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "properties": [
                            "summary": ["type": "string"],
                            "suggestions": ["type": "array", "items": suggestionSchema]
                        ],
                        "required": ["summary", "suggestions"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]
    }
}
