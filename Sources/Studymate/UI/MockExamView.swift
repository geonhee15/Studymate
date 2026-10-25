import AppKit
import SwiftUI

/// 실전 모의고사 landing: app sets, paper mode, history.
struct MockExamView: View {
    @Bindable var appState: AppState
    @State private var paperYear: Int = 2023
    @Environment(\.colorScheme) private var scheme

    private var library: ContentLibrary { appState.library }
    private var store: MockStore { appState.mocks }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "실전 모의고사", subtitle: "25문항 · 40분 · 1~10번 10분, 11~20번 15분, 21~25번 15분 배분")
                HStack(alignment: .top, spacing: 14) {
                    setsCard
                    paperCard.frame(width: 330)
                }
                historyCard
            }
            .padding(24)
        }
    }

    private var setsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "앱 오리지널 세트")
            if library.mockSets.isEmpty {
                Text("세트 준비 중").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            ForEach(library.mockSets) { set in
                let past = store.results(source: set.id)
                HStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.system(size: 15)).foregroundStyle(Theme.accent).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(set.title).font(.system(size: 14, weight: .semibold))
                        Text(past.isEmpty ? "아직 안 풂 · 25문항 40분" : "최근 \(past[0].score)/25 · \(Format.shortDate(past[0].date)) · \(past.count)회 풂")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let best = past.max(by: { $0.score < $1.score }) {
                        Chip(text: "최고 \(best.score)", icon: "star", color: Theme.correct)
                    }
                    Button(past.isEmpty ? "시작" : "다시 풀기") { appState.startMock(set: set) }
                        .buttonStyle(PillButtonStyle(prominent: past.isEmpty))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var paperCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "종이 기출 모드")
            Text("문제는 앱에 없어요. 종이 기출을 펴고 40분 타이머와 답안지만 쓰세요. 끝나면 직접 정오를 체크하고, 결과는 기출 트래커에 들어가요.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Picker("연도", selection: $paperYear) {
                    ForEach(appState.papers.visibleYears.reversed(), id: \.self) { Text(String($0)).tag($0) }
                }
                .frame(width: 120)
                Spacer()
                Button("시작") { appState.startPaper(year: paperYear) }.buttonStyle(PillButtonStyle(prominent: true))
            }
            if appState.papers.reservedLocked {
                Text("2024~2026은 기출 트래커에서 잠금을 풀면 고를 수 있어요.").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .card()
        .onAppear { paperYear = appState.papers.visibleYears.last ?? 2023 }
    }

    private var historyCard: some View {
        let results = store.sortedByDate
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "기록")
            if results.isEmpty {
                Text("아직 기록이 없어요").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            ForEach(results) { r in
                HStack(spacing: 12) {
                    Image(systemName: r.kind == .app ? "doc.text" : "doc.plaintext").foregroundStyle(.secondary).frame(width: 22)
                    Text(r.title).font(.system(size: 13, weight: .medium))
                    Text(Format.fullDate(r.date)).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(r.score) / \(r.total)").font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(Format.duration(Int(r.seconds))).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                    if r.kind == .app, let set = library.mockSets.first(where: { $0.id == r.source }) {
                        Button("분석") { appState.showMockResult(r, set: set) }.buttonStyle(PillButtonStyle()).controlSize(.small)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Exam session

struct MockSessionView: View {
    @Bindable var appState: AppState
    @Bindable var session: MockSession
    @State private var bridge = WebBridge()
    @State private var keyMonitor: Any?
    @State private var confirmFinish = false
    @State private var confirmExit = false
    @State private var headerWidth: CGFloat = 2000
    @State private var footerWidth: CGFloat = 2000
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if session.finished, let result = session.result {
                MockResultView(appState: appState, result: result, set: session.exam) { appState.endMock() }
            } else {
                HStack(spacing: 0) {
                    ScratchSplit(appState: appState, document: session.currentScratch, minContent: 440) {
                        VStack(spacing: 0) {
                            header
                            Divider().opacity(0.5)
                            MathWebView(bridge: bridge)
                            Divider().opacity(0.5)
                            footer
                        }
                    }
                    Divider().opacity(0.5)
                    omr.frame(width: 232)
                }
            }
        }
        .onAppear {
            bridge.onMessage = { type, body in
                if type == "choice", let letter = body["letter"] as? String { session.answer(letter) }
            }
            load()
            installKeys()
        }
        .onDisappear {
            removeKeys()
            appState.scratch.focused = false
        }
        .onChange(of: session.index) { _, _ in load() }
        .onChange(of: session.answers) { _, _ in
            bridge.run("sm.setSelected(\(WebTemplate.jsString(session.answers[session.currentNumber] ?? "")));")
        }
        .confirmationDialog("답안을 제출할까요?", isPresented: $confirmFinish) {
            Button("제출") { session.finish() }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            Text("\(session.answeredCount)/25 표시했어요. 비운 문제는 0점이에요.")
        }
        .confirmationDialog("모의고사를 그만둘까요?", isPresented: $confirmExit) {
            Button("그만두기 (기록 안 함)", role: .destructive) { appState.endMock(discard: true) }
            Button("계속 풀기", role: .cancel) {}
        }
    }

    private var header: some View {
        headerRow(compact: headerWidth < 700).readWidth($headerWidth)
    }

    /// `compact` drops the segment guide when the scratch pad leaves little room.
    private func headerRow(compact: Bool) -> some View {
        let remaining = session.remaining
        let warn = remaining < 300
        return HStack(spacing: 12) {
            Button { confirmExit = true } label: {
                HStack(spacing: 4) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)); Text("나가기").font(.system(size: 12.5, weight: .medium)) }.foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Text(session.exam.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text("\(session.currentNumber)번").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.accent)
            if !compact { Chip(text: session.current.band.title, icon: "chart.bar") }
            Spacer()
            if !compact { Text(segmentGuide).font(.system(size: 11.5)).foregroundStyle(.secondary) }
            HStack(spacing: 5) {
                Image(systemName: "timer").font(.system(size: 12, weight: .medium))
                Text(Format.clock(remaining)).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .foregroundStyle(warn ? Theme.wrong : Color.primary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(warn ? Theme.wrong.opacity(0.12) : Theme.chipFill(scheme)))
            .fixedSize()
        }
        .padding(.leading, appState.chromeHidden ? 84 : 18)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
    }

    private var segmentGuide: String {
        let used = session.elapsed
        if session.currentNumber <= 10 { return "1~10번 목표 10분 · 경과 \(Format.clock(used))" }
        if session.currentNumber <= 20 { return "11~20번 목표 25분까지 · 경과 \(Format.clock(used))" }
        return "21~25번 · 경과 \(Format.clock(used))"
    }

    private var footer: some View {
        footerRow(FooterDensity.forWidth(footerWidth, full: 840, medium: 640)).readWidth($footerWidth)
    }

    /// Labels go first, then the A–E buttons (the choices, the 1–5 keys and the answer sheet still work).
    private func footerRow(_ level: FooterDensity) -> some View {
        HStack(spacing: 10) {
            Button { session.previous() } label: { HStack(spacing: 4) { Image(systemName: "chevron.left"); if level.labels { Text("이전") } } }
                .buttonStyle(PillButtonStyle()).disabled(session.index == 0).help("이전 (←)")
            Button { session.next() } label: { HStack(spacing: 4) { if level.labels { Text("다음") }; Image(systemName: "chevron.right"); Keycap(text: "Space") } }
                .buttonStyle(PillButtonStyle()).disabled(session.index >= session.problems.count - 1).help("다음 (Space, →)")
            Button {
                if session.flagged.contains(session.currentNumber) { session.flagged.remove(session.currentNumber) } else { session.flagged.insert(session.currentNumber) }
            } label: {
                HStack(spacing: 4) { Image(systemName: session.flagged.contains(session.currentNumber) ? "flag.fill" : "flag"); if level.labels { Text("나중에") }; Keycap(text: "F") }
            }
            .buttonStyle(PillButtonStyle(prominent: session.flagged.contains(session.currentNumber)))
            .help("나중에 다시 볼 문제로 표시 (F)")
            ScratchToggleButton(appState: appState, compact: !level.labels)
            Spacer()
            if level.letters {
                HStack(spacing: 4) {
                    ForEach(Problem.letters, id: \.self) { letter in
                        Button(letter) { session.answer(letter) }
                            .buttonStyle(PillButtonStyle(prominent: session.answers[session.currentNumber] == letter))
                    }
                    Button { session.clearAnswer() } label: { Image(systemName: "delete.left") }.buttonStyle(PillButtonStyle())
                        .disabled(session.answers[session.currentNumber] == nil)
                }
            }
            Button("제출") { confirmFinish = true }.buttonStyle(PillButtonStyle(prominent: true))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    /// OMR-style answer sheet on the right.
    private var omr: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "답안지")
                Spacer()
                Text("\(session.answeredCount)/25").font(.system(size: 11.5, design: .rounded)).monospacedDigit().foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(Array(session.problems.enumerated()), id: \.offset) { i, p in
                        let n = p.number ?? i + 1
                        let selected = session.index == i
                        HStack(spacing: 4) {
                            Text("\(n)").font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                                .foregroundStyle(selected ? Theme.accent : Color.secondary).frame(width: 20, alignment: .trailing)
                            ForEach(Problem.letters, id: \.self) { letter in
                                let marked = session.answers[n] == letter
                                Circle()
                                    .fill(marked ? Theme.accent : Color.clear)
                                    .overlay(Circle().strokeBorder(marked ? Theme.accent : Theme.cardStroke(scheme).opacity(2)))
                                    .frame(width: 14, height: 14)
                                    .overlay(Text(letter).font(.system(size: 7, weight: .bold)).foregroundStyle(marked ? .white : Color.secondary))
                            }
                            if session.flagged.contains(n) { Image(systemName: "flag.fill").font(.system(size: 8)).foregroundStyle(.orange) }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(selected ? Theme.accent.opacity(0.12) : Color.clear))
                        .contentShape(Rectangle())
                        .onTapGesture { session.go(to: i) }
                        if n == 10 || n == 20 { Divider().padding(.vertical, 2) }
                    }
                }
            }
            Text("1~5·A~E 답, Space 다음, ← → 이동, F 표시, N 연습장").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(12)
    }

    private func load() {
        bridge.setContent(WebTemplate.problem(session.current, lang: appState.koreanFirst ? .ko : .en, exam: true))
        bridge.run("sm.setSelected(\(WebTemplate.jsString(session.answers[session.currentNumber] ?? "")));")
    }

    private func installKeys() {
        removeKeys()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Keys typed or drawn into the 연습장 stay there; Esc hands focus back to the problem; ⌘Z undoes strokes.
            let editing = NSApp.keyWindow?.firstResponder.map { $0 is NSTextView || $0 is NSTextField } ?? false
            switch MainActor.assumeIsolated({ appState.scratch.intercept(event, document: session.currentScratch, textFieldActive: editing) }) {
            case .consumed: return nil
            case .passThrough: return event
            case .unhandled: break
            }
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView || responder is NSTextField { return event }
            if confirmFinish || confirmExit || session.finished { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            return MainActor.assumeIsolated { handle(event) ? nil : event }
        }
    }

    private func removeKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch event.keyCode {
        case 123: session.previous(); return true   // ←
        case 124: session.next(); return true       // →
        default: break
        }
        switch chars {
        case "1", "2", "3", "4", "5": session.answer(Problem.letters[Int(chars)! - 1]); return true
        case "a", "b", "c", "d", "e": session.answer(chars.uppercased()); return true
        case " ": session.next(); return true
        case "f":
            if session.flagged.contains(session.currentNumber) { session.flagged.remove(session.currentNumber) } else { session.flagged.insert(session.currentNumber) }
            return true
        case "n":
            withAnimation(.snappy(duration: 0.2)) { appState.scratch.toggle() }
            return true
        case "\u{7f}", "\u{8}": session.clearAnswer(); return true
        default: return false
        }
    }
}

// MARK: - Result

struct MockResultView: View {
    @Bindable var appState: AppState
    let result: MockResult
    let set: MockSet
    var done: () -> Void
    @State private var reviewing: Problem?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HStack(alignment: .top, spacing: 14) {
                        segmentCard
                        fieldCard
                    }
                    problemList
                }
                .padding(24)
                .padding(.top, appState.chromeHidden ? 20 : 0)
            }
            .onAppear {
                // Snapshots: open the review pane on the first problem that has a scratch pad.
                if DebugEnv.scratchFlags.contains("pane"), let a = result.answers.first(where: { $0.scratchID != nil }) { reviewing = set.problem(number: a.number) }
            }
            if let p = reviewing {
                let answer = result.answers.first { $0.number == p.number }
                Divider().opacity(0.5)
                MockReviewPane(appState: appState, problem: p, chosen: answer?.chosen, scratchID: answer?.scratchID) { reviewing = nil }
                    .frame(width: 520)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "\(result.title) · \(Format.fullDate(result.date))")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(result.score) / \(result.total)").font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Theme.accent)
                    Text(Format.percent(result.accuracy)).font(.system(size: 16, weight: .semibold)).foregroundStyle(.secondary)
                    Text("사용 시간 \(Format.duration(Int(result.seconds)))").font(.system(size: 13)).foregroundStyle(.secondary)
                    let blank = result.answers.filter { $0.chosen == nil }.count
                    if blank > 0 { Chip(text: "빈칸 \(blank)", icon: "exclamationmark.triangle", color: .orange) }
                }
            }
            Spacer()
            Button("돌아가기") { done() }.buttonStyle(PillButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
        }
    }

    private var segmentCard: some View {
        let used = result.segmentSeconds
        let guide = MockResult.segmentGuide
        let maxV = max(used.max() ?? 1, guide.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "구간별 시간 사용 (목표 10 / 15 / 15분)")
            ForEach(0..<3, id: \.self) { i in
                let over = used[i] > guide[i]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(MockResult.segmentTitles[i]).font(.system(size: 12.5, weight: .medium)).frame(width: 60, alignment: .leading)
                        Text(Format.clock(used[i])).font(.system(size: 12.5, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(over ? Theme.wrong : Color.primary)
                        Text("/ 목표 \(Format.clock(guide[i]))").font(.system(size: 11.5)).foregroundStyle(.secondary)
                        Spacer()
                        let correct = result.answers.filter { a in (i == 0 && a.number <= 10) || (i == 1 && a.number > 10 && a.number <= 20) || (i == 2 && a.number > 20) }
                        Text("\(correct.filter { $0.correct == true }.count)/\(correct.count) 정답").font(.system(size: 11.5)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.07))
                            Capsule().fill(Theme.accent.opacity(0.25)).frame(width: geo.size.width * guide[i] / maxV)
                            Capsule().fill(over ? Theme.wrong : Theme.accent).frame(width: geo.size.width * used[i] / maxV)
                        }
                    }
                    .frame(height: 10)
                }
            }
            Text("연한 막대가 목표, 진한 막대가 실제. 빨간색은 목표 초과.").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var fieldCard: some View {
        var stats: [(Field, Int, Int)] = []
        for f in Field.allCases {
            let a = result.answers.filter { $0.fields.contains(f) }
            if !a.isEmpty { stats.append((f, a.filter { $0.correct == true }.count, a.count)) }
        }
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "분야별")
            ForEach(stats, id: \.0) { f, c, t in
                HStack(spacing: 8) {
                    Image(systemName: f.icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                    Text(f.title).font(.system(size: 12.5)).frame(width: 64, alignment: .leading)
                    ProgressBar(fraction: Double(c) / Double(t), color: c == t ? Theme.correct : (Double(c) / Double(t) < 0.5 ? Theme.wrong : Theme.accent), height: 6)
                    Text("\(c)/\(t)").font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .frame(width: 330, alignment: .leading)
        .card()
    }

    private var problemList: some View {
        VStack(spacing: 2) {
            ForEach(result.answers, id: \.number) { a in
                let p = set.problem(number: a.number)
                HStack(spacing: 10) {
                    Text("\(a.number)").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                    Image(systemName: a.correct == true ? "checkmark.circle.fill" : (a.chosen == nil ? "minus.circle" : "xmark.circle.fill"))
                        .foregroundStyle(a.correct == true ? Theme.correct : (a.chosen == nil ? Color.secondary : Theme.wrong))
                    Text("내 답 \(a.chosen ?? "–") · 정답 \(p?.answer ?? "?")").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
                    Text(a.fields.map(\.title).joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(.secondary)
                    if let lesson = a.lesson { Text(appState.library.lessonTitle(lesson)).font(.system(size: 11.5)).foregroundStyle(.tertiary) }
                    Spacer()
                    if let p { ScratchThumbnail(appState: appState, problemID: p.id, id: a.scratchID, size: CGSize(width: 46, height: 32)) }
                    Text(Format.clock(a.seconds)).font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundStyle(.secondary)
                    if let p { Button("해설") { reviewing = p }.buttonStyle(PillButtonStyle(prominent: reviewing?.id == p.id)).controlSize(.small) }
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
            }
        }
        .padding(6)
        .card()
    }
}

/// Problem + solution for one mock problem (after grading), and the scratch pad used on it.
struct MockReviewPane: View {
    @Bindable var appState: AppState
    let problem: Problem
    let chosen: String?
    let scratchID: UUID?
    var close: () -> Void
    @State private var bridge = WebBridge()
    @State private var showScratch = DebugEnv.scratchFlags.contains("pane")

    private var scratchPad: ScratchPad? {
        guard let scratchID, let pad = appState.scratchStore.load(problemID: problem.id, id: scratchID), !pad.isEmpty else { return nil }
        return pad
    }

    var body: some View {
        let pad = scratchPad
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(problem.number ?? 0)번").font(.system(size: 13, weight: .semibold))
                if pad != nil {
                    Picker("", selection: $showScratch) {
                        Text("해설").tag(false)
                        Text("내 연습장").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                } else {
                    Text("해설").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { close() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider().opacity(0.5)
            if showScratch, let pad {
                ScrollView {
                    ScratchPadView(pad: pad, figureSVG: problem.figure, width: 480).padding(16)
                }
            } else {
                MathWebView(bridge: bridge)
                    .onAppear { show() }
                    .onChange(of: problem.id) { _, _ in show() }
            }
        }
        .onChange(of: problem.id) { _, _ in if scratchPad == nil { showScratch = false } }
    }

    private func show() {
        bridge.setContent(WebTemplate.problem(problem, lang: .en))
        bridge.run("sm.showResult(\(WebTemplate.jsString(chosen ?? "")), \(WebTemplate.jsString(problem.answer)), \(WebTemplate.jsString("")));")
    }
}

// MARK: - Paper mode

struct PaperSessionView: View {
    @Bindable var appState: AppState
    @Bindable var session: PaperSession
    @State private var confirmExit = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            switch session.phase {
            case .solving: answerSheet
            case .grading: grading
            case .done: doneView
            }
        }
        .confirmationDialog("종이 기출 모드를 그만둘까요?", isPresented: $confirmExit) {
            Button("그만두기 (기록 안 함)", role: .destructive) { appState.endPaper(discard: true) }
            Button("계속", role: .cancel) {}
        }
    }

    private var header: some View {
        let warn = session.remaining < 300
        return HStack(spacing: 12) {
            Button { if session.phase == .done { appState.endPaper() } else { confirmExit = true } } label: {
                HStack(spacing: 4) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)); Text("나가기").font(.system(size: 12.5, weight: .medium)) }.foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Text("\(String(session.year)) AMC 8 · 종이 기출").font(.system(size: 13, weight: .semibold))
            Text(session.phase == .solving ? "답만 표시하세요" : session.phase == .grading ? "정답지를 보고 직접 체크하세요" : "완료").font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            if session.phase == .solving {
                HStack(spacing: 5) {
                    Image(systemName: "timer").font(.system(size: 12, weight: .medium))
                    Text(Format.clock(session.remaining)).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                }
                .foregroundStyle(warn ? Theme.wrong : Color.primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(warn ? Theme.wrong.opacity(0.12) : Theme.chipFill(scheme)))
            }
        }
        .padding(.leading, appState.chromeHidden ? 84 : 18)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
    }

    private var answerSheet: some View {
        VStack(spacing: 14) {
            Text("1~10번 10분 · 11~20번 15분 · 21~25번 15분").font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 14)
            HStack(alignment: .top, spacing: 18) {
                ForEach([1...10, 11...20, 21...25], id: \.lowerBound) { range in
                    VStack(spacing: 6) {
                        ForEach(Array(range), id: \.self) { n in
                            HStack(spacing: 6) {
                                Text("\(n)").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: 22, alignment: .trailing)
                                ForEach(Problem.letters, id: \.self) { letter in
                                    let marked = session.answers[n] == letter
                                    Button {
                                        session.answer(number: n, marked ? nil : letter)
                                    } label: {
                                        Text(letter).font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(marked ? .white : Color.secondary)
                                            .frame(width: 26, height: 26)
                                            .background(Circle().fill(marked ? Theme.accent : Theme.chipFill(scheme)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .card()
                }
            }
            HStack {
                Text("표시 \(session.answers.count)/25 · 빈칸은 무조건 손해").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("다 풀었어요, 채점하기") { session.stopSolving() }.buttonStyle(PillButtonStyle(prominent: true))
            }
            .frame(maxWidth: 760)
            Spacer()
        }
        .padding(24)
    }

    private var grading: some View {
        VStack(spacing: 12) {
            Text("정답지와 비교해서 맞음·틀림을 누르세요. 찍어서 맞힌 건 '찍음', 시간이 오래 걸린 건 '오래'를 함께 켜세요.")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 14)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(1...25, id: \.self) { n in
                        HStack(spacing: 10) {
                            Text("\(n)").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                            Text("내 답 \(session.answers[n] ?? "–")").font(.system(size: 12.5)).frame(width: 70, alignment: .leading)
                            Button("맞음") { session.verdicts[n] = true }.buttonStyle(PillButtonStyle(prominent: session.verdicts[n] == true)).controlSize(.small)
                            Button("틀림") { session.verdicts[n] = false }.buttonStyle(PillButtonStyle(prominent: session.verdicts[n] == false)).controlSize(.small)
                            Toggle("찍음", isOn: Binding(get: { session.guessed.contains(n) }, set: { if $0 { session.guessed.insert(n) } else { session.guessed.remove(n) } })).toggleStyle(.checkbox)
                            Toggle("오래", isOn: Binding(get: { session.slow.contains(n) }, set: { if $0 { session.slow.insert(n) } else { session.slow.remove(n) } })).toggleStyle(.checkbox)
                            Spacer()
                            Button { NSWorkspace.shared.open(PastPaperStore.aopsURL(year: session.year, number: n)) } label: { Image(systemName: "safari").font(.system(size: 11)) }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                    }
                }
                .padding(6)
                .card()
                .frame(maxWidth: 640)
            }
            HStack {
                Text("체크 \(session.gradedCount)/25 · 지금까지 \(session.score)점").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("기출 트래커에 저장") { appState.finishPaper(session) }.buttonStyle(PillButtonStyle(prominent: true)).disabled(session.gradedCount < 25)
            }
            .frame(maxWidth: 640)
            Spacer(minLength: 10)
        }
        .padding(24)
    }

    private var doneView: some View {
        VStack(spacing: 10) {
            Text("\(String(session.year)) AMC 8").font(.system(size: 13)).foregroundStyle(.secondary)
            Text("\(session.score) / 25").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
            Text("사용 시간 \(Format.duration(Int(session.usedSeconds))) · 기출 트래커와 통계에 반영됐어요").font(.system(size: 12.5)).foregroundStyle(.secondary)
            Button("돌아가기") { appState.endPaper() }.buttonStyle(PillButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
