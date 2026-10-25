import Foundation

/// Development switches (see README "개발용 환경 변수").
///   STUDYMATE_TAB=home|unit:1|lesson:1-1|practice:1-1|quiz:1|test:1|mistakes|review|pastpapers|mock[:1]|paper:2019|stats|cheatsheet|settings
///     (review = 오답노트의 활성 항목으로 복습 세션 시작)
///   STUDYMATE_SNAPSHOT=/path/out.png   STUDYMATE_SNAPSHOT_DELAY=3   STUDYMATE_SNAPSHOT_QUIT=1   STUDYMATE_SNAPSHOT_SCREEN=1 (시트 포함)
///   STUDYMATE_WINDOW=1180x760          window size for the run (not saved)
///   STUDYMATE_DEBUG_DATA_DIR=<dir>     read/write user data there instead of Application Support
///   STUDYMATE_DEBUG_SAMPLE=1           seed sample progress/mistakes into the (debug) data dir for screenshots
///   STUDYMATE_DEBUG_PROBLEM=select:C|hint:2|guess|submit:B|next|stuck   drive the problem screen for snapshots
///     mock: answer:B|go:12|next|fill:C|finish   paper: fill:C|grade|mark
///   STUDYMATE_DEBUG_LANG=ko            start the problem screen in Korean
///   STUDYMATE_DEBUG_FLASHCARDS=1       cheatsheet in flashcard mode
///   STUDYMATE_DEBUG_SCROLL=examples    lesson screen scrolls to a section (why|basics|intuition|examples|tips|pitfalls)
///   STUDYMATE_DEBUG_SCRATCH=open,sample,figure,text,viewer   open the 연습장 panel (sample strokes + text, figure underlay,
///     text mode); viewer = open the saved-pad viewer from the first thumbnail (오답노트, 결과); pane = 모의고사 결과의 내 연습장 pane
///   STUDYMATE_DEBUG_KEYS=n,focus,c,esc,c,cmd+z   post key events (and focus/draw/line/erase/stress steps) one by one, log the state after each
///   STUDYMATE_DEBUG_THEME=jarvis       STUDYMATE_DEBUG_APPEARANCE=dark   skin / appearance for this run only
enum DebugEnv {
    static let env = ProcessInfo.processInfo.environment

    static var startTab: String? { env["STUDYMATE_TAB"] }
    static var snapshotPath: String? { env["STUDYMATE_SNAPSHOT"] }
    static var snapshotDelay: Double { Double(env["STUDYMATE_SNAPSHOT_DELAY"] ?? "") ?? 2.5 }
    static var snapshotQuits: Bool { env["STUDYMATE_SNAPSHOT_QUIT"] == "1" }
    /// Capture the on-screen window rect (includes sheets and popovers) instead of the window alone.
    static var snapshotIncludesSheets: Bool { env["STUDYMATE_SNAPSHOT_SCREEN"] == "1" }
    static var seedSample: Bool { env["STUDYMATE_DEBUG_SAMPLE"] == "1" }
    static var problemScript: String? { env["STUDYMATE_DEBUG_PROBLEM"] }
    static var startLanguage: String? { env["STUDYMATE_DEBUG_LANG"] }
    static var flashcards: Bool { env["STUDYMATE_DEBUG_FLASHCARDS"] == "1" }
    static var lessonScroll: String? { env["STUDYMATE_DEBUG_SCROLL"] }
    static var scratch: String? { env["STUDYMATE_DEBUG_SCRATCH"] }
    static var scratchFlags: Set<String> { Set((scratch ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }) }
    static var keys: String? { env["STUDYMATE_DEBUG_KEYS"] }

    static var windowSize: CGSize? {
        guard let spec = env["STUDYMATE_WINDOW"] else { return nil }
        let parts = spec.lowercased().split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }
}
