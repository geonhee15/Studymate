import SwiftUI

struct HomeView: View {
    @Bindable var appState: AppState

    private var library: ContentLibrary { appState.library }
    private var progress: ProgressStore { appState.progress }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ddayCard
                    todayCard
                }
                HStack(alignment: .top, spacing: 14) {
                    masteryCard
                    VStack(spacing: 14) {
                        StuckQuestionsCard()
                        examInfoCard
                    }
                    .frame(width: 330)
                }
            }
            .padding(24)
        }
    }

    // MARK: D-day

    private var ddayCard: some View {
        let days = ExamInfo.daysLeft()
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "AMC 8까지")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(days >= 0 ? "D-\(days)" : "D+\(-days)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                if days == 0 { Text("오늘").font(.system(size: 15, weight: .semibold)) }
            }
            Text(ExamInfo.dateText)
                .font(.system(size: 13)).foregroundStyle(.secondary)
            Text("25문항 · 40분 · 오답 감점 없음")
                .font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(width: 260, alignment: .leading)
        .card()
    }

    // MARK: Today

    private var todayCard: some View {
        let due = appState.mistakes.due
        let resume = resumeLesson
        let todayCount = progress.attemptsToday.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "오늘 할 것")
                Spacer()
                if todayCount > 0 {
                    Text("오늘 \(todayCount)문제 풂").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            CardButton(prominent: !due.isEmpty, action: {
                if due.isEmpty { appState.open(.mistakes) } else { appState.startReview(entries: due) }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "bookmark.fill").foregroundStyle(due.isEmpty ? Color.secondary : Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(due.isEmpty ? "복습 예정인 오답 없음" : "복습 예정인 오답 \(due.count)개")
                            .font(.system(size: 13, weight: .semibold))
                        Text(due.isEmpty ? "틀린 문제는 1일 → 3일 → 7일 → 14일 간격으로 다시 나와요" : dueSummary(due))
                            .font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(10)
            }
            CardButton(prominent: due.isEmpty, action: {
                if let lesson = resume { appState.open(.lesson(lesson.id)) } else { appState.open(.unit(1)) }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "book.fill").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(resume.map { "이어서: \($0.id) \($0.title)" } ?? "유닛 1부터 시작하기")
                            .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(resumeHint)
                            .font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(10)
            }
            let weak = appState.mistakes.weakFields()
            if !weak.isEmpty {
                HStack(spacing: 6) {
                    Text("이번 주 약한 분야").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    ForEach(weak, id: \.field) { w in
                        Chip(text: "\(w.field.title) \(w.count)", icon: w.field.icon, color: Theme.wrong)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func dueSummary(_ due: [MistakeEntry]) -> String {
        let fields = Set(due.flatMap(\.fields)).map(\.title).sorted().prefix(3).joined(separator: ", ")
        return fields.isEmpty ? "오답노트에서 복습 시작" : fields
    }

    /// The lesson to continue with: the last opened one unless it is already proficient, then the next unfinished one.
    private var resumeLesson: Lesson? {
        if let last = progress.lastLessonID, let lesson = library.lesson(last) {
            if progress.mastery(lesson: lesson) < .proficient { return lesson }
            if let next = library.lesson(after: last) { return next }
        }
        return library.allLessons.first { progress.mastery(lesson: $0) < .proficient } ?? library.allLessons.first
    }

    private var resumeHint: String {
        guard let lesson = resumeLesson else { return "" }
        let level = progress.mastery(lesson: lesson)
        if let acc = progress.recentAccuracy(lessonID: lesson.id) {
            return "\(level.title) · 최근 정답률 \(Format.percent(acc)) · 연습문제 \(lesson.problems.count)개"
        }
        return lesson.problems.isEmpty ? "레슨 읽기" : "레슨 읽고 연습문제 \(lesson.problems.count)개"
    }

    // MARK: Mastery

    private var masteryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "유닛별 숙련도")
                Spacer()
                MasteryLegend()
            }
            ForEach(library.units) { unit in
                let levels = unit.lessons.map { progress.mastery(lesson: $0) }
                CardButton(action: { appState.open(.unit(unit.number)) }) {
                    HStack(spacing: 10) {
                        Image(systemName: unit.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("\(unit.number). \(unit.title)").font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text(masterySummary(levels)).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                            }
                            MasteryStrip(levels: levels)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func masterySummary(_ levels: [MasteryLevel]) -> String {
        let mastered = levels.filter { $0 == .mastered }.count
        let proficient = levels.filter { $0 >= .proficient }.count
        if levels.allSatisfy({ $0 == .none }) { return "\(levels.count)개 레슨" }
        return "숙련 \(proficient) · 마스터 \(mastered) / \(levels.count)"
    }

    private var examInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").foregroundStyle(Theme.accent)
                Text("시험 기본 정보").font(.system(size: 14, weight: .semibold))
            }
            infoRow("25문항, 5지선다, 40분. 맞으면 1점, 틀리거나 비워도 0점. 오답 감점 없음 → 빈칸은 무조건 손해.")
            infoRow("계산기, 컴퍼스, 각도기, 모눈종이 금지. 빈 연습지와 자, 지우개만.")
            infoRow("그림은 축척대로 그려져 있지 않을 수 있다.")
            infoRow("권장 시간 배분: 1~10번 10분, 11~20번 15분, 21~25번 15분.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 4, height: 4).padding(.top, 7)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

/// One segment per lesson, colored by its mastery level.
struct MasteryStrip: View {
    var levels: [MasteryLevel]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(level == .none ? Color.primary.opacity(0.08) : Theme.mastery(level))
                    .frame(height: 7)
            }
        }
    }
}

struct MasteryLegend: View {
    @State private var showRules = false
    var body: some View {
        HStack(spacing: 8) {
            ForEach(MasteryLevel.allCases.filter { $0 != .none }, id: \.self) { level in
                HStack(spacing: 3) {
                    Circle().fill(Theme.mastery(level)).frame(width: 7, height: 7)
                    Text(level.title).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Button { showRules.toggle() } label: {
                Image(systemName: "questionmark.circle").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showRules, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("숙련도 기준").font(.system(size: 13, weight: .semibold))
                    Text(MasteryEngine.explanation).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(width: 360)
            }
        }
    }
}
