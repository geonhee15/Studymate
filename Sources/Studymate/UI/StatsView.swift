import Charts
import SwiftUI

/// 통계: field accuracy and time, weekly trend, stuck reasons, mastery over time, mock scores.
struct StatsView: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var scheme

    private var progress: ProgressStore { appState.progress }
    private var attempts: [Attempt] { progress.attempts }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "통계", subtitle: "\(attempts.count)문제 풂 · 오답노트 \(appState.mistakes.active.count)개 진행 중 · 기출 \(appState.papers.solvedCount)칸")
                if attempts.isEmpty && appState.mocks.results.isEmpty {
                    EmptyStateView(icon: "chart.bar", title: "아직 기록이 없어요", message: "레슨 연습문제를 풀면 분야별 정답률과 추이가 여기에 쌓여요.").frame(height: 300)
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        fieldCard
                        reasonCard.frame(width: 330)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        weeklyCard
                        masteryCard
                    }
                    HStack(alignment: .top, spacing: 14) {
                        mockCard
                        paperCard
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: Field accuracy + time

    private struct FieldStat: Identifiable {
        let field: Field
        let correct: Int
        let total: Int
        let avgSeconds: Double
        let recentAccuracy: Double?
        var id: Field { field }
        var accuracy: Double { Double(correct) / Double(max(1, total)) }
    }

    private var fieldStats: [FieldStat] {
        Field.allCases.compactMap { f in
            let a = attempts.filter { $0.fields.contains(f) }
            guard !a.isEmpty else { return nil }
            let recent = a.suffix(10)
            return FieldStat(field: f, correct: a.filter(\.correct).count, total: a.count,
                             avgSeconds: a.map(\.seconds).reduce(0, +) / Double(a.count),
                             recentAccuracy: recent.count >= 3 ? Double(recent.filter(\.correct).count) / Double(recent.count) : nil)
        }
    }

    private var fieldCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "분야별 정답률과 평균 시간")
            if fieldStats.isEmpty { Text("기록 없음").font(.system(size: 12)).foregroundStyle(.secondary) }
            ForEach(fieldStats) { s in
                HStack(spacing: 10) {
                    Image(systemName: s.field.icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                    Text(s.field.title).font(.system(size: 12.5, weight: .medium)).frame(width: 64, alignment: .leading)
                    ProgressBar(fraction: s.accuracy, color: s.accuracy >= 0.7 ? Theme.correct : (s.accuracy < 0.5 ? Theme.wrong : Theme.accent), height: 7)
                    Text(Format.percent(s.accuracy)).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().frame(width: 40, alignment: .trailing)
                    Text("\(s.correct)/\(s.total)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit().frame(width: 48, alignment: .trailing)
                    Text("평균 \(Format.clock(s.avgSeconds))").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit().frame(width: 70, alignment: .trailing)
                    if let r = s.recentAccuracy {
                        let diff = r - s.accuracy
                        Text(diff >= 0.05 ? "↑ 최근 \(Format.percent(r))" : diff <= -0.05 ? "↓ 최근 \(Format.percent(r))" : "→ 최근 \(Format.percent(r))")
                            .font(.system(size: 11)).foregroundStyle(diff >= 0.05 ? Theme.correct : diff <= -0.05 ? Theme.wrong : Color.secondary)
                            .frame(width: 84, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Reasons

    private var reasonCard: some View {
        var counts: [StuckReason: Int] = [:]
        for a in attempts { if let r = a.reason { counts[r, default: 0] += 1 } }
        for e in appState.mistakes.entries where !counts.keys.contains(e.reason) || true {
            if case .pastPaper = e.source { counts[e.reason, default: 0] += 1 }
        }
        let total = max(1, counts.values.reduce(0, +))
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "막힌 이유 분포")
            if counts.isEmpty { Text("아직 없음").font(.system(size: 12)).foregroundStyle(.secondary) }
            ForEach(StuckReason.allCases) { r in
                let c = counts[r] ?? 0
                HStack(spacing: 8) {
                    Image(systemName: r.icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                    Text(r.title).font(.system(size: 12.5)).frame(width: 110, alignment: .leading)
                    ProgressBar(fraction: Double(c) / Double(total), color: .orange, height: 7)
                    Text("\(c)").font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                }
            }
            if let top = counts.max(by: { $0.value < $1.value }), top.value > 0 {
                Text(advice(for: top.key)).font(.system(size: 11.5)).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
        .padding(16)
        .card()
    }

    private func advice(for reason: StuckReason) -> String {
        switch reason {
        case .concept: return "개념이 제일 많이 막혀요. 해당 레슨의 기초 설명과 직관 예시를 다시 읽고 연습문제를 쉬운 것부터."
        case .idea: return "아이디어가 안 떠오를 때가 많아요. 막혔을 때 5가지 질문을 문제마다 순서대로 적용해 보세요."
        case .calculation: return "계산 실수가 많아요. 답을 고르기 전 홀짝·일의 자리·어림으로 한 번 더 거르세요."
        case .misread: return "문제를 잘못 읽는 경우가 많아요. not, least, greatest, 단위에 동그라미 치고 시작하세요."
        }
    }

    // MARK: Weekly trend

    private struct WeekPoint: Identifiable {
        let start: Date
        let label: String
        let count: Int
        let accuracy: Double?
        var id: Date { start }
    }

    private var weeks: [WeekPoint] {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<8).reversed().map { back in
            let start = cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            let a = attempts.filter { $0.date >= start && $0.date < end }
            let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M/d"
            return WeekPoint(start: start, label: f.string(from: start), count: a.count, accuracy: a.isEmpty ? nil : Double(a.filter(\.correct).count) / Double(a.count))
        }
    }

    private var weeklyCard: some View {
        let data = weeks
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "최근 8주: 푼 문제 수와 정답률")
            Chart {
                ForEach(data) { w in
                    BarMark(x: .value("주", w.label), y: .value("문제", w.count))
                        .foregroundStyle(Theme.accent.opacity(0.35))
                        .cornerRadius(3)
                }
                ForEach(data.filter { $0.accuracy != nil }) { w in
                    LineMark(x: .value("주", w.label), y: .value("정답률", (w.accuracy ?? 0) * Double(max(1, data.map(\.count).max() ?? 1))))
                        .foregroundStyle(Theme.correct)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary) }
            }
            .frame(height: 160)
            HStack(spacing: 10) {
                HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Theme.accent.opacity(0.35)).frame(width: 10, height: 10); Text("푼 문제 수").font(.system(size: 11)).foregroundStyle(.secondary) }
                HStack(spacing: 4) { Circle().fill(Theme.correct).frame(width: 8, height: 8); Text("정답률 (막대 높이 기준 0~100%)").font(.system(size: 11)).foregroundStyle(.secondary) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Mastery over time

    private struct MasteryPoint: Identifiable {
        let label: String
        let level: MasteryLevel
        let count: Int
        var id: String { label + level.title }
    }

    private var masteryHistory: [MasteryPoint] {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        var points: [MasteryPoint] = []
        let lessons = appState.library.allLessons
        for back in (0..<8).reversed() {
            let end = cal.date(byAdding: .weekOfYear, value: 1 - back, to: thisWeek)!
            let a = attempts.filter { $0.date < end }
            let r = progress.results.filter { $0.date < end }
            var counts: [MasteryLevel: Int] = [:]
            for l in lessons {
                let level = MasteryEngine.level(lessonID: l.id, unit: l.unit, attempts: a, results: r)
                if level != .none { counts[level, default: 0] += 1 }
            }
            let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M/d"
            let label = f.string(from: cal.date(byAdding: .weekOfYear, value: -1, to: end)!)
            for level in MasteryLevel.allCases where level != .none {
                points.append(MasteryPoint(label: label, level: level, count: counts[level] ?? 0))
            }
        }
        return points
    }

    private var masteryCard: some View {
        let data = masteryHistory
        let current = Dictionary(grouping: appState.library.allLessons.map { progress.mastery(lesson: $0) }, by: { $0 }).mapValues(\.count)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "숙련도 변화 (레슨 수)")
                Spacer()
                ForEach(MasteryLevel.allCases.filter { $0 != .none }, id: \.self) { level in
                    HStack(spacing: 3) {
                        Circle().fill(Theme.mastery(level)).frame(width: 7, height: 7)
                        Text("\(level.title) \(current[level] ?? 0)").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                }
            }
            Chart(data) { p in
                BarMark(x: .value("주", p.label), y: .value("레슨", p.count))
                    .foregroundStyle(Theme.mastery(p.level))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary) } }
            .frame(height: 160)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Mocks and past papers

    private var mockCard: some View {
        let results = appState.mocks.results.sorted { $0.date < $1.date }
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "모의고사 점수 추이")
            if results.isEmpty {
                Text("아직 모의고사 기록이 없어요").font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                Chart(Array(results.enumerated()), id: \.offset) { i, r in
                    LineMark(x: .value("회", i + 1), y: .value("점수", r.score)).foregroundStyle(Theme.accent).interpolationMethod(.catmullRom)
                    PointMark(x: .value("회", i + 1), y: .value("점수", r.score)).foregroundStyle(r.kind == .app ? Theme.accent : .orange)
                }
                .chartYScale(domain: 0...25)
                .chartYAxis { AxisMarks(position: .leading, values: [0, 5, 10, 15, 20, 25]) { _ in AxisGridLine().foregroundStyle(Color.primary.opacity(0.08)); AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary) } }
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary) } }
                .frame(height: 140)
                HStack(spacing: 10) {
                    HStack(spacing: 4) { Circle().fill(Theme.accent).frame(width: 8, height: 8); Text("앱 세트").font(.system(size: 11)).foregroundStyle(.secondary) }
                    HStack(spacing: 4) { Circle().fill(Color.orange).frame(width: 8, height: 8); Text("종이 기출").font(.system(size: 11)).foregroundStyle(.secondary) }
                    Spacer()
                    let avg = Double(results.map(\.score).reduce(0, +)) / Double(results.count)
                    Text("평균 \(String(format: "%.1f", avg))점 · 최고 \(results.map(\.score).max() ?? 0)점").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var paperCard: some View {
        let store = appState.papers
        var byBand: [(String, Int, Int)] = []
        for (title, range) in [("1~10번", 1...10), ("11~15번", 11...15), ("16~20번", 16...20), ("21~25번", 21...25)] {
            var right = 0, total = 0
            for y in PastPaperStore.years + PastPaperStore.reservedYears {
                for n in range {
                    let c = store.cell(year: y, number: n)
                    if c.status != .unsolved { total += 1; if c.status != .wrong { right += 1 } }
                }
            }
            byBand.append((title, right, total))
        }
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "기출 번호대별 정답률")
            if store.solvedCount == 0 {
                Text("기출 트래커에 기록하면 번호대별로 보여요").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(byBand, id: \.0) { title, right, total in
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 12.5)).frame(width: 60, alignment: .leading)
                    ProgressBar(fraction: total == 0 ? 0 : Double(right) / Double(total), color: Theme.accent, height: 7)
                    Text(total == 0 ? "–" : "\(right)/\(total)").font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                }
            }
            Text("찍어서 맞힌 것과 오래 걸린 것도 '맞음'으로 셉니다.").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 330, alignment: .leading)
        .card()
    }
}
