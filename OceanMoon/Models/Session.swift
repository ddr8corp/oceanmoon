import Foundation
import SwiftData

@Model
final class Session {
    var title: String
    var createdAt: Date
    var isActive: Bool
    @Relationship(deleteRule: .cascade) var utterances: [Utterance]

    init(title: String = "新しい会話", createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
        self.isActive = true
        self.utterances = []
    }

    var duration: TimeInterval {
        guard let first = utterances.sorted(by: { $0.timestamp < $1.timestamp }).first else { return 0 }
        guard let last = utterances.sorted(by: { $0.timestamp < $1.timestamp }).last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    var preview: String {
        utterances
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { $0.text.isEmpty ? nil : $0.text }
            .joined(separator: " ")
    }
}

@Model
final class Utterance {
    var text: String
    var timestamp: Date
    var offsetSeconds: TimeInterval
    var speakerIndex: Int

    init(text: String, timestamp: Date = .now, offsetSeconds: TimeInterval = 0, speakerIndex: Int = 0) {
        self.text = text
        self.timestamp = timestamp
        self.offsetSeconds = offsetSeconds
        self.speakerIndex = speakerIndex
    }

    var formattedOffset: String {
        let total = Int(offsetSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
