import Foundation

/// Fills a scratch data folder with believable progress for screenshots (STUDYMATE_DEBUG_SAMPLE=1 + STUDYMATE_DEBUG_DATA_DIR).
@MainActor
enum SampleData {
    static func seed(library: ContentLibrary, progress: ProgressStore, mistakes: MistakeStore, papers: PastPaperStore) {
        guard progress.attempts.isEmpty else { return }
        let cal = Calendar.current
        func daysAgo(_ d: Int, hour: Int = 20) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -d, to: Date())!)!
        }
        // Unit 1: lessons 1-1, 1-2 solid, 1-3 shaky, 1-4 just started.
        let plan: [(String, Int, [Bool], Int)] = [
            ("1-1", 9, [true, true, true, false, true, true, true, true, true, true], 1),
            ("1-2", 8, [true, true, false, true, true, true, true, true], 2),
            ("1-3", 7, [true, false, false, true, true, false, true], 3),
            ("1-4", 3, [true, false, true], 0),
        ]
        for (lesson, count, pattern, dayOffset) in plan {
            let problems = library.lesson(lesson)?.problems ?? []
            for i in 0..<count {
                let p = problems.isEmpty ? nil : problems[i % problems.count]
                let correct = pattern[i % pattern.count]
                let seconds = Double(60 + (i * 37) % 90)
                progress.record(Attempt(problemID: p?.id ?? "\(lesson)-\(i + 1)", lesson: lesson, unit: 1, kind: .practice,
                                        chosen: correct ? (p?.answer ?? "C") : "B", correct: correct, seconds: seconds,
                                        targetSeconds: p?.targetSeconds ?? 90, hintsUsed: correct ? 0 : 1, guessed: false,
                                        date: daysAgo(dayOffset + (count - i) / 4), reason: correct ? nil : .idea, fields: p?.fields ?? [.counting]))
            }
        }
        progress.record(SetResult(unit: 1, kind: .quiz, score: 6, total: 8, date: daysAgo(1), seconds: 540))
        progress.markOpened(lesson: "1-4")

        let p13 = library.lesson("1-3")?.problems.first
        mistakes.add(source: .problem(id: p13?.id ?? "1-3-1", lesson: "1-3"), fields: [.counting], reason: .idea,
                     keyIdea: "둘 다의 배수는 최소공배수의 배수. 6과 8이면 24.", myNote: "6×8=48로 나눠서 틀림")
        let p12 = library.lesson("1-2")?.problems.dropFirst(2).first
        mistakes.add(source: .problem(id: p12?.id ?? "1-2-3", lesson: "1-2"), fields: [.probability, .counting], reason: .misread,
                     keyIdea: "'적어도 2개'의 반대는 '0개 또는 1개'", myNote: "")
        mistakes.add(source: .pastPaper(year: 2019, number: 17), fields: [.geometry], reason: .concept,
                     keyIdea: "기울어진 정사각형은 감싸는 정사각형에서 귀퉁이 삼각형 4개를 뺀다", myNote: "")

        for (year, statuses) in [(2023, "cccwcsccgc"), (2022, "cccccwcc"), (2020, "ccwc")] {
            for (i, ch) in statuses.enumerated() {
                let status: PaperStatus = ch == "c" ? .correct : ch == "w" ? .wrong : ch == "s" ? .slow : .guessed
                papers.update(year: year, number: 11 + i) { cell in
                    cell.status = status
                    cell.seconds = 60 + i * 20
                    cell.fields = [i % 3 == 0 ? .counting : i % 3 == 1 ? .numberTheory : .geometry]
                }
            }
        }
    }
}
