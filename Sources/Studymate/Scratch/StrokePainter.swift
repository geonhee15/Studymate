import AppKit

/// Draws strokes into a CGContext. Shared by the live canvas (incremental, segment by segment) and the
/// thumbnail / viewer renderer (whole pad at once), so both look identical.
///
/// A stroke with n points is n segments: p0 → m01, then m(k-1,k) → m(k,k+1) curving through p_k, then
/// m(n-2,n-1) → p(n-1). Each segment takes its width from the pressure of the point it passes through, and the
/// round caps hide the seams, so pressure changes read as a smoothly thickening line.
enum StrokePainter {
    /// Pressure 0.5 (no pressure data) → 1.0; a hard Pencil press → 1.45, a light one → 0.6.
    static func widthFactor(_ pressure: Double) -> Double { 0.55 + 0.9 * min(1, max(0.05, pressure)) }

    /// Full stroke. A mouse / trackpad stroke has one width throughout, so it goes down as a single path; only
    /// pressure-varying (Pencil) strokes are stroked segment by segment.
    static func draw(_ stroke: ScratchStroke, in ctx: CGContext, dark: Bool) {
        let n = stroke.pointCount
        guard n > 0 else { return }
        prepare(ctx, stroke: stroke, dark: dark)
        if n == 1 {
            dot(stroke, in: ctx)
        } else if stroke.eraser || uniformPressure(stroke) {
            ctx.setLineWidth(lineWidth(stroke, at: 0))
            ctx.beginPath()
            ctx.move(to: stroke.point(0))
            ctx.addLine(to: mid(stroke.point(0), stroke.point(1)))
            if n > 2 {
                for k in 1..<(n - 1) { ctx.addQuadCurve(to: mid(stroke.point(k), stroke.point(k + 1)), control: stroke.point(k)) }
            }
            ctx.addLine(to: stroke.point(n - 1))
            ctx.strokePath()
        } else {
            for k in 0..<n { segment(stroke, k, in: ctx) }
        }
        ctx.setBlendMode(.normal)
    }

    private static func uniformPressure(_ stroke: ScratchStroke) -> Bool {
        let first = stroke.pressure(0)
        for i in 1..<stroke.pointCount where abs(stroke.pressure(i) - first) > 0.01 { return false }
        return true
    }

    /// Live drawing: the segment that becomes determined when point `n-1` arrives (count == n).
    /// Returns the rect to redraw.
    @discardableResult
    static func drawLatest(_ stroke: ScratchStroke, in ctx: CGContext, dark: Bool) -> CGRect {
        let n = stroke.pointCount
        guard n >= 2 else { return .null }
        prepare(ctx, stroke: stroke, dark: dark)
        let k = n == 2 ? 0 : n - 2
        let rect = segment(stroke, k, in: ctx)
        ctx.setBlendMode(.normal)
        return rect
    }

    /// Live drawing: the tail (or the dot of a single-point stroke) when the mouse goes up.
    @discardableResult
    static func drawTail(_ stroke: ScratchStroke, in ctx: CGContext, dark: Bool) -> CGRect {
        let n = stroke.pointCount
        guard n > 0 else { return .null }
        prepare(ctx, stroke: stroke, dark: dark)
        let rect = n == 1 ? dot(stroke, in: ctx) : segment(stroke, n - 1, in: ctx)
        ctx.setBlendMode(.normal)
        return rect
    }

    // MARK: Pieces

    private static func prepare(_ ctx: CGContext, stroke: ScratchStroke, dark: Bool) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        if stroke.eraser {
            ctx.setBlendMode(.clear)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        } else {
            ctx.setBlendMode(.normal)
            let c = stroke.color.nsColor(dark: dark).cgColor
            ctx.setStrokeColor(c)
            ctx.setFillColor(c)
        }
    }

    private static func lineWidth(_ stroke: ScratchStroke, at i: Int) -> CGFloat {
        stroke.eraser ? stroke.width : stroke.width * widthFactor(stroke.pressure(i))
    }

    private static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }

    @discardableResult
    private static func dot(_ stroke: ScratchStroke, in ctx: CGContext) -> CGRect {
        let p = stroke.point(0)
        let w = lineWidth(stroke, at: 0)
        let r = CGRect(x: p.x - w / 2, y: p.y - w / 2, width: w, height: w)
        ctx.fillEllipse(in: r)
        return r.insetBy(dx: -2, dy: -2)
    }

    /// Segment k of 0..<n; returns its dirty rect.
    @discardableResult
    private static func segment(_ stroke: ScratchStroke, _ k: Int, in ctx: CGContext) -> CGRect {
        let n = stroke.pointCount
        let from: CGPoint, to: CGPoint, control: CGPoint?, w: CGFloat
        if k == 0 {
            from = stroke.point(0); to = mid(stroke.point(0), stroke.point(1)); control = nil
            w = lineWidth(stroke, at: 0)
        } else if k == n - 1 {
            from = mid(stroke.point(n - 2), stroke.point(n - 1)); to = stroke.point(n - 1); control = nil
            w = lineWidth(stroke, at: n - 1)
        } else {
            from = mid(stroke.point(k - 1), stroke.point(k)); to = mid(stroke.point(k), stroke.point(k + 1))
            control = stroke.point(k)
            w = lineWidth(stroke, at: k)
        }
        ctx.setLineWidth(w)
        ctx.beginPath()
        ctx.move(to: from)
        if let control { ctx.addQuadCurve(to: to, control: control) } else { ctx.addLine(to: to) }
        ctx.strokePath()
        var r = CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
        if let control { r = r.union(CGRect(origin: control, size: .zero)) }
        return r.insetBy(dx: -(w / 2 + 2), dy: -(w / 2 + 2))
    }

    // MARK: Whole pad → image

    /// Renders the pad (figure underlay + strokes) into an image that fits `size`, keeping proportions.
    /// `region` defaults to the content bounds with a margin; thumbnails pass nil, the viewer passes the full canvas.
    static func render(_ pad: ScratchPad, figure: NSImage?, size: CGSize, scale: CGFloat, dark: Bool, region: CGRect? = nil) -> NSImage? {
        guard var area = region ?? pad.contentBounds?.insetBy(dx: -12, dy: -12) else { return nil }
        if area.width < 40 { area = area.insetBy(dx: -(40 - area.width) / 2, dy: 0) }
        if area.height < 30 { area = area.insetBy(dx: 0, dy: -(30 - area.height) / 2) }
        let fit = min(size.width / area.width, size.height / area.height)
        let drawn = CGSize(width: area.width * fit, height: area.height * fit)
        let pixelW = max(1, Int(drawn.width * scale)), pixelH = max(1, Int(drawn.height * scale))
        guard let ctx = CGContext(data: nil, width: pixelW, height: pixelH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        // Flip so the pad's top-left origin matches.
        ctx.translateBy(x: 0, y: CGFloat(pixelH))
        ctx.scaleBy(x: scale * fit, y: -scale * fit)
        ctx.translateBy(x: -area.minX, y: -area.minY)
        ctx.setAllowsAntialiasing(true)
        ctx.interpolationQuality = .high
        if let f = pad.figure, let figure {
            drawFigure(figure, in: f.rect, ctx: ctx)
        }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for s in pad.strokes { draw(s, in: ctx, dark: dark) }
        ctx.endTransparencyLayer()
        guard let cg = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cg, size: drawn)
    }

    /// The figure underlay, faint so pen strokes stay readable on top of it. `ctx` is flipped (y down).
    static func drawFigure(_ image: NSImage, in rect: CGRect, ctx: CGContext) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        ctx.saveGState()
        ctx.setAlpha(0.42)
        // CGImage draws y-up; undo the flip inside the figure's rect.
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }
}

/// Problem figures (inline SVG from the content) as NSImage for the underlay. `currentColor` has no meaning
/// outside the web view, so it is replaced by a gray that works on the current appearance.
@MainActor
enum FigureImage {
    private static var cache: [String: NSImage] = [:]

    static func image(svg: String, dark: Bool) -> NSImage? {
        let key = "\(dark ? "d" : "l")\(svg.hashValue)"
        if let hit = cache[key] { return hit }
        let gray = dark ? "#D0D0D4" : "#404044"
        let prepared = svg.replacingOccurrences(of: "currentColor", with: gray)
        guard let data = prepared.data(using: .utf8), let image = NSImage(data: data), image.size.width > 0 else { return nil }
        cache[key] = image
        return image
    }

    /// Where a figure of `size` goes on a canvas of `width`: centered near the top, enlarged a little, never wider than the paper.
    static func placement(size: CGSize, canvasWidth: Double) -> ScratchFigure {
        let maxW = max(80, canvasWidth - 32)
        let w = min(size.width * 1.25, maxW)
        let h = w * size.height / max(1, size.width)
        return ScratchFigure(x: ((canvasWidth - w) / 2).rounded(), y: 18, w: w.rounded(), h: h.rounded())
    }
}
