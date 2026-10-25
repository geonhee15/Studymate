import Foundation
import Observation

/// The scratch pad being edited for one problem of one session: strokes, text, figure underlay, undo stack.
/// Saves through the store on every change.
@MainActor
@Observable
final class ScratchDocument {
    private(set) var pad: ScratchPad
    private(set) var redoStack: [ScratchStroke] = []
    /// Bumps whenever the canvas must re-render everything (undo, redo, clear, figure toggle). Plain stroke
    /// additions do not bump it: the canvas drew them itself as they were made.
    private(set) var version = 0
    let figureSVG: String?

    @ObservationIgnored private let store: ScratchStore

    init(problem: Problem, kind: ProblemSetKind, store: ScratchStore, canvasWidth: Double) {
        self.store = store
        self.figureSVG = problem.figure
        pad = ScratchPad(id: UUID(), problemID: problem.id, kind: kind, date: Date(), canvasWidth: canvasWidth)
    }

    var id: UUID { pad.id }
    var problemID: String { pad.problemID }
    var isEmpty: Bool { pad.isEmpty }
    var canUndo: Bool { !pad.strokes.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var hasFigure: Bool { figureSVG != nil }
    var figureShown: Bool { pad.figure != nil }
    var strokeCount: Int { pad.strokes.count }

    /// Called by the canvas after it has drawn the stroke.
    func add(_ stroke: ScratchStroke) {
        guard stroke.pointCount > 0 else { return }
        pad.strokes.append(stroke)
        redoStack.removeAll()
        changed()
    }

    func undo() {
        guard let last = pad.strokes.popLast() else { return }
        redoStack.append(last)
        version += 1
        changed()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        pad.strokes.append(next)
        version += 1
        changed()
    }

    func clearDrawing() {
        guard !pad.strokes.isEmpty || pad.figure != nil else { return }
        pad.strokes.removeAll()
        pad.figure = nil
        redoStack.removeAll()
        version += 1
        changed()
    }

    func setText(_ text: String) {
        guard text != pad.text else { return }
        pad.text = text
        changed()
    }

    /// Lays the problem figure under the strokes (or removes it).
    func toggleFigure(canvasWidth: Double) {
        if pad.figure != nil {
            pad.figure = nil
        } else {
            guard let svg = figureSVG, let image = FigureImage.image(svg: svg, dark: false) else { return }
            pad.figure = FigureImage.placement(size: image.size, canvasWidth: canvasWidth > 0 ? canvasWidth : pad.canvasWidth)
        }
        version += 1
        changed()
    }

    /// The canvas reports its width so thumbnails keep the proportions. Not a content change.
    func noteCanvasWidth(_ width: Double) {
        guard width > 0, abs(width - pad.canvasWidth) > 0.5 else { return }
        pad.canvasWidth = width
    }

    func flush() { store.save(pad, immediately: true) }

    private func changed() { store.save(pad) }

    // MARK: Debug sample

    /// Strokes that look like a quick hand sketch, for snapshots (STUDYMATE_DEBUG_SCRATCH=sample).
    func addSampleStrokes() {
        let w = pad.canvasWidth > 0 ? pad.canvasWidth : 360
        let left = max(24, (w - 300) / 2)
        func line(_ pts: [(Double, Double)], _ color: ScratchColor, _ pen: ScratchPen, wobble: Double = 1.2, steps: Int = 6) -> ScratchStroke {
            var out: [Double] = []
            var seed = 7.0
            func noise() -> Double { seed = (seed * 9301 + 49297).truncatingRemainder(dividingBy: 233280); return seed / 233280 - 0.5 }
            for i in 0..<(pts.count - 1) {
                let (x0, y0) = pts[i], (x1, y1) = pts[i + 1]
                for s in 0..<steps {
                    let t = Double(s) / Double(steps)
                    let pressure = 0.35 + 0.4 * (0.5 + 0.5 * sin(Double(i * steps + s) * 0.7))
                    out += [left + x0 + (x1 - x0) * t + noise() * wobble, y0 + (y1 - y0) * t + noise() * wobble, pressure]
                }
            }
            out += [left + pts.last!.0, pts.last!.1, 0.45]
            return ScratchStroke(points: out, color: color, width: pen.width, eraser: false)
        }
        func circle(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ color: ScratchColor) -> ScratchStroke {
            var out: [Double] = []
            for i in 0...40 {
                let a = Double(i) / 40 * 2 * .pi - .pi / 2
                out += [left + cx + rx * cos(a) * (1 + 0.03 * sin(a * 3)), cy + ry * sin(a), 0.5 + 0.25 * sin(a)]
            }
            return ScratchStroke(points: out, color: color, width: ScratchPen.thin.width, eraser: false)
        }
        let top = (pad.figure?.rect.maxY ?? 20) + 24
        // A triangle with its height, a right-angle mark, and the base split in two.
        pad.strokes.append(line([(30, top + 120), (250, top + 120), (120, top + 10), (30, top + 120)], .ink, .thick))
        pad.strokes.append(line([(120, top + 12), (120, top + 118)], .red, .thin))
        pad.strokes.append(line([(120, top + 106), (132, top + 106), (132, top + 118)], .red, .thin, wobble: 0.5, steps: 3))
        pad.strokes.append(line([(60, top + 70), (72, top + 62)], .blue, .thin, steps: 3))
        pad.strokes.append(line([(176, top + 62), (188, top + 70)], .blue, .thin, steps: 3))
        // "handwriting": a few short wavy runs under the figure, then the answer circled.
        var y = top + 160
        for row in 0..<3 {
            var pts: [(Double, Double)] = []
            var x = 36.0
            let len = [210.0, 150.0, 120.0][row]
            var i = 0
            while x < 36 + len {
                pts.append((x, y + (i % 2 == 0 ? -6 : 6) + Double(i % 3) * 1.5))
                x += 9
                i += 1
            }
            pad.strokes.append(line(pts, .ink, .thin, wobble: 0.8, steps: 3))
            y += 30
        }
        pad.strokes.append(circle(200, y - 30, 30, 16, .red))
        version += 1
        changed()
    }

    /// Many random strokes at once (STUDYMATE_DEBUG_KEYS=stress) to check the canvas stays quick.
    func addStressStrokes(_ count: Int) {
        let w = pad.canvasWidth > 0 ? pad.canvasWidth : 360
        var seed = 11.0
        func rnd() -> Double { seed = (seed * 9301 + 49297).truncatingRemainder(dividingBy: 233280); return seed / 233280 }
        for _ in 0..<count {
            var pts: [Double] = []
            var x = 10 + rnd() * (w - 20), y = 10 + rnd() * 1200
            for _ in 0..<24 {
                x = min(max(4, x + (rnd() - 0.5) * 16), w - 4)
                y = max(4, y + (rnd() - 0.5) * 16)
                pts += [x, y, 0.3 + rnd() * 0.6]
            }
            pad.strokes.append(ScratchStroke(points: pts, color: ScratchColor.allCases[Int(rnd() * 3) % 3], width: ScratchPen.thin.width, eraser: false))
        }
        redoStack.removeAll()
        version += 1
        changed()
    }

    static let sampleText = """
    밑변 7 + 15 = 22, 높이 6
    (7 + 15) × 6 / 2 = 66

    빗변 10 → 10^2 - 6^2 = 64 → 8
    15 - 7 = 8  (맞음)

    답 66 → (C)
    """
}
