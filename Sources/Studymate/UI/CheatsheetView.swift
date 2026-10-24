import SwiftUI

struct CheatsheetView: View {
    @Bindable var appState: AppState
    @State private var bridge = WebBridge()
    @State private var flashcards = DebugEnv.flashcards
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PageTitle(title: "치트시트", subtitle: "외워 두면 시간 버는 수")
                Spacer()
                Picker("", selection: $flashcards) {
                    Text("표").tag(false)
                    Text("플래시카드").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
            if flashcards {
                FlashcardView(sections: appState.library.cheatsheet)
            } else {
                MathWebView(bridge: bridge)
                    .onAppear { bridge.setContent(WebTemplate.cheatsheet(appState.library.cheatsheet)) }
            }
        }
    }
}

struct FlashcardView: View {
    let sections: [CheatsheetSection]
    @State private var selectedSection: String = "전체"
    @State private var deck: [(String, String)] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var bridge = WebBridge()
    @Environment(\.colorScheme) private var scheme

    private var sectionNames: [String] { ["전체"] + sections.filter { !$0.cards.isEmpty }.map(\.title) }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Picker("", selection: $selectedSection) {
                    ForEach(sectionNames, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 200)
                Button("섞기") { build(shuffle: true) }.buttonStyle(PillButtonStyle())
                Spacer()
                if !deck.isEmpty {
                    Text("\(index + 1) / \(deck.count)").font(.system(size: 12.5, design: .rounded)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.cardFill(scheme))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.cardStroke(scheme)))
                VStack(spacing: 10) {
                    Text(flipped ? "답" : "문제").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    MathWebView(bridge: bridge)
                        .frame(height: 120)
                }
                .padding(20)
            }
            .frame(maxWidth: 560)
            .frame(height: 220)
            .contentShape(Rectangle())
            .onTapGesture { flip() }
            HStack(spacing: 10) {
                Button { previous() } label: { Image(systemName: "chevron.left") }.buttonStyle(PillButtonStyle()).disabled(index == 0)
                Button(flipped ? "다음" : "뒤집기") { if flipped { next() } else { flip() } }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .keyboardShortcut(.space, modifiers: [])
                Button { next() } label: { Image(systemName: "chevron.right") }.buttonStyle(PillButtonStyle()).disabled(index >= deck.count - 1)
            }
            Text("Space로 뒤집고 넘기기 · 카드 클릭으로 뒤집기").font(.system(size: 11)).foregroundStyle(.tertiary)
            Spacer()
        }
        .onAppear { build(shuffle: false) }
        .onChange(of: selectedSection) { _, _ in build(shuffle: false) }
    }

    private func build(shuffle: Bool) {
        var cards = selectedSection == "전체" ? sections.flatMap(\.cards) : (sections.first { $0.title == selectedSection }?.cards ?? [])
        if shuffle { cards.shuffle() }
        deck = cards
        index = 0
        flipped = false
        show()
    }

    private func show() {
        guard !deck.isEmpty else { bridge.setContent("<div class=\"doc\"><p>카드가 없어요</p></div>"); return }
        let card = deck[index]
        let text = flipped ? card.1 : card.0
        let html = "<div style=\"display:flex;align-items:center;justify-content:center;height:110px;font-size:\(flipped ? 22 : 20)px;font-weight:600;text-align:center\">\(MarkdownHTML.renderInline(text))</div>"
        bridge.setContent(html)
    }

    private func flip() { flipped.toggle(); show() }
    private func next() { guard index < deck.count - 1 else { return }; index += 1; flipped = false; show() }
    private func previous() { guard index > 0 else { return }; index -= 1; flipped = false; show() }
}
