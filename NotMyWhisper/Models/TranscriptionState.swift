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
        case .valid: return ""
        case .invalid(let reason): return reason
        }
    }
}

enum TranscriptionState: Equatable {
    case idle
    case recording
    case transcribing
    case correcting
    case inserting

    var displayText: String {
        switch self {
        case .idle: return String(localized: "Ready")
        case .recording: return String(localized: "Recording...")
        case .transcribing: return String(localized: "Transcribing...")
        case .correcting: return String(localized: "Correcting...")
        case .inserting: return String(localized: "Inserting text...")
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
    case pushToTalk = "pushToTalk"
    case toggle = "toggle"

    var displayName: String {
        switch self {
        case .pushToTalk: return String(localized: "Push to Talk")
        case .toggle: return String(localized: "Toggle")
        }
    }

    var description: String {
        switch self {
        case .pushToTalk: return String(localized: "Hold key to record, release to transcribe")
        case .toggle: return String(localized: "Press to start, press again to stop")
        }
    }
}

enum CorrectionMode: String, CaseIterable, Codable {
    case standard = "standard"
    case promptEngineering = "promptEngineering"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .standard: return "Standard (STT Correction)"
        case .promptEngineering: return "Prompt Formatting"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Fix STT errors: spacing, punctuation, misheard words"
        case .promptEngineering: return "Format speech into well-structured prompts for LLMs"
        case .custom: return "Use your own custom system prompt"
        }
    }
}

enum SupportedLanguage: String, CaseIterable, Codable {
    case auto = "auto"
    case korean = "ko"
    case english = "en"

    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto-detect")
        case .korean: return "한국어"
        case .english: return "English"
        }
    }
}
