import Foundation

enum WhisperArtifactFilter {
    static func shouldDiscard(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { return true }
        // Whisper can return a single period or ellipsis for non-speech audio.
        let nonPunctuation = CharacterSet.punctuationCharacters
            .union(.whitespacesAndNewlines)
            .union(.controlCharacters)
            .inverted
        if normalized.rangeOfCharacter(from: nonPunctuation) == nil { return true }
        // Match whole artifact transcripts; do not delete fragments of valid speech.
        let patterns = [
            #"(?is)^субтитры\s+создавал.*$"#,
            #"(?is)^редактор\s+субтитров.*$"#,
            #"(?is)^продолжение\s+следует.*$"#,
            #"(?is)^.*\bdimatorzok\b.*$"#,
            // At least three identical words, with optional punctuation between them.
            #"(?iu)^([\p{L}\p{N}]+)(?:[\s\p{P}]+\1){2,}[\s\p{P}]*$"#
        ]
        return patterns.contains { normalized.range(of: $0, options: .regularExpression) != nil }
    }
}
