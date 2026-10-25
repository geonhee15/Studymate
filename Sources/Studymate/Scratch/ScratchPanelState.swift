import AppKit
import Observation

/// Scratch pad panel: open state, width, mode and tools (remembered), plus whether keyboard focus is inside it
/// (the problem screen's single-key shortcuts are off while it is).
@MainActor
@Observable
final class ScratchPanelState {
    static let minWidth = 300.0
    static let maxWidth = 760.0

    var isOpen: Bool {
        didSet { remember(isOpen, "scratchOpen") }
    }
    var width: Double {
        didSet { remember(width, "scratchWidth") }
    }
    var mode: ScratchMode {
        didSet { remember(mode.rawValue, "scratchMode") }
    }
    var pen: ScratchPen {
        didSet { remember(pen.rawValue, "scratchPen") }
    }
    var color: ScratchColor {
        didSet { remember(color.rawValue, "scratchColor") }
    }
    var tool: ScratchTool = .pen
    /// The canvas or the text view is first responder.
    var focused = false

    init() {
        // Snapshot / dev runs (STUDYMATE_DEBUG_DATA_DIR) start from the defaults and leave the real preferences alone.
        if DataDirectory.isDebugOverride {
            isOpen = false
            width = 380
            mode = .draw
            pen = .thin
            color = .ink
            return
        }
        let d = UserDefaults.standard
        isOpen = d.bool(forKey: "scratchOpen")
        let w = d.double(forKey: "scratchWidth")
        width = w > 0 ? min(Self.maxWidth, max(Self.minWidth, w)) : 380
        mode = ScratchMode(rawValue: d.string(forKey: "scratchMode") ?? "") ?? .draw
        pen = ScratchPen(rawValue: d.integer(forKey: "scratchPen")) ?? .thin
        color = ScratchColor(rawValue: d.integer(forKey: "scratchColor")) ?? .ink
    }

    private func remember(_ value: Any, _ key: String) {
        guard !DataDirectory.isDebugOverride else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    func toggle() {
        if isOpen { releaseFocus() }
        isOpen.toggle()
    }

    /// Esc: back to the problem, shortcuts on again.
    func releaseFocus() {
        for window in NSApp.windows {
            if let responder = window.firstResponder, responder is ScratchCanvasNSView || responder is ScratchTextNSView {
                window.makeFirstResponder(nil)
            }
        }
        focused = false
    }

    enum KeyDisposition {
        /// Handled here; drop the event.
        case consumed
        /// Belongs to the panel (typing, drawing); let it through untouched, the screen's shortcuts stay quiet.
        case passThrough
        /// Not the panel's business.
        case unhandled
    }

    /// First stop of the problem screens' key monitors. While the panel has focus, only Esc (back to the problem) and
    /// ⌘Z / ⇧⌘Z on the drawing are acted on; everything else is the panel's. With focus elsewhere, ⌘Z / ⇧⌘Z still undo
    /// the drawing while it is on screen, unless a text field is being edited.
    func intercept(_ event: NSEvent, document: ScratchDocument?, textFieldActive: Bool) -> KeyDisposition {
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let undoKey = chars == "z" && (mods == [.command] || mods == [.command, .shift])
        if focused {
            if event.keyCode == 53, mods.isEmpty {
                releaseFocus()
                return .consumed
            }
            if undoKey, mode == .draw, let document {
                if mods.contains(.shift) { document.redo() } else { document.undo() }
                return .consumed
            }
            return .passThrough
        }
        if undoKey, isOpen, mode == .draw, !textFieldActive, let document {
            if mods.contains(.shift) { document.redo() } else { document.undo() }
            return .consumed
        }
        return .unhandled
    }

    func clampWidth(_ w: Double) -> Double { min(Self.maxWidth, max(Self.minWidth, w)) }
}
