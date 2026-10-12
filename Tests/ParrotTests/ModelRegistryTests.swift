import XCTest
@testable import ParrotCore

final class ModelRegistryTests: XCTestCase {
    func testEveryEntryResolvesAndHasAnEngineID() {
        for m in ModelRegistry.shared {
            XCTAssertNotNil(ModelRegistry.find(m.id), m.id)
            XCTAssertNotNil(m.whisperKitID, m.id)
            XCTAssertEqual(m.engine, .whisperKit, m.id)
        }
    }

    func testIDsAreUniqueAndExactlyOneIsRecommended() {
        let ids = ModelRegistry.shared.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ModelRegistry.shared.filter(\.recommended).count, 1)
        XCTAssertEqual(ModelRegistry.recommended()?.id, "whisper-base.en")
    }

    func testCompressedLargeVariantsAreMultilingual() {
        for id in [
            "whisper-large-v3-turbo-632mb",
            "whisper-large-v3-626mb",
            "whisper-distil-large-v3-turbo-600mb",
            "whisper-base",
        ] {
            let m = try? XCTUnwrap(ModelRegistry.find(id))
            XCTAssertTrue(m?.isMultilingual == true, id)
        }
    }

    func testCompressedVariantsUseSupportedWhisperKitIDs() {
        XCTAssertEqual(
            ModelRegistry.find("whisper-large-v3-turbo-632mb")?.whisperKitID,
            "openai_whisper-large-v3-v20240930_turbo_632MB"
        )
        XCTAssertEqual(
            ModelRegistry.find("whisper-large-v3-626mb")?.whisperKitID,
            "openai_whisper-large-v3-v20240930_626MB"
        )
        XCTAssertEqual(
            ModelRegistry.find("whisper-distil-large-v3-turbo-600mb")?.whisperKitID,
            "distil-whisper_distil-large-v3_turbo_600MB"
        )
        XCTAssertEqual(ModelRegistry.find("whisper-base")?.whisperKitID, "openai_whisper-base")
    }
}
