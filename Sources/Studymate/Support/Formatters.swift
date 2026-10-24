import Foundation

enum Format {
    /// "1:05" / "12:30"
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// "40분", "1분 30초", "45초"
    static func duration(_ seconds: Int) -> String {
        if seconds >= 60, seconds % 60 == 0 { return "\(seconds / 60)분" }
        if seconds >= 60 { return "\(seconds / 60)분 \(seconds % 60)초" }
        return "\(seconds)초"
    }

    static func percent(_ fraction: Double) -> String {
        String(format: "%.0f%%", fraction * 100)
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR")))
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR")))
    }

    /// "오늘", "내일", "3일 뒤", "2일 지남"
    static func relativeDay(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "오늘" }
        if days == 1 { return "내일" }
        if days > 1 { return "\(days)일 뒤" }
        return "\(-days)일 지남"
    }
}

enum ExamInfo {
    /// AMC 8, 2027-01-22 19:30 KST.
    static let date: Date = {
        var comps = DateComponents()
        comps.year = 2027; comps.month = 1; comps.day = 22; comps.hour = 19; comps.minute = 30
        comps.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    /// Whole days until the exam day (D-0 on the day itself, negative afterwards).
    static func daysLeft(now: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
    }

    static var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy년 M월 d일 (E) HH:mm"
        return f.string(from: date)
    }
}
