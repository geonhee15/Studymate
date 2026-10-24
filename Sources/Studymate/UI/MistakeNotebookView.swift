import SwiftUI

/// 오답노트 list with filters and review start. (Editing and the past-paper import land with stage 3.)
struct MistakeNotebookView: View {
    @Bindable var appState: AppState
    @State private var field: Field?
    @State private var reason: StuckReason?
    @State private var showGraduated = false
    @Environment(\.colorScheme) private var scheme

    private var store: MistakeStore { appState.mistakes }

    private var filtered: [MistakeEntry] {
        (showGraduated ? store.graduated : store.active).filter { e in
            (field == nil || e.fields.contains(field!)) && (reason == nil || e.reason == reason)
        }
        .sorted { $0.nextReview < $1.nextReview }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    PageTitle(title: "오답노트", subtitle: "1일 → 3일 → 7일 → 14일 간격으로 다시 풀고, 해설 안 보고 맞히면 다음 단계")
                    Spacer()
                    let due = store.due
                    Button {
                        appState.startReview(entries: due)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
                            Text(due.isEmpty ? "오늘 복습할 것 없음" : "오늘 복습 \(due.count)개 시작")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: !due.isEmpty))
                    .disabled(due.compactMap(\.problemID).isEmpty)
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
                if filtered.isEmpty {
                    EmptyStateView(icon: "bookmark", title: showGraduated ? "졸업한 항목이 없어요" : "오답노트가 비어 있어요",
                                   message: "틀리거나, 목표 시간을 넘기거나, 찍은 문제가 자동으로 들어와요.")
                        .frame(height: 300)
                } else {
                    VStack(spacing: 4) {
                        ForEach(filtered) { entry in row(entry) }
                    }
                    .padding(6)
                    .card()
                }
            }
            .padding(24)
        }
    }

    private func row(_ entry: MistakeEntry) -> some View {
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
                    if let pid = entry.problemID, appState.library.problem(pid) != nil, !entry.graduated {
                        Button("지금 풀기") { appState.startReview(entries: [entry]) }.buttonStyle(PillButtonStyle()).controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }
}

// MARK: - Stage 3 placeholders

struct PastPaperView: View {
    @Bindable var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "기출 트래커", subtitle: "연도 × 1~25번 · AoPS Wiki 링크 · 오답노트로 보내기")
            EmptyStateView(icon: "tablecells", title: "다음 단계에서 열려요",
                           message: "2000~2023년(2021년은 시행되지 않았어요) 그리드와 2024~2026년 잠금 토글이 들어옵니다. 지금까지 기록된 칸: \(appState.papers.solvedCount)개")
        }
        .padding(24)
    }
}

struct MockExamView: View {
    @Bindable var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "실전 모의고사", subtitle: "25문항 40분 · OMR · 구간별 시간 분석 · 종이 기출 모드")
            EmptyStateView(icon: "timer", title: "다음 단계에서 열려요", message: "유닛 1 피드백을 반영한 뒤 오리지널 25문항 세트 4개와 종이 기출 모드가 들어옵니다.")
        }
        .padding(24)
    }
}

struct StatsView: View {
    @Bindable var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "통계", subtitle: "분야별 정답률과 평균 시간 추이 · 막힌 이유 분포 · 숙련도 변화")
            EmptyStateView(icon: "chart.bar", title: "다음 단계에서 열려요", message: "지금까지 기록된 시도: \(appState.progress.attempts.count)개")
        }
        .padding(24)
    }
}
