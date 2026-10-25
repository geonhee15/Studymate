import AppKit
import SwiftUI

/// Free-hand drawing surface. Finished strokes live in a bitmap the view blits; the stroke being drawn goes into
/// the same bitmap one short curve at a time, so a mouse move costs one quad segment plus a redraw of its rect
/// no matter how many strokes the page already holds. Undo, redo, clear and the figure underlay re-render
/// the bitmap from the stroke list.
final class ScratchCanvasNSView: NSView {
    var document: ScratchDocument? {
        didSet {
            guard document !== oldValue else { return }
            live = nil
            renderedVersion = -1
            cacheValid = false
            enclosingScrollView?.contentView.scroll(to: .zero)
            fitHeight()
            needsDisplay = true
        }
    }
    var tool: ScratchTool = .pen {
        didSet { if tool != oldValue { window?.invalidateCursorRects(for: self) } }
    }
    var pen: ScratchPen = .thin
    var color: ScratchColor = .ink
    var onFocusChange: ((Bool) -> Void)?
    private(set) var renderedVersion = -1

    private var buffer: UnsafeMutableRawPointer?
    private var bufferSize = 0
    private var cache: CGContext?
    private var cacheSize = CGSize.zero
    private var cacheScale: CGFloat = 0
    private var cacheValid = false

    private var live: ScratchStroke?
    private var liveStart = CGPoint.zero
    private var straight = false
    private var previewRect = CGRect.null

    static let maxHeight: CGFloat = 8000
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    deinit { buffer?.deallocate() }

    private var isDark: Bool { effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    // MARK: Cache

    private func ensureCache() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let size = bounds.size
        guard size.width >= 1, size.height >= 1 else { return }
        if cache == nil || cacheSize != size || cacheScale != scale { allocate(size, scale: scale) }
        if !cacheValid || renderedVersion != (document?.version ?? -1) { rebuild() }
    }

    private func allocate(_ size: CGSize, scale: CGFloat) {
        let w = max(1, Int(size.width * scale)), h = max(1, Int(size.height * scale))
        let bytesPerRow = w * 4
        let n = bytesPerRow * h
        let fresh = UnsafeMutableRawPointer.allocate(byteCount: n, alignment: 16)
        // The paper only ever grows or shrinks at the bottom while drawing. Same width and scale → the old rows are
        // the top rows of the new bitmap (row 0 is the top in memory), so copy them instead of re-rendering strokes.
        var preserved = false
        if let old = buffer, let oldCtx = cache, cacheValid, oldCtx.width == w, cacheScale == scale {
            let keep = min(bufferSize, n)
            memcpy(fresh, old, keep)
            if n > keep { memset(fresh + keep, 0, n - keep) }
            preserved = true
        } else {
            memset(fresh, 0, n)
        }
        buffer?.deallocate()
        buffer = fresh
        bufferSize = n
        cache = CGContext(data: fresh, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                          space: Self.colorSpace, bitmapInfo: Self.bitmapInfo)
        // Same y-down coordinates as the (flipped) view.
        cache?.translateBy(x: 0, y: CGFloat(h))
        cache?.scaleBy(x: scale, y: -scale)
        cache?.setAllowsAntialiasing(true)
        cache?.setShouldAntialias(true)
        cacheSize = size
        cacheScale = scale
        cacheValid = preserved
    }

    private func rebuild() {
        guard let cache else { return }
        cache.clear(CGRect(origin: .zero, size: cacheSize))
        let dark = isDark
        if let document {
            for s in document.pad.strokes { StrokePainter.draw(s, in: cache, dark: dark) }
        }
        // A stroke in progress is not in the document yet; keep what was drawn so far.
        if let live, !straight { StrokePainter.draw(live, in: cache, dark: dark) }
        cacheValid = true
        renderedVersion = document?.version ?? -1
    }

    /// The bitmap as an image sharing the buffer (no copy); drawn clipped to the dirty rect.
    private func cacheImage() -> CGImage? {
        guard let buffer, let cache else { return nil }
        guard let provider = CGDataProvider(dataInfo: nil, data: buffer, size: bufferSize, releaseData: { _, _, _ in }) else { return nil }
        return CGImage(width: cache.width, height: cache.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cache.bytesPerRow,
                       space: Self.colorSpace, bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo), provider: provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ensureCache()
        let dark = isDark
        if let document, let f = document.pad.figure, let svg = document.figureSVG, f.rect.intersects(dirtyRect),
           let image = FigureImage.image(svg: svg, dark: dark) {
            StrokePainter.drawFigure(image, in: f.rect, ctx: ctx)
        }
        if let image = cacheImage() {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(origin: .zero, size: bounds.size))
            ctx.restoreGState()
        }
        if straight, let live, live.pointCount >= 2 {
            // Shift-line preview; the line is committed to the cache on mouse up.
            if live.eraser {
                ctx.setBlendMode(.normal)
                ctx.setStrokeColor(CGColor(gray: 0.5, alpha: 0.45))
                ctx.setLineWidth(live.width)
                ctx.setLineCap(.round)
                ctx.beginPath()
                ctx.move(to: live.point(0))
                ctx.addLine(to: live.point(1))
                ctx.strokePath()
            } else {
                StrokePainter.draw(live, in: ctx, dark: dark)
            }
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // ensureCache sees the size change and reallocates (keeping the pixels when only the height changed).
        if let document, newSize.width > 0 {
            let w = Double(newSize.width)
            DispatchQueue.main.async { document.noteCanvasWidth(w) }
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        cacheValid = false
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        cacheValid = false
        needsDisplay = true
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        fitHeight()
    }

    /// Keeps a margin of blank paper under the lowest stroke so the page grows as it fills up.
    func fitHeight() {
        guard let scroll = enclosingScrollView else { return }
        let visible = scroll.contentView.bounds.height
        let contentMax = document?.pad.contentBounds?.maxY ?? 0
        let liveMax = live?.bounds.maxY ?? 0
        let wanted = min(Self.maxHeight, max(visible, max(contentMax, liveMax) + 260))
        if abs(wanted - frame.height) > 0.5 { setFrameSize(NSSize(width: frame.width, height: wanted)) }
    }

    // MARK: Focus and keys

    override func becomeFirstResponder() -> Bool {
        onFocusChange?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        onFocusChange?(false)
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Single keys are the problem screen's shortcuts; while drawing they do nothing here and must not reach it.
        if event.keyCode == 53 { window?.makeFirstResponder(nil) }
    }

    @objc func undo(_ sender: Any?) { document?.undo() }
    @objc func redo(_ sender: Any?) { document?.redo() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: tool == .eraser ? Self.eraserCursor : .crosshair)
    }

    private static let eraserCursor: NSCursor = {
        let d = ScratchStroke.eraserWidth + 2
        let image = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
            ring.lineWidth = 1.5
            NSColor.white.withAlphaComponent(0.9).setStroke()
            ring.stroke()
            let inner = NSBezierPath(ovalIn: rect.insetBy(dx: 2.5, dy: 2.5))
            inner.lineWidth = 1
            NSColor.black.withAlphaComponent(0.8).setStroke()
            inner.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: d / 2, y: d / 2))
    }()

    // MARK: Mouse

    private func pressure(_ event: NSEvent) -> Double {
        // Apple Pencil over Sidecar (and graphics tablets) arrive as tablet points with 0...1 pressure;
        // a mouse or trackpad gets the neutral value.
        if event.subtype == .tabletPoint { return Double(min(1, max(0.05, event.pressure))) }
        return ScratchStroke.neutralPressure
    }

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        onFocusChange?(true)
        guard document != nil else { return }
        let p = convert(event.locationInWindow, from: nil)
        liveStart = p
        straight = event.modifierFlags.contains(.shift)
        let eraser = tool == .eraser
        live = ScratchStroke(points: [p.x, p.y, pressure(event)], color: color,
                             width: eraser ? ScratchStroke.eraserWidth : pen.width, eraser: eraser)
        previewRect = .null
        ensureCache()
    }

    override func mouseDragged(with event: NSEvent) {
        guard var stroke = live else { return }
        let p = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.shift) { straight = true }
        if straight {
            stroke.points = [liveStart.x, liveStart.y, stroke.pressure(0), p.x, p.y, pressure(event)]
            live = stroke
            let r = stroke.bounds.union(previewRect)
            previewRect = stroke.bounds
            setNeedsDisplay(r)
            return
        }
        let last = stroke.point(stroke.pointCount - 1)
        guard hypot(p.x - last.x, p.y - last.y) >= 1.2 else { return }
        stroke.points += [p.x, p.y, pressure(event)]
        live = stroke
        if p.y > frame.height - 80 { fitHeight() }   // rebuilds the cache with the live stroke included
        ensureCache()
        guard let cache else { return }
        let dirty = StrokePainter.drawLatest(stroke, in: cache, dark: isDark)
        setNeedsDisplay(dirty)
    }

    override func mouseUp(with event: NSEvent) {
        guard var stroke = live else { return }
        ensureCache()
        guard let cache else { live = nil; return }
        if straight {
            if stroke.pointCount == 1 { stroke.points += [stroke.point(0).x + 0.5, stroke.point(0).y, stroke.pressure(0)] }
            live = nil
            StrokePainter.draw(stroke, in: cache, dark: isDark)
            setNeedsDisplay(stroke.bounds.union(previewRect))
            previewRect = .null
        } else {
            let dirty = StrokePainter.drawTail(stroke, in: cache, dark: isDark)
            live = nil
            setNeedsDisplay(dirty)
        }
        straight = false
        document?.add(stroke)
        fitHeight()
    }
}

extension ScratchCanvasNSView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undo(_:)) { return document?.canUndo ?? false }
        if menuItem.action == #selector(redo(_:)) { return document?.canRedo ?? false }
        return true
    }
}

/// The canvas inside a vertical scroll view.
struct ScratchCanvas: NSViewRepresentable {
    let document: ScratchDocument
    /// Passed explicitly so SwiftUI updates the view after undo / redo / clear.
    var version: Int
    var tool: ScratchTool
    var pen: ScratchPen
    var color: ScratchColor
    var onFocusChange: (Bool) -> Void

    final class Coordinator {
        var observer: NSObjectProtocol?
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        let canvas = ScratchCanvasNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
        canvas.autoresizingMask = [.width]
        scroll.documentView = canvas
        scroll.contentView.postsFrameChangedNotifications = true
        context.coordinator.observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: scroll.contentView, queue: .main) { [weak canvas] _ in
            MainActor.assumeIsolated { canvas?.fitHeight() }
        }
        apply(to: canvas)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let canvas = scroll.documentView as? ScratchCanvasNSView else { return }
        apply(to: canvas)
    }

    private func apply(to canvas: ScratchCanvasNSView) {
        canvas.onFocusChange = onFocusChange
        canvas.tool = tool
        canvas.pen = pen
        canvas.color = color
        canvas.document = document
        if canvas.renderedVersion != version { canvas.needsDisplay = true }
    }
}
