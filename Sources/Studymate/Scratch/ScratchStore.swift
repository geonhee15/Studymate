import AppKit
import Observation

/// Scratch pads on disk: <data dir>/scratch/<problemID>/<padID>.json, one file per attempt. Writes are debounced
/// per pad; blank pads that were never saved are not written at all.
@MainActor
@Observable
final class ScratchStore {
    let root: URL
    /// Bumps after every write so thumbnails re-render.
    private(set) var revision = 0

    @ObservationIgnored private var pending: [UUID: DispatchWorkItem] = [:]
    @ObservationIgnored private var padCache: [UUID: ScratchPad] = [:]
    @ObservationIgnored private var thumbCache: [String: NSImage] = [:]

    init() {
        root = DataDirectory.url.appendingPathComponent("scratch", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func url(problemID: String, id: UUID) -> URL {
        root.appendingPathComponent(Self.folderName(problemID), isDirectory: true).appendingPathComponent(id.uuidString + ".json")
    }

    /// Problem ids are "5-3-2" / "m1-12"; anything odd is sanitised so it stays a single path component.
    private static func folderName(_ problemID: String) -> String {
        String(problemID.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? Character($0) : "_" })
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    func load(problemID: String, id: UUID) -> ScratchPad? {
        if let hit = padCache[id] { return hit }
        guard let data = try? Data(contentsOf: url(problemID: problemID, id: id)) else { return nil }
        do {
            let pad = try Self.decoder.decode(ScratchPad.self, from: data)
            padCache[id] = pad
            return pad
        } catch {
            NSLog("Studymate: failed to decode scratch \(id): \(error)")
            return nil
        }
    }

    /// A saved, non-blank pad for this attempt?
    func hasContent(problemID: String, id: UUID?) -> Bool {
        guard let id, let pad = load(problemID: problemID, id: id) else { return false }
        return !pad.isEmpty
    }

    /// Every saved pad of a problem, newest first.
    func pads(problemID: String) -> [ScratchPad] {
        let dir = root.appendingPathComponent(Self.folderName(problemID), isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .compactMap { file -> ScratchPad? in
                guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else { return nil }
                return load(problemID: problemID, id: id)
            }
            .filter { !$0.isEmpty }
            .sorted { $0.date > $1.date }
    }

    /// Coalesces a burst of strokes into one write.
    func save(_ pad: ScratchPad, immediately: Bool = false) {
        let target = url(problemID: pad.problemID, id: pad.id)
        if pad.isEmpty && !FileManager.default.fileExists(atPath: target.path) { return }
        padCache[pad.id] = pad
        thumbCache = thumbCache.filter { !$0.key.hasPrefix(pad.id.uuidString) }
        pending[pad.id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            do {
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try Self.encoder.encode(pad)
                try data.write(to: target, options: .atomic)
            } catch {
                NSLog("Studymate: failed to save scratch \(pad.id): \(error)")
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pending[pad.id] = nil
                self.revision += 1
            }
        }
        pending[pad.id] = work
        if immediately {
            work.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        }
    }

    func flush() {
        for (_, work) in pending where !work.isCancelled { work.perform() }
        pending.removeAll()
    }

    /// Thumbnail of a saved pad, cached per size and appearance. `figure` is the problem's SVG, if any.
    func thumbnail(for pad: ScratchPad, figureSVG: String?, size: CGSize, dark: Bool) -> NSImage? {
        let key = "\(pad.id.uuidString)|\(Int(size.width))x\(Int(size.height))|\(dark ? "d" : "l")"
        if let hit = thumbCache[key] { return hit }
        let figure = (pad.figure != nil ? figureSVG : nil).flatMap { FigureImage.image(svg: $0, dark: dark) }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = StrokePainter.render(pad, figure: figure, size: size, scale: scale, dark: dark) else { return nil }
        thumbCache[key] = image
        return image
    }
}
