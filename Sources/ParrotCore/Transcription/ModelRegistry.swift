import Foundation

/// Built-in transcription model registry.
///
/// The model list lives directly in source rather than as a JSON resource so
/// the binary stays self-contained — no `Bundle.module` lookup, no per-target
/// resource bundle to ship alongside the executable.
package enum ModelRegistry {
    static let shared: [TranscriptionModel] = [
        TranscriptionModel(
            id: "whisper-base.en",
            displayName: "Whisper Base (English)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-base.en",
            sizeMB: 145,
            languages: ["en"],
            recommended: true
        ),
        TranscriptionModel(
            id: "whisper-large-v3-turbo",
            displayName: "Whisper Large v3 Turbo",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-large-v3-v20240930_turbo",
            sizeMB: 1620,
            languages: ["multi"],
            recommended: false
        ),
        TranscriptionModel(
            id: "whisper-small.en",
            displayName: "Whisper Small (English)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-small.en",
            sizeMB: 488,
            languages: ["en"],
            recommended: false
        ),
        TranscriptionModel(
            id: "whisper-small",
            displayName: "Whisper Small",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-small",
            sizeMB: 490,
            languages: ["multi"],
            recommended: false
        ),
        TranscriptionModel(
            id: "whisper-base",
            displayName: "Whisper Base",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-base",
            sizeMB: 147,
            languages: ["multi"],
            recommended: false
        ),
        TranscriptionModel(
            id: "whisper-large-v3-turbo-632mb",
            displayName: "Whisper Large v3 Turbo (Compressed)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-large-v3-v20240930_turbo_632MB",
            sizeMB: 646,
            languages: ["multi"],
            recommended: false
        ),
        TranscriptionModel(
            id: "whisper-large-v3-626mb",
            displayName: "Whisper Large v3 (Compressed)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-large-v3-v20240930_626MB",
            sizeMB: 627,
            languages: ["multi"],
            recommended: false
        ),
        TranscriptionModel(
            id: "whisper-distil-large-v3-turbo-600mb",
            displayName: "Whisper Distil Large v3 Turbo (Compressed)",
            engine: .whisperKit,
            whisperKitID: "distil-whisper_distil-large-v3_turbo_600MB",
            sizeMB: 607,
            languages: ["multi"],
            recommended: false
        ),
    ]

    package static func find(_ id: String) -> TranscriptionModel? {
        shared.first { $0.id == id }
    }

    package static func recommended() -> TranscriptionModel? {
        shared.first { $0.recommended } ?? shared.first
    }
}
