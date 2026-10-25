import AppKit
import SwiftUI

/// The scratch pad beside a problem: draw or type, like the scratch paper at the real test.
struct ScratchPanel: View {
    @Bindable var appState: AppState
    let document: ScratchDocument
    @State private var confirmClear = false
    @Environment(\.colorScheme) private var scheme

    private var state: ScratchPanelState { appState.scratch }

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.mode == .draw { drawToolbar }
            paper
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            footer
        }
        .frame(maxHeight: .infinity)
        .background(Theme.hoverFill(scheme).opacity(0.5))
        .confirmationDialog("그림을 전부 지울까요?", isPresented: $confirmClear) {
            Button("전부 지우기", role: .destructive) { document.clearDrawing() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌릴 수 없어요.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(get: { state.mode }, set: { state.mode = $0 })) {
                ForEach(ScratchMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            Spacer()
            if state.focused {
                Chip(text: "입력 중 · Esc", color: Theme.accent)
            }
            Button {
                state.toggle()
            } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("연습장 닫기 (N)")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: Draw tools

    private var drawToolbar: some View {
        HStack(spacing: 4) {
            ToolButton(icon: "pencil", active: state.tool == .pen && state.pen == .thin, help: "가는 펜") {
                state.tool = .pen; state.pen = .thin
            }
            ToolButton(icon: "pencil.tip", active: state.tool == .pen && state.pen == .thick, help: "굵은 펜") {
                state.tool = .pen; state.pen = .thick
            }
            ToolButton(icon: "eraser", active: state.tool == .eraser, help: "지우개") {
                state.tool = .eraser
            }
            Rectangle().fill(Theme.cardStroke(scheme)).frame(width: 1, height: 16).padding(.horizontal, 3)
            ForEach(ScratchColor.allCases) { c in
                Button {
                    state.color = c
                    state.tool = .pen
                } label: {
                    Circle()
                        .fill(c.color(scheme))
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(Theme.accent, lineWidth: state.color == c && state.tool == .pen ? 2 : 0).padding(-3))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(c.title)
            }
            Spacer(minLength: 4)
            ToolButton(icon: "arrow.uturn.backward", active: false, enabled: document.canUndo, help: "실행 취소 (⌘Z)") { document.undo() }
            ToolButton(icon: "arrow.uturn.forward", active: false, enabled: document.canRedo, help: "다시 실행 (⇧⌘Z)") { document.redo() }
            ToolButton(icon: "trash", active: false, enabled: document.pad.hasDrawing, help: "전부 지우기") { confirmClear = true }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: Paper

    private var paper: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(paperColor)
            Group {
                if state.mode == .draw {
                    ScratchCanvas(document: document, version: document.version, tool: state.tool, pen: state.pen, color: state.color) { focused in
                        state.focused = focused
                    }
                } else {
                    ScratchTextEditor(document: document) { focused in
                        state.focused = focused
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(state.focused ? Theme.accent : Theme.cardStroke(scheme), lineWidth: state.focused ? 2 : 1)
                .allowsHitTesting(false)
        )
        .animation(.snappy(duration: 0.18), value: state.focused)
    }

    private var paperColor: Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.78)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if state.mode == .draw {
                if document.hasFigure {
                    Button {
                        document.toggleFigure(canvasWidth: document.pad.canvasWidth > 0 ? document.pad.canvasWidth : state.width - 20)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: document.figureShown ? "photo.on.rectangle.angled" : "photo").font(.system(size: 10, weight: .semibold))
                            Text(document.figureShown ? "그림 빼기" : "그림 가져오기")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: document.figureShown))
                    .controlSize(.small)
                    .help("문제 그림을 연하게 깔고 그 위에 그려요")
                }
                Spacer()
                Text("Shift 직선 · Esc 문제로").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            } else {
                Text("계산 과정을 손으로 적는 곳이에요").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                Spacer()
                Text("Esc 문제로").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(height: 30)
    }
}

/// Small square icon button for the tool row.
struct ToolButton: View {
    var icon: String
    var active: Bool
    var enabled = true
    var help: String
    var action: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Theme.accent : (enabled ? Color.primary : Color.secondary.opacity(0.5)))
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? Theme.accent.opacity(0.16) : (hovering && enabled ? Theme.hoverFill(scheme) : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .onHover { hovering = $0 }
    }
}

/// Drag strip between the problem and the panel.
struct ScratchResizeHandle: View {
    @Bindable var state: ScratchPanelState
    /// Widest the panel can get right now (the problem column keeps its minimum).
    var maxWidth: Double = ScratchPanelState.maxWidth
    @State private var startWidth: Double?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(Theme.cardStroke(scheme))
            .frame(width: 1)
            .frame(width: 9)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if startWidth == nil { startWidth = state.width }
                        state.width = min(max(ScratchPanelState.minWidth, maxWidth), state.clampWidth((startWidth ?? state.width) - value.translation.width))
                    }
                    .onEnded { _ in startWidth = nil }
            )
    }
}

/// Problem content on the left, the scratch pad (when open) on the right. The panel never takes more than the
/// window can spare: the problem column keeps `minContent` points (its header and footer have compact layouts).
struct ScratchSplit<Content: View>: View {
    @Bindable var appState: AppState
    let document: ScratchDocument?
    var minContent: CGFloat = 520
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let room = Double(geo.size.width - minContent - 9)
            let width = max(ScratchPanelState.minWidth, min(appState.scratch.width, room))
            HStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if appState.scratch.isOpen, let document {
                    ScratchResizeHandle(state: appState.scratch, maxWidth: room)
                    ScratchPanel(appState: appState, document: document)
                        .frame(width: width)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }
}

/// How much of a problem-screen footer fits: full labels, icons only, or icons only without the A–E buttons
/// (the choices themselves and the 1–5 keys still select). Chosen from the measured column width, because a
/// SwiftUI text can always squeeze and ViewThatFits would happily clip the letters instead of dropping labels.
enum FooterDensity: CaseIterable {
    case full, medium, compact
    var labels: Bool { self == .full }
    var letters: Bool { self != .compact }

    static func forWidth(_ width: CGFloat, full: CGFloat, medium: CGFloat) -> FooterDensity {
        width >= full ? .full : width >= medium ? .medium : .compact
    }
}

/// Reports the width a row actually gets (rows with a Spacer fill their column, so this is the column width).
struct WidthReader: ViewModifier {
    @Binding var width: CGFloat

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { width = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in width = w }
            }
        )
    }
}

extension View {
    func readWidth(_ width: Binding<CGFloat>) -> some View { modifier(WidthReader(width: width)) }
}

/// Footer button that opens / closes the panel.
struct ScratchToggleButton: View {
    @Bindable var appState: AppState
    var compact = false

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { appState.scratch.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "pencil.and.outline").font(.system(size: 11, weight: .semibold))
                if !compact { Text("연습장") }
                Keycap(text: "N")
            }
        }
        .buttonStyle(PillButtonStyle(prominent: appState.scratch.isOpen))
        .help(appState.scratch.isOpen ? "연습장 닫기" : "연습장 열기")
    }
}

// MARK: - Saved pads

/// Thumbnail of a saved pad; click to see it large. Nothing when the attempt has no pad.
struct ScratchThumbnail: View {
    @Bindable var appState: AppState
    let problemID: String
    let id: UUID?
    var size = CGSize(width: 84, height: 58)
    @State private var showViewer = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let store = appState.scratchStore
        let _ = store.revision
        if let id, let pad = store.load(problemID: problemID, id: id), !pad.isEmpty {
            Button {
                showViewer = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(scheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.85))
                    if pad.hasDrawing, let image = store.thumbnail(for: pad, figureSVG: appState.library.problem(problemID)?.figure,
                                                                   size: CGSize(width: size.width - 8, height: size.height - 8), dark: scheme == .dark) {
                        Image(nsImage: image).resizable().scaledToFit().padding(4)
                    } else {
                        Text(pad.text)
                            .font(.system(size: 6.5, design: .monospaced))
                            .lineLimit(5)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(5)
                    }
                }
                .frame(width: size.width, height: size.height)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.cardStroke(scheme)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("이 시도의 연습장 크게 보기")
            .sheet(isPresented: $showViewer) {
                ScratchViewerSheet(appState: appState, problemID: problemID, initialID: id)
            }
            .onAppear { if DebugEnv.scratchFlags.contains("viewer") { showViewer = true } }   // snapshots of the viewer
        }
    }
}

/// Read-only rendering of one pad: drawing on top, text below.
struct ScratchPadView: View {
    let pad: ScratchPad
    let figureSVG: String?
    var width: CGFloat = 640
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pad.hasDrawing, let image = rendered {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: image.size.width, height: image.size.height)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.78)))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.cardStroke(scheme)))
            }
            if !pad.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(pad.text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.78)))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.cardStroke(scheme)))
            }
        }
    }

    private var rendered: NSImage? {
        guard let bounds = pad.contentBounds else { return nil }
        let canvasW = max(pad.canvasWidth, bounds.maxX + 12, 200)
        let region = CGRect(x: 0, y: 0, width: canvasW, height: max(bounds.maxY + 24, 120))
        let figure = pad.figure != nil ? figureSVG.flatMap { FigureImage.image(svg: $0, dark: scheme == .dark) } : nil
        let target = CGSize(width: width, height: region.height * width / region.width)
        return StrokePainter.render(pad, figure: figure, size: target, scale: NSScreen.main?.backingScaleFactor ?? 2, dark: scheme == .dark, region: region)
    }
}

/// Every saved pad of a problem, newest first, with the one that was asked for selected.
struct ScratchViewerSheet: View {
    @Bindable var appState: AppState
    let problemID: String
    let initialID: UUID?
    @State private var selected: UUID?
    @Environment(\.dismiss) private var dismiss

    private var pads: [ScratchPad] { appState.scratchStore.pads(problemID: problemID) }

    var body: some View {
        let pads = pads
        let current = pads.first { $0.id == (selected ?? initialID) } ?? pads.first
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("연습장 · \(MistakeSource.problem(id: problemID, lesson: "").title)").font(.system(size: 14, weight: .semibold))
                if let current { Text(Format.fullDate(current.date) + " · " + current.kind.title).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
                if pads.count > 1 {
                    Picker("시도", selection: Binding(get: { current?.id ?? UUID() }, set: { selected = $0 })) {
                        ForEach(pads) { p in Text("\(Format.shortDate(p.date)) \(p.kind.title)").tag(p.id) }
                    }
                    .frame(width: 200)
                }
                Button("닫기") { dismiss() }.buttonStyle(PillButtonStyle()).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            Divider().opacity(0.5)
            ScrollView {
                if let current {
                    ScratchPadView(pad: current, figureSVG: appState.library.problem(problemID)?.figure, width: 700)
                        .padding(18)
                } else {
                    Text("저장된 연습장이 없어요").font(.system(size: 13)).foregroundStyle(.secondary).padding(40)
                }
            }
        }
        .frame(width: 760, height: 620)
    }
}
