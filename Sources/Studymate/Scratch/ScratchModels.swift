import AppKit
import SwiftUI

/// Pen colors. Stored by raw value; the ink color follows light/dark mode when drawn.
enum ScratchColor: Int, Codable, CaseIterable, Identifiable {
    case ink = 0, red = 1, blue = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .ink: return "기본"
        case .red: return "빨강"
        case .blue: return "파랑"
        }
    }

    func nsColor(dark: Bool) -> NSColor {
        switch self {
        case .ink: return dark ? NSColor(white: 0.93, alpha: 1) : NSColor(white: 0.13, alpha: 1)
        case .red: return NSColor(srgbRed: 0.90, green: 0.26, blue: 0.23, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.22, green: 0.46, blue: 0.95, alpha: 1)
        }
    }

    func color(_ scheme: ColorScheme) -> Color { Color(nsColor: nsColor(dark: scheme == .dark)) }
}

enum ScratchPen: Int, Codable, CaseIterable {
    case thin = 0, thick = 1

    var width: Double {
        switch self {
        case .thin: return 2.0
        case .thick: return 4.2
        }
    }

    var title: String { self == .thin ? "가는 펜" : "굵은 펜" }
}

enum ScratchTool: String {
    case pen, eraser
}

enum ScratchMode: String, CaseIterable, Identifiable {
    case draw, text

    var id: String { rawValue }
    var title: String { self == .draw ? "그리기" : "텍스트" }
}

/// One pen or eraser stroke. Points are x, y, pressure triples in canvas points (origin top-left).
/// Pressure is 0.5 when the input device has none (mouse, trackpad); Apple Pencil over Sidecar gives 0...1.
struct ScratchStroke: Codable, Equatable {
    var points: [Double]
    var color: ScratchColor
    /// Base line width in points; the pressure scales it (see StrokePainter.widthFactor).
    var width: Double
    var eraser: Bool

    static let eraserWidth = 18.0
    static let neutralPressure = 0.5

    var pointCount: Int { points.count / 3 }

    func point(_ i: Int) -> CGPoint { CGPoint(x: points[i * 3], y: points[i * 3 + 1]) }
    func pressure(_ i: Int) -> Double { points[i * 3 + 2] }

    /// Widest the stroke can get, for dirty rects and bounds.
    var maxWidth: Double { eraser ? width : width * StrokePainter.widthFactor(1) }

    var bounds: CGRect {
        guard pointCount > 0 else { return .null }
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for i in 0..<pointCount {
            let p = point(i)
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let pad = maxWidth / 2 + 1
        return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + 2 * pad, height: maxY - minY + 2 * pad)
    }
}

/// Where the problem's figure is laid under the strokes (canvas points).
struct ScratchFigure: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

/// One scratch pad: one problem, one attempt. Saved as scratch/<problemID>/<id>.json.
struct ScratchPad: Codable, Identifiable, Equatable {
    var id: UUID
    var problemID: String
    var kind: ProblemSetKind
    var date: Date
    var strokes: [ScratchStroke] = []
    var text = ""
    var figure: ScratchFigure?
    /// Width of the canvas the strokes were drawn on, so a thumbnail can keep the proportions.
    var canvasWidth: Double

    var isEmpty: Bool { strokes.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasDrawing: Bool { !strokes.isEmpty || figure != nil }

    /// Union of all strokes and the figure, or nil for a blank pad.
    var contentBounds: CGRect? {
        var r = CGRect.null
        for s in strokes where !s.eraser { r = r.union(s.bounds) }
        if let f = figure { r = r.union(f.rect) }
        return r.isNull ? nil : r
    }
}
