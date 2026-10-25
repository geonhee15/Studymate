import AppKit
import SwiftUI

/// Plain monospaced text for working out calculations by hand. No substitutions, no spell check, no smart
/// anything: what you type is what stays, like pencil on the test's scratch paper.
final class ScratchTextNSView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}

struct ScratchTextEditor: NSViewRepresentable {
    let document: ScratchDocument
    var onFocusChange: (Bool) -> Void

    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: ScratchDocument
        var documentID: UUID
        init(document: ScratchDocument) {
            self.document = document
            documentID = document.id
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            document.setText(tv.string)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(document: document) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder

        let tv = ScratchTextNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainerInset = NSSize(width: 10, height: 12)
        tv.drawsBackground = false
        tv.isRichText = false
        tv.importsGraphics = false
        tv.usesFontPanel = false
        tv.usesFindBar = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.font = Self.font
        tv.textColor = .labelColor
        tv.typingAttributes = [.font: Self.font, .foregroundColor: NSColor.labelColor]
        tv.delegate = context.coordinator
        tv.onFocusChange = onFocusChange
        tv.string = document.pad.text
        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? ScratchTextNSView else { return }
        tv.onFocusChange = onFocusChange
        let coordinator = context.coordinator
        if coordinator.documentID != document.id {
            coordinator.document = document
            coordinator.documentID = document.id
            tv.string = document.pad.text
            tv.undoManager?.removeAllActions()
            tv.typingAttributes = [.font: Self.font, .foregroundColor: NSColor.labelColor]
            scroll.contentView.scroll(to: .zero)
        } else if tv.string != document.pad.text && tv.window?.firstResponder !== tv {
            tv.string = document.pad.text
        }
    }
}
