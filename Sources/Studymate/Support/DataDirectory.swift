import Foundation

/// Where user data lives: ~/Library/Application Support/Studymate, or STUDYMATE_DEBUG_DATA_DIR for screenshots/tests.
enum DataDirectory {
    static let url: URL = {
        let dir: URL
        if let override = ProcessInfo.processInfo.environment["STUDYMATE_DEBUG_DATA_DIR"], !override.isEmpty {
            dir = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            dir = base.appendingPathComponent("Studymate", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var isDebugOverride: Bool {
        !(ProcessInfo.processInfo.environment["STUDYMATE_DEBUG_DATA_DIR"] ?? "").isEmpty
    }
}

/// One JSON file holding a Codable value, with debounced atomic writes.
@MainActor
final class JSONFile<Value: Codable> {
    let url: URL
    private var pending: DispatchWorkItem?

    init(name: String) {
        url = DataDirectory.url.appendingPathComponent(name)
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            NSLog("Studymate: failed to decode \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    /// Coalesces bursts of changes into one write half a second later.
    func save(_ value: Value, immediately: Bool = false) {
        pending?.cancel()
        let work = DispatchWorkItem { [url] in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            do {
                let data = try encoder.encode(value)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Studymate: failed to save \(url.lastPathComponent): \(error)")
            }
        }
        pending = work
        if immediately {
            work.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    func flush() {
        if let pending, !pending.isCancelled { pending.perform(); self.pending = nil }
    }
}
