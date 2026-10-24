import AppKit
import SwiftUI

/// 오답노트: filters, spaced-repetition status, review start, editing, and self-checked review for past-paper entries.
struct MistakeNotebookView: View {
    @Bindable var appState: AppState
    @State private var field: Field?
    @State private var reason: StuckReason?
    @State private var showGraduated = false
    @State private var editing: MistakeEntry?
    @State private var confirmDelete: MistakeEntry?
    @Environment(\.colorScheme) private var scheme

    private var store: MistakeStore { appState.mistakes }

    private var filtered: [MistakeEntry] {
        (showGraduated ? store.graduated : store.active).filter { e in
            (field == nil || e.fields.contains(field!)) && (reason == nil || e.reason == reason)
        }
        .sorted { ($0.isDue ? 0 : 1, $0.nextReview) < ($1.isDue ? 0 : 1, $1.nextReview) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    PageTitle(title: "오답노트", subtitle: "1일 → 3일 → 7일 → 14일 간격으로 다시 풀고, 해설 안 보고 맞히면 다음 단계. 14일 단계를 통과하면 졸업")
                    Spacer()
                    let dueLesson = store.due.filter { $0.problemID != nil && appState.library.problem($0.problemID!) != nil }
                    Button {
                        appState.startReview(entries: dueLesson)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
                            Text(dueLesson.isEmpty ? "오늘 복습할 레슨 문제 없음" : "오늘 복습 \(dueLesson.count)개 시작")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: !dueLesson.isEmpty))
                    .disabled(dueLesson.isEmpty)
                }
                HStack(spacing: 8) {
                    let weak = store.weakFields()
                    if !weak.isEmpty {
                        Text("이번 주 약한 분야").font(.system(size: 12)).foregroundStyle(.secondary)
                        ForEach(weak, id: \.field) { w in Chip(text: "\(w.field.title) \(w.count)", icon: w.field.icon, color: Theme.wrong) }
                    }
                    Spacer()
                    Picker("분야", selection: $field) {
                        Text("모든 분야").tag(Field?.none)
                        ForEach(Field.allCases) { Text($0.title).tag(Field?.some($0)) }
                    }
                    .frame(width: 140)
                    Picker("이유", selection: $reason) {
                        Text("모든 이유").tag(StuckReason?.none)
                        ForEach(StuckReason.allCases) { Text($0.title).tag(StuckReason?.some($0)) }
                    }
                    .frame(width: 170)
                    Toggle("졸업한 것", isOn: $showGraduated).toggleStyle(.checkbox)
                }
                summaryRow
                if filtered.isEmpty {
                    EmptyStateView(icon: "bookmark", title: showGraduated ? "졸업한 항목이 없어요" : "오답노트가 비어 있어요",
                                   message: "틀리거나, 목표 시간을 넘기거나, 찍은 문제가 자동으로 들어와요. 기출 트래커에서 보낼 수도 있어요.")
                        .frame(height: 280)
                } else {
                    VStack(spacing: 4) {
                        ForEach(filtered) { entry in MistakeRow(appState: appState, entry: entry, onEdit: { editing = entry }, onDelete: { confirmDelete = entry }) }
                    }
                    .padding(6)
                    .card()
                }
            }
            .padding(24)
        }
        .sheet(item: $editing) { entry in
            MistakeEditSheet(appState: appState, entry: entry) { editing = nil }
        }
        .confirmationDialog("이 항목을 지울까요?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), presenting: confirmDelete) { entry in
            Button("지우기", role: .destructive) { store.remove(id: entry.id) }
            Button("취소", role: .cancel) {}
        } message: { entry in
            Text(entry.source.title)
        }
    }

    private var summaryRow: some View {
        let active = store.active
        let stages = (0..<4).map { s in active.filter { $0.stage == s }.count }
        return HStack(spacing: 14) {
            StatPill(title: "복습 대기", value: "\(store.due.count)", color: Theme.accent)
            StatPill(title: "진행 중", value: "\(active.count)", color: .secondary)
            StatPill(title: "졸업", value: "\(store.graduated.count)", color: Theme.correct)
            Spacer()
            HStack(spacing: 6) {
                Text("단계별").font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach(0..<4, id: \.self) { s in
                    Chip(text: "\(MistakeEntry.intervals[s])일 \(stages[s])")
                }
            }
        }
    }
}

struct StatPill: View {
    var title: String
    var value: String
    var color: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            Text(title).font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
    }
}

struct MistakeRow: View {
    @Bindable var appState: AppState
    let entry: MistakeEntry
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var showSelfCheck = false
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    private var hasProblem: Bool { entry.problemID.flatMap { appState.library.problem($0) } != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 3) {
                Image(systemName: entry.graduated ? "checkmark.seal.fill" : (entry.isDue ? "bell.fill" : "clock"))
                    .foregroundStyle(entry.graduated ? Theme.correct : (entry.isDue ? Theme.accent : Color.secondary))
                Text(entry.graduated ? "졸업" : "\(entry.intervalDays)일")
                    .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            }
            .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.source.title).font(.system(size: 13, weight: .semibold))
                    if let lesson = entry.lessonID {
                        Text(appState.library.lessonTitle(lesson)).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    if case .pastPaper(let year, let number) = entry.source {
                        Button {
                            NSWorkspace.shared.open(PastPaperStore.aopsURL(year: year, number: number))
                        } label: {
                            Image(systemName: "safari").font(.system(size: 11)).foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .help("AoPS Wiki에서 열기")
                    }
                    Spacer()
                    ForEach(entry.fields) { f in Chip(text: f.title, icon: f.icon) }
                    Chip(text: entry.reason.title, icon: entry.reason.icon, color: .orange)
                }
                if !entry.keyIdea.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "key.fill").font(.system(size: 10)).foregroundStyle(Theme.accent).padding(.top, 3)
                        Text(entry.keyIdea).font(.system(size: 13))
                    }
                }
                if !entry.myNote.isEmpty {
                    Text(entry.myNote).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Text(entry.graduated ? "졸업 \(Format.shortDate(entry.reviews.last?.date ?? entry.createdAt))" : "다음 복습 \(Format.relativeDay(entry.nextReview))")
                        .font(.system(size: 11)).foregroundStyle(entry.isDue ? Theme.accent : Color.secondary.opacity(0.7))
                    Text("단계 \(min(entry.stage + 1, 4))/4 · 복습 \(entry.reviews.count)회 · 등록 \(Format.shortDate(entry.createdAt))")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    if hovering || showSelfCheck {
                        Button("편집") { onEdit() }.buttonStyle(PillButtonStyle()).controlSize(.small)
                        Button("지우기") { onDelete() }.buttonStyle(PillButtonStyle(destructive: true)).controlSize(.small)
                    }
                    if !entry.graduated {
                        if hasProblem {
                            Button("지금 풀기") { appState.startReview(entries: [entry]) }.buttonStyle(PillButtonStyle(prominent: entry.isDue)).controlSize(.small)
                        } else {
                            Button("다시 풀었어요") { showSelfCheck = true }
                                .buttonStyle(PillButtonStyle(prominent: entry.isDue)).controlSize(.small)
                                .popover(isPresented: $showSelfCheck, arrowEdge: .bottom) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("해설 안 보고 맞혔나요?").font(.system(size: 13, weight: .semibold))
                                        Text("맞혔으면 다음 단계로, 틀렸으면 1일로 돌아가요.").font(.system(size: 11.5)).foregroundStyle(.secondary)
                                        HStack {
                                            Button("틀렸어요") { appState.mistakes.recordReview(id: entry.id, correct: false); showSelfCheck = false }
                                                .buttonStyle(PillButtonStyle(destructive: true))
                                            Spacer()
                                            Button("맞혔어요") { appState.mistakes.recordReview(id: entry.id, correct: true); showSelfCheck = false }
                                                .buttonStyle(PillButtonStyle(prominent: true))
                                        }
                                    }
                                    .padding(14)
                                    .frame(width: 280)
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? Theme.hoverFill(scheme) : Color.clear))
        .onHover { hovering = $0 }
    }
}

struct MistakeEditSheet: View {
    @Bindable var appState: AppState
    let entry: MistakeEntry
    var dismiss: () -> Void
    @State private var reason: StuckReason = .idea
    @State private var keyIdea = ""
    @State private var note = ""
    @State private var fields: Set<Field> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.source.title).font(.system(size: 16, weight: .bold))
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "막힌 이유")
                HStack(spacing: 6) {
                    ForEach(StuckReason.allCases) { r in
                        Button { reason = r } label: {
                            HStack(spacing: 5) { Image(systemName: r.icon).font(.system(size: 11, weight: .semibold)); Text(r.title) }
                        }
                        .buttonStyle(PillButtonStyle(prominent: reason == r))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "분야")
                HStack(spacing: 4) {
                    ForEach(Field.allCases) { f in
                        Button { if fields.contains(f) { fields.remove(f) } else { fields.insert(f) } } label: { Text(f.title).font(.system(size: 11)) }
                            .buttonStyle(PillButtonStyle(prominent: fields.contains(f))).controlSize(.small)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "핵심 아이디어 한 줄")
                TextField("", text: $keyIdea).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "내 풀이 메모")
                TextField("", text: $note, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("취소") { dismiss() }.buttonStyle(PillButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("저장") {
                    appState.mistakes.update(id: entry.id, keyIdea: keyIdea, myNote: note, reason: reason, fields: Array(fields).sorted { $0.rawValue < $1.rawValue })
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            reason = entry.reason
            keyIdea = entry.keyIdea
            note = entry.myNote
            fields = Set(entry.fields)
        }
    }
}
