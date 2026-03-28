import Foundation

enum ProviderValidation {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var message: String {
        switch self {
            case .valid: ""
            case let .invalid(reason): reason
        }
    }
}

enum TranscriptionState: Equatable {
    case idle
    case recording
    case transcribing
    case correcting
    case inserting
    case selectingScreenshots

    var displayText: String {
        switch self {
            case .idle: String(localized: "Ready")
            case .recording: String(localized: "Recording...")
            case .transcribing: String(localized: "Transcribing...")
            case .correcting: String(localized: "Correcting...")
            case .inserting: String(localized: "Inserting text...")
            case .selectingScreenshots: String(localized: "Select screenshots")
        }
    }

    var isActive: Bool {
        self != .idle
    }
}

enum ModelState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case loading
    case ready
    case error(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

enum RecordingMode: String, CaseIterable, Codable {
    case pushToTalk
    case toggle

    var displayName: String {
        switch self {
            case .pushToTalk: String(localized: "Push to Talk")
            case .toggle: String(localized: "Toggle")
        }
    }

    var description: String {
        switch self {
            case .pushToTalk: String(localized: "Hold key to record, release to transcribe")
            case .toggle: String(localized: "Press to start, press again to stop")
        }
    }
}

enum CorrectionMode: String, CaseIterable, Codable {
    case standard
    case fillerRemoval
    case structured
    case custom

    var displayName: String {
        switch self {
            case .standard: "Standard (STT Correction)"
            case .fillerRemoval: "Filler Removal"
            case .structured: "Structured"
            case .custom: "Custom"
        }
    }

    var description: String {
        switch self {
            case .standard: "Fix STT errors: spacing, punctuation, misheard words"
            case .fillerRemoval: "STT correction + remove fillers (음, 어, 그러니까)"
            case .structured: "STT correction + filler removal + organize with bullet points"
            case .custom: "Use your own custom system prompt"
        }
    }

    // Migration: "promptEngineering" → .fillerRemoval
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if rawValue == "promptEngineering" {
            self = .fillerRemoval
        } else {
            self = CorrectionMode(rawValue: rawValue) ?? .standard
        }
    }
}

enum SupportedLanguage: String, CaseIterable, Codable {
    case auto
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"

    var displayName: String {
        switch self {
            case .auto: String(localized: "Auto-detect")
            case .korean: "한국어"
            case .english: "English"
            case .japanese: "日本語"
            case .chinese: "中文"
            case .spanish: "Español"
            case .french: "Français"
            case .german: "Deutsch"
            case .portuguese: "Português"
        }
    }
}
