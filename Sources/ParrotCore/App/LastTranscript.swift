/// The most recently delivered transcript, kept in memory only.
struct LastTranscript {
    private(set) var text: String?

    mutating func update(_ value: String) {
        guard !value.isEmpty else { return }
        text = value
    }
}
