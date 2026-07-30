import Foundation

/// A small local retry queue for encrypted files whose owning SwiftData record
/// was already removed. It contains only opaque references, never plaintext or
/// attachment metadata, and is deliberately device-local.
@MainActor
final class EncryptedContentCleanupQueue {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.aistudio.socialbrain.pending-encrypted-cleanup"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func enqueue(_ reference: LocalEncryptedContentReference) {
        var queued = references
        if !queued.contains(reference) {
            queued.append(reference)
            write(queued)
        }
    }

    /// Best-effort cleanup is intentionally non-throwing. A failed file stays
    /// queued for the next app launch or capture operation.
    func drain(using store: LocalEncryptedContentStore) {
        var remaining: [LocalEncryptedContentReference] = []
        for reference in references {
            do {
                try store.delete(reference)
            } catch {
                remaining.append(reference)
            }
        }
        write(remaining)
    }

    func removeAll() {
        defaults.removeObject(forKey: key)
    }

    private var references: [LocalEncryptedContentReference] {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([LocalEncryptedContentReference].self, from: data)
        else {
            return []
        }
        return values
    }

    private func write(_ values: [LocalEncryptedContentReference]) {
        guard !values.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: key)
    }
}
