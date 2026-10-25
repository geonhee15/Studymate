import AppKit

/// STUDYMATE_DEBUG_KEYS: feeds key events through the normal event queue (so the local key monitors, menus and
/// first responder all see them) and logs the app state after each step. Steps, comma separated:
///   a single character ("c", "1", "n", "h", " "), esc, enter, space, cmd+z, shift+cmd+z,
///   focus       make the scratch canvas / text view first responder, as a click into the panel would
///   draw        drag a short stroke on the scratch canvas (mouse events straight into the view)
///   wait        nothing, just a pause
@MainActor
enum DebugDriver {
    static func run(_ script: String, appState: AppState) {
        let steps = script.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        step(0, steps, appState: appState)
    }

    private static func step(_ i: Int, _ steps: [String], appState: AppState) {
        guard i < steps.count else {
            NSLog("Studymate debug keys: done")
            return
        }
        let s = steps[i]
        switch s {
        case "focus": focusScratch()
        case "draw": drawStroke()
        case "line": drawStroke(shift: true)
        case "erase": drawStroke(eraser: true)
        case "stress": (appState.session?.scratch ?? appState.mockSession?.currentScratch)?.addStressStrokes(1500)
        case "wait": break
        case "esc": post(key: "\u{1b}", code: 53)
        case "enter": post(key: "\r", code: 36)
        case "space": post(key: " ", code: 49)
        case "cmd+z": post(key: "z", code: 6, flags: .command)
        case "shift+cmd+z": post(key: "z", code: 6, flags: [.command, .shift])
        default: post(key: s, code: keyCode(for: s))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            MainActor.assumeIsolated {
                log(after: s, appState: appState)
                step(i + 1, steps, appState: appState)
            }
        }
    }

    private static func log(after s: String, appState: AppState) {
        let responder = NSApp.keyWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
        var state = "open=\(appState.scratch.isOpen) focused=\(appState.scratch.focused) responder=\(responder)"
        if let session = appState.session {
            let last = session.scratch.pad.strokes.last.map { "\($0.pointCount)pts\($0.eraser ? " eraser" : "")" } ?? "-"
            state += " selected=\(session.selected ?? "-") submitted=\(session.submitted) hints=\(session.hintsRevealed) lang=\(session.language.rawValue) strokes=\(session.scratch.strokeCount) last=\(last) redo=\(session.scratch.redoStack.count) text=\(session.scratch.pad.text.count) sheet=\(session.pendingReview != nil)"
        }
        state += " mistakes=\(appState.mistakes.entries.count) lastScratch=\(appState.mistakes.entries.last?.scratchID?.uuidString.prefix(8) ?? "-")"
        if let mock = appState.mockSession {
            state += " answer=\(mock.answers[mock.currentNumber] ?? "-") number=\(mock.currentNumber) strokes=\(mock.currentScratch?.strokeCount ?? -1)"
        }
        NSLog("Studymate debug keys: after '%@': %@", s, state)
    }

    private static func keyCode(for s: String) -> UInt16 {
        let table: [String: UInt16] = ["a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "n": 45, "t": 17,
                                       "1": 18, "2": 19, "3": 20, "4": 21, "5": 23]
        return table[s.lowercased()] ?? 0
    }

    private static func post(key: String, code: UInt16, flags: NSEvent.ModifierFlags = []) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
        let time = ProcessInfo.processInfo.systemUptime
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let e = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: time, windowNumber: window.windowNumber,
                                        context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code) {
                NSApp.postEvent(e, atStart: false)
            }
        }
    }

    private static func scratchView() -> NSView? {
        guard let root = (NSApp.keyWindow ?? NSApp.windows.first)?.contentView else { return nil }
        func find(_ v: NSView) -> NSView? {
            if v is ScratchCanvasNSView || v is ScratchTextNSView { return v }
            for sub in v.subviews { if let hit = find(sub) { return hit } }
            return nil
        }
        return find(root)
    }

    private static func focusScratch() {
        guard let view = scratchView() else { NSLog("Studymate debug keys: no scratch view to focus"); return }
        view.window?.makeFirstResponder(view)
    }

    private static func drawStroke(shift: Bool = false, eraser: Bool = false) {
        guard let canvas = scratchView() as? ScratchCanvasNSView, let window = canvas.window else { NSLog("Studymate debug keys: no canvas"); return }
        canvas.tool = eraser ? .eraser : .pen
        // Eraser / line runs cross the middle of whatever is drawn; plain strokes go near the bottom (and grow the page).
        let start = eraser ? CGPoint(x: 30, y: 150) : shift ? CGPoint(x: 30, y: min(canvas.bounds.height - 40, 300)) : CGPoint(x: 40, y: canvas.bounds.height - 60)
        let origin = canvas.convert(start, to: nil)
        func event(_ type: NSEvent.EventType, _ dx: CGFloat, _ dy: CGFloat) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: CGPoint(x: origin.x + dx, y: origin.y + dy), modifierFlags: shift ? [.shift] : [],
                               timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                               eventNumber: 0, clickCount: 1, pressure: 0.6)
        }
        let started = CFAbsoluteTimeGetCurrent()
        if let e = event(.leftMouseDown, 0, 0) { canvas.mouseDown(with: e) }
        for i in 1...12 {
            if let e = event(.leftMouseDragged, CGFloat(i) * (eraser || shift ? 22 : 9), CGFloat(i % 3) * 4) { canvas.mouseDragged(with: e) }
        }
        if let e = event(.leftMouseUp, eraser || shift ? 270 : 110, 6) { canvas.mouseUp(with: e) }
        canvas.displayIfNeeded()
        NSLog("Studymate debug keys: stroke of 13 events incl. redraw took %.2f ms", (CFAbsoluteTimeGetCurrent() - started) * 1000)
    }
}
