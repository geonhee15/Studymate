import SwiftUI

struct UnitView: View {
    @Bindable var appState: AppState
    let unit: Unit
    @Environment(\.colorScheme) private var scheme

    private var progress: ProgressStore { appState.progress }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "유닛 \(unit.number)")
                        Text(unit.title).font(.system(size: 26, weight: .bold))
                        if let en = unit.titleEn { Text(en).font(.system(size: 13)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    unitProgress
                }
                VStack(spacing: 6) {
                    ForEach(unit.lessons) { lesson in
                        lessonRow(lesson)
                    }
                }
                .padding(8)
                .card()
                HStack(spacing: 12) {
                    setCard(kind: .quiz, problems: unit.quiz, description: "8문제 · 6개 이상 맞히면 통과 → 익숙한 레슨이 숙련으로")
                    setCard(kind: .test, problems: unit.test, description: "15문제 · 12개 이상 맞히면 통과 → 7일 뒤 재확인까지 통과하면 마스터")
                }
            }
            .padding(24)
        }
    }

    private var unitProgress: some View {
        let levels = unit.lessons.map { progress.mastery(lesson: $0) }
        return VStack(alignment: .trailing, spacing: 6) {
            Text(Format.percent(progress.unitProgress(unit)))
                .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Theme.accent)
            MasteryStrip(levels: levels).frame(width: 160)
            MasteryLegend()
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let level = progress.mastery(lesson: lesson)
        let accuracy = progress.recentAccuracy(lessonID: lesson.id)
        return CardButton(action: { appState.open(.lesson(lesson.id)) }) {
            HStack(spacing: 12) {
                Image(systemName: level.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(level == .none ? Color.secondary.opacity(0.5) : Theme.mastery(level))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(lesson.id).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                        Text(lesson.title).font(.system(size: 14, weight: .semibold))
                    }
                    HStack(spacing: 6) {
                        if let en = lesson.titleEn { Text(en).font(.system(size: 11.5)).foregroundStyle(.secondary) }
                        Text("예제 \(lesson.examples.count)개 · 연습문제 \(lesson.problems.count)개")
                            .font(.system(size: 11.5)).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if let accuracy {
                    Text("정답률 \(Format.percent(accuracy))").font(.system(size: 11.5)).foregroundStyle(.secondary).monospacedDigit()
                }
                MasteryPips(level: level)
                MasteryBadge(level: level)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
        }
    }

    private func setCard(kind: ProblemSetKind, problems: [Problem], description: String) -> some View {
        let best = progress.bestResult(unit: unit.number, kind: kind)
        let last = progress.lastResult(unit: unit.number, kind: kind)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: kind == .quiz ? "checkmark.seal" : "rosette").foregroundStyle(Theme.accent)
                Text(kind.title).font(.system(size: 14, weight: .semibold))
                Spacer()
                if let best {
                    Chip(text: "최고 \(best.score)/\(best.total)", icon: best.passed ? "checkmark" : nil, color: best.passed ? Theme.correct : .secondary)
                }
            }
            Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
            if let last {
                Text("마지막 \(Format.shortDate(last.date)) · \(last.score)/\(last.total) · \(Format.duration(Int(last.seconds)))")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            HStack {
                Spacer()
                if problems.isEmpty {
                    Text("준비 중").font(.system(size: 12)).foregroundStyle(.tertiary)
                } else {
                    Button(best == nil ? "시작" : "다시 풀기") {
                        if kind == .quiz { appState.startQuiz(unit: unit) } else { appState.startTest(unit: unit) }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
