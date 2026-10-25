import AppKit
import SwiftUI

/// The problem screen: native header (progress, band, timer) + web body (question, choices, hints, solution) + native footer,
/// with the 연습장 (scratch pad) panel on the right when open.
/// Keys: 1–5 / A–E select, Enter submit, H hint, Space next, T translation, N scratch pad, Esc leave.
struct ProblemSessionView: View {
    @Bindable var appState: AppState
    @Bindable var session: ProblemSession
    @State private var bridge = WebBridge()
    @State private var keyMonitor: Any?
    @State private var showStuck = false
    @State private var showSummary = false
    @State private var headerWidth: CGFloat = 2000
    @State private var footerWidth: CGFloat = 2000
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScratchSplit(appState: appState, document: session.finished ? nil : session.scratch) {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)
                if session.finished {
                    SessionSummaryView(appState: appState, session: session)
                } else {
                    MathWebView(bridge: bridge)
                    Divider().opacity(0.5)
                    footer
                }
            }
        }
        .onAppear {
            bridge.onMessage = handle
            loadProblem()
            installKeys()
        }
        .onDisappear {
            removeKeys()
            appState.scratch.focused = false
        }
        .onChange(of: session.index) { _, _ in loadProblem() }
        .onChange(of: session.selected) { _, letter in
            bridge.run("sm.setSelected(\(WebTemplate.jsString(letter ?? "")));")
        }
        .onChange(of: session.hintsRevealed) { _, n in
            if n > 0 { bridge.run("sm.showHint(\(n));") }
        }
        .onChange(of: session.submitted) { _, submitted in
            guard submitted, let chosen = session.selected else { return }
            let text = "\(Format.clock(session.elapsed)) / 목표 \(Format.clock(Double(session.current.targetSeconds)))"
            bridge.run("sm.showResult(\(WebTemplate.jsString(chosen)), \(WebTemplate.jsString(session.current.answer)), \(WebTemplate.jsString(text)));")
        }
        .onChange(of: session.language) { _, lang in
            bridge.run("sm.setLang(\(WebTemplate.jsString(lang.rawValue)));")
        }
        .sheet(isPresented: Binding(get: { session.pendingReview != nil && !showStuck }, set: { if !$0 { session.pendingReview = nil } })) {
            if let outcome = session.pendingReview {
                StuckReasonSheet(outcome: outcome, session: session, appState: appState) { session.pendingReview = nil }
            }
        }
        .sheet(isPresented: $appState.showStuckQuestions) {
            VStack(alignment: .leading, spacing: 12) {
                StuckQuestionsCard()
                HStack { Spacer(); Button("닫기") { appState.showStuckQuestions = false }.keyboardShortcut(.cancelAction) }
            }
            .padding(16)
            .frame(width: 440)
        }
    }

    // MARK: Header

    private var header: some View {
        headerRow(compact: headerWidth < 820).readWidth($headerWidth)
    }

    /// `compact` drops the progress bar and tags when the scratch pad leaves little room.
    private func headerRow(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                appState.endSession()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    Text("나가기").font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Esc")
            Text(session.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text("\(session.index + 1) / \(session.total)")
                .font(.system(size: 12.5, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(.secondary)
            if !compact {
                ProgressBar(fraction: Double(session.index + (session.submitted ? 1 : 0)) / Double(max(1, session.total)), height: 4)
                    .frame(width: 120)
                Chip(text: session.current.band.title, icon: "chart.bar", color: bandColor(session.current.band))
                ForEach(session.current.fields) { f in Chip(text: f.title, icon: f.icon) }
            }
            Spacer()
            timerView.fixedSize()
            Button {
                appState.focusMode.toggle()
            } label: {
                Image(systemName: appState.focusMode ? "rectangle.inset.filled" : "rectangle.lefthalf.inset.filled")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(appState.focusMode ? "집중 모드 끄기" : "집중 모드 켜기")
        }
        .padding(.leading, appState.chromeHidden ? 84 : 18)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
    }

    private var timerView: some View {
        let over = session.overTarget
        return HStack(spacing: 5) {
            Image(systemName: over ? "clock.badge.exclamationmark" : "clock")
                .font(.system(size: 12, weight: .medium))
            Text(Format.clock(session.elapsed))
                .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
            Text("/ \(Format.clock(Double(session.current.targetSeconds)))")
                .font(.system(size: 11.5, design: .rounded)).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(over ? Theme.wrong : Color.primary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(over ? Theme.wrong.opacity(0.12) : Theme.chipFill(scheme)))
    }

    private func bandColor(_ band: Band) -> Color {
        switch band {
        case .easy: return Theme.correct
        case .medium: return Theme.accent
        case .hard: return .orange
        case .hardest: return Theme.wrong
        }
    }

    // MARK: Footer

    private var footer: some View {
        footerRow(FooterDensity.forWidth(footerWidth, full: 870, medium: 730)).readWidth($footerWidth)
    }

    /// Labels go first, then the A–E buttons, as the scratch pad takes room (the choices and the 1–5 keys still work).
    private func footerRow(_ level: FooterDensity) -> some View {
        HStack(spacing: 10) {
            Button {
                session.language = session.language == .en ? .ko : .en
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "character.bubble").font(.system(size: 11, weight: .semibold))
                    if level.labels { Text(session.language == .en ? "한국어로" : "English") }
                    Keycap(text: "T")
                }
            }
            .buttonStyle(PillButtonStyle())
            .help(session.language == .en ? "한국어로 (T)" : "English (T)")
            Button {
                appState.showStuckQuestions = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "questionmark.circle").font(.system(size: 11, weight: .semibold))
                    if level.labels { Text("막혔어") }
                }
            }
            .buttonStyle(PillButtonStyle())
            .help("막혔을 때 5가지 질문")
            ScratchToggleButton(appState: appState, compact: !level.labels)
            if !session.submitted {
                Button {
                    session.revealHint()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb").font(.system(size: 11, weight: .semibold))
                        Text("힌트 \(session.hintsRevealed)/\(session.hintsAvailable)")
                        Keycap(text: "H")
                    }
                }
                .buttonStyle(PillButtonStyle())
                .disabled(session.hintsRevealed >= session.hintsAvailable)
                Toggle(isOn: $session.guessed) {
                    Text("찍었음").font(.system(size: 12.5))
                }
                .toggleStyle(.checkbox)
            }
            Spacer()
            if session.submitted {
                let last = session.outcomes.last?.attempt
                if let last {
                    HStack(spacing: 6) {
                        Image(systemName: last.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(last.correct ? Theme.correct : Theme.wrong)
                        Text(last.correct ? "정답" : "오답")
                            .font(.system(size: 13, weight: .semibold))
                        if last.overTarget { Chip(text: "목표 시간 초과", icon: "clock", color: .orange) }
                        if last.guessed { Chip(text: "찍음", icon: "questionmark", color: .orange) }
                    }
                }
                Button {
                    session.next()
                } label: {
                    HStack(spacing: 6) {
                        Text(session.isLast ? "결과 보기" : "다음 문제")
                        Keycap(text: "Space")
                    }
                }
                .buttonStyle(PillButtonStyle(prominent: true))
            } else {
                if level.letters {
                    HStack(spacing: 4) {
                        ForEach(Problem.letters, id: \.self) { letter in
                            Button(letter) { session.select(letter) }
                                .buttonStyle(PillButtonStyle(prominent: session.selected == letter))
                        }
                    }
                }
                Button {
                    session.submit()
                } label: {
                    HStack(spacing: 6) {
                        Text("제출")
                        Keycap(text: "⏎")
                    }
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .disabled(!session.canSubmit)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    // MARK: Web

    private func loadProblem() {
        bridge.setContent(WebTemplate.problem(session.current, lang: session.language))
    }

    private func handle(_ type: String, _ body: [String: Any]) {
        if type == "choice", let letter = body["letter"] as? String {
            session.select(letter)
        }
    }

    // MARK: Keys

    private func installKeys() {
        removeKeys()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Keys typed or drawn into the 연습장 stay there; Esc hands focus back to the problem; ⌘Z undoes strokes.
            let editing = NSApp.keyWindow?.firstResponder.map { $0 is NSTextView || $0 is NSTextField } ?? false
            switch MainActor.assumeIsolated({ appState.scratch.intercept(event, document: session.scratch, textFieldActive: editing) }) {
            case .consumed: return nil
            case .passThrough: return event
            case .unhandled: break
            }
            // Let text fields (memo sheet, etc.) keep their keys.
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView || responder is NSTextField { return event }
            if session.pendingReview != nil || appState.showStuckQuestions { return event }
            if event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false { return event }
            return MainActor.assumeIsolated { handleKey(event) ? nil : event }
        }
    }

    private func removeKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the key was consumed.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if session.finished {
            if chars == "\u{1b}" || chars == "\r" || chars == " " { appState.endSession(); return true }
            return false
        }
        switch chars {
        case "1", "2", "3", "4", "5":
            session.select(index: Int(chars)! - 1); return true
        case "a", "b", "c", "d", "e":
            session.select(chars.uppercased()); return true
        case "\r":
            if session.submitted { session.next() } else { session.submit() }
            return true
        case " ":
            if session.submitted { session.next(); return true }
            return false
        case "h":
            session.revealHint(); return true
        case "t":
            session.language = session.language == .en ? .ko : .en; return true
        case "g":
            if !session.submitted { session.guessed.toggle() }; return true
        case "n":
            withAnimation(.snappy(duration: 0.2)) { appState.scratch.toggle() }; return true
        case "\u{1b}":
            appState.endSession(); return true
        default:
            return false
        }
    }
}

/// "막힌 이유" + one-line key idea → the mistake notebook.
struct StuckReasonSheet: View {
    let outcome: ProblemSession.Outcome
    @Bindable var session: ProblemSession
    @Bindable var appState: AppState
    var dismiss: () -> Void
    @State private var reason: StuckReason = .idea
    @State private var keyIdea = ""
    @State private var note = ""
    @Environment(\.colorScheme) private var scheme

    private var why: String {
        var parts: [String] = []
        if !outcome.attempt.correct { parts.append("틀림") }
        if outcome.attempt.overTarget { parts.append("목표 시간 초과") }
        if outcome.attempt.guessed { parts.append("찍었음") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("오답노트에 남길게요").font(.system(size: 16, weight: .bold))
                Text("\(why) · 막힌 이유와 핵심 아이디어를 적어 두면 복습할 때 그대로 떠올라요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "막힌 이유")
                HStack(spacing: 6) {
                    ForEach(StuckReason.allCases) { r in
                        Button {
                            reason = r
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: r.icon).font(.system(size: 11, weight: .semibold))
                                Text(r.title)
                            }
                        }
                        .buttonStyle(PillButtonStyle(prominent: reason == r))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "핵심 아이디어 한 줄")
                TextField("예: 적어도 하나 → 전체에서 하나도 없는 경우를 뺀다", text: $keyIdea)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "내 풀이 메모 (선택)")
                TextField("어디서 어떻게 틀렸는지", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("건너뛰기") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("오답노트에 저장") {
                    save()
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            if let existing = appState.mistakes.entry(for: .problem(id: outcome.problem.id, lesson: outcome.problem.lesson)) {
                reason = existing.reason
                keyIdea = existing.keyIdea
                note = existing.myNote
            } else if !outcome.attempt.correct {
                reason = outcome.attempt.hintsUsed > 0 ? .idea : .calculation
            }
        }
    }

    private func save() {
        appState.progress.updateReason(attemptID: outcome.attempt.id, reason: reason)
        let source = MistakeSource.problem(id: outcome.problem.id, lesson: outcome.problem.lesson)
        if session.kind == .review, let entryID = session.reviewEntryIDs[outcome.problem.id] {
            // In a review the pass/fail already moved the stage; just refresh the notes.
            appState.mistakes.update(id: entryID, keyIdea: keyIdea.isEmpty ? nil : keyIdea, myNote: note.isEmpty ? nil : note, reason: reason)
        } else {
            let scratchID = session.scratch.isEmpty ? nil : outcome.attempt.scratchID
            appState.mistakes.add(source: source, fields: outcome.problem.fields, reason: reason, keyIdea: keyIdea, myNote: note, scratchID: scratchID)
        }
    }
}

/// End-of-set summary.
struct SessionSummaryView: View {
    @Bindable var appState: AppState
    let session: ProblemSession
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: session.title)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(session.score) / \(session.total)")
                            .font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(Theme.accent)
                        Text(Format.percent(Double(session.score) / Double(max(1, session.total))))
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.secondary)
                        if session.kind == .quiz || session.kind == .test {
                            let passed = MasteryEngine.passed(kind: session.kind, score: session.score, total: session.total)
                            Chip(text: passed ? "통과" : "미통과", icon: passed ? "checkmark" : "xmark", color: passed ? Theme.correct : Theme.wrong)
                        }
                    }
                    let total = session.outcomes.reduce(0.0) { $0 + $1.attempt.seconds }
                    Text("총 \(Format.duration(Int(total))) · 문제당 평균 \(Format.clock(total / Double(max(1, session.outcomes.count))))")
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    ForEach(Array(session.outcomes.enumerated()), id: \.offset) { i, o in
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).frame(width: 22)
                            Image(systemName: o.attempt.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(o.attempt.correct ? Theme.correct : Theme.wrong)
                            Text(o.problem.band.title).font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                            Text(o.problem.fields.map(\.title).joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(.secondary)
                            Spacer()
                            if o.attempt.hintsUsed > 0 { Chip(text: "힌트 \(o.attempt.hintsUsed)", icon: "lightbulb", color: .orange) }
                            if o.attempt.guessed { Chip(text: "찍음", icon: "questionmark", color: .orange) }
                            ScratchThumbnail(appState: appState, problemID: o.problem.id, id: o.attempt.scratchID, size: CGSize(width: 46, height: 32))
                            Text(Format.clock(o.attempt.seconds))
                                .font(.system(size: 12, design: .rounded)).monospacedDigit()
                                .foregroundStyle(o.attempt.overTarget ? Theme.wrong : Color.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                    }
                }
                .padding(6)
                .card()
                HStack {
                    Spacer()
                    Button("돌아가기") { appState.endSession() }
                        .buttonStyle(PillButtonStyle(prominent: true))
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
    }
}
