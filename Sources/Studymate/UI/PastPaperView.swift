import AppKit
import SwiftUI

/// 기출 트래커: years × 1~25 grid. Cells open an editor popover; wrong/slow/guessed cells can be sent to the notebook.
struct PastPaperView: View {
    @Bindable var appState: AppState
    @State private var editing: (year: Int, number: Int)?
    @Environment(\.colorScheme) private var scheme

    private var store: PastPaperStore { appState.papers }

    var body: some View {
        ScrollView([.vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    PageTitle(title: "기출 트래커", subtitle: "종이로 푼 실제 기출 기록. 칸을 누르면 상태를 적고 AoPS Wiki 문제 페이지를 열 수 있어요")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Toggle(isOn: Binding(get: { store.reservedLocked }, set: { store.reservedLocked = $0 })) {
                            Text("2024~2026은 실전 모의고사용으로 아껴두기").font(.system(size: 12))
                        }
                        .toggleStyle(.switch).controlSize(.small)
                        let pending = store.pendingForNotebook
                        Button {
                            sendAllPending()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "bookmark").font(.system(size: 11, weight: .semibold))
                                Text(pending.isEmpty ? "오답노트로 보낼 것 없음" : "틀림·오래 걸림·찍음 \(pending.count)개 오답노트로")
                            }
                        }
                        .buttonStyle(PillButtonStyle(prominent: !pending.isEmpty))
                        .disabled(pending.isEmpty)
                    }
                }
                legend
                grid
                Text("2021년은 AMC 8이 시행되지 않았어요 (MAA가 2022년부터 1월 시행으로 옮기면서 건너뜀). 문제 본문은 앱에 없고, 칸의 링크로 AoPS Wiki를 엽니다.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(24)
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(PaperStatus.allCases) { status in
                HStack(spacing: 5) {
                    PaperCellView(status: status, number: nil, compact: true)
                    Text(status.title).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("기록 \(store.solvedCount)칸").font(.system(size: 11.5)).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private var grid: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Text("연도").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                ForEach(1...PastPaperStore.problemCount, id: \.self) { n in
                    Text("\(n)").font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        .frame(width: 26)
                }
                Text("점수").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            }
            ForEach(store.visibleYears.reversed(), id: \.self) { year in
                yearRow(year)
            }
        }
        .padding(10)
        .card()
    }

    private func yearRow(_ year: Int) -> some View {
        let cells = store.cells(year: year)
        let solved = cells.filter { $0.status != .unsolved }.count
        let right = cells.filter { $0.status == .correct || $0.status == .slow || $0.status == .guessed }.count
        let reserved = PastPaperStore.reservedYears.contains(year)
        return HStack(spacing: 3) {
            HStack(spacing: 3) {
                Text(String(year)).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                if reserved { Image(systemName: "lock.open").font(.system(size: 9)).foregroundStyle(.tertiary) }
            }
            .frame(width: 44, alignment: .leading)
            ForEach(1...PastPaperStore.problemCount, id: \.self) { n in
                let cell = cells[n - 1]
                Button {
                    editing = (year, n)
                } label: {
                    PaperCellView(status: cell.status, number: n, compact: false)
                }
                .buttonStyle(.plain)
                .help(cellHelp(year: year, number: n, cell: cell))
                .popover(isPresented: Binding(get: { editing?.year == year && editing?.number == n }, set: { if !$0 { editing = nil } }), arrowEdge: .bottom) {
                    PaperCellEditor(appState: appState, year: year, number: n)
                }
            }
            Text(solved > 0 ? "\(right)/\(solved)" : "")
                .font(.system(size: 11.5, design: .rounded)).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func cellHelp(year: Int, number: Int, cell: PaperCell) -> String {
        var parts = ["\(year) AMC 8 \(number)번", cell.status.title]
        if let s = cell.seconds { parts.append(Format.duration(s)) }
        if !cell.fields.isEmpty { parts.append(cell.fields.map(\.title).joined(separator: ", ")) }
        if !cell.note.isEmpty { parts.append(cell.note) }
        return parts.joined(separator: " · ")
    }

    private func sendAllPending() {
        for item in store.pendingForNotebook {
            appState.sendPaperToNotebook(year: item.year, number: item.number)
        }
    }
}

struct PaperCellView: View {
    var status: PaperStatus
    var number: Int?
    var compact: Bool
    @Environment(\.colorScheme) private var scheme

    private var color: Color {
        switch status {
        case .unsolved: return .clear
        case .correct: return Theme.correct
        case .wrong: return Theme.wrong
        case .slow: return .orange
        case .guessed: return Color(red: 0.85, green: 0.65, blue: 0.1)
        }
    }

    var body: some View {
        let size: CGFloat = compact ? 14 : 24
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 3 : 5, style: .continuous)
                .fill(status == .unsolved ? Theme.chipFill(scheme) : color.opacity(0.85))
            if status != .unsolved {
                Image(systemName: status.icon)
                    .font(.system(size: compact ? 7 : 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: compact ? size : 26, height: size)
    }
}

/// Editor for one (year, number) cell.
struct PaperCellEditor: View {
    @Bindable var appState: AppState
    let year: Int
    let number: Int
    @State private var status: PaperStatus = .unsolved
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var fields: Set<Field> = []
    @State private var note = ""

    private var store: PastPaperStore { appState.papers }
    private var inNotebook: Bool { appState.mistakes.entry(for: .pastPaper(year: year, number: number)) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(String(year)) AMC 8 · \(number)번").font(.system(size: 14, weight: .bold))
                Chip(text: Band.forNumber(number).title, icon: "chart.bar")
                Spacer()
                Button {
                    NSWorkspace.shared.open(PastPaperStore.aopsURL(year: year, number: number))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "safari").font(.system(size: 11, weight: .semibold))
                        Text("AoPS에서 열기")
                    }
                }
                .buttonStyle(PillButtonStyle())
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "상태")
                HStack(spacing: 5) {
                    ForEach(PaperStatus.allCases) { s in
                        Button {
                            status = s
                            save()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: s.icon).font(.system(size: 10, weight: .bold))
                                Text(s.title)
                            }
                        }
                        .buttonStyle(PillButtonStyle(prominent: status == s))
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "걸린 시간")
                    HStack(spacing: 4) {
                        TextField("분", text: $minutes).textFieldStyle(.roundedBorder).frame(width: 44)
                        Text("분").font(.system(size: 12)).foregroundStyle(.secondary)
                        TextField("초", text: $seconds).textFieldStyle(.roundedBorder).frame(width: 44)
                        Text("초").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "분야")
                    HStack(spacing: 4) {
                        ForEach(Field.allCases) { f in
                            Button {
                                if fields.contains(f) { fields.remove(f) } else { fields.insert(f) }
                                save()
                            } label: {
                                Text(f.title).font(.system(size: 11))
                            }
                            .buttonStyle(PillButtonStyle(prominent: fields.contains(f)))
                            .controlSize(.small)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "메모")
                TextField("핵심 아이디어, 틀린 이유 …", text: $note, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            }
            HStack {
                if status.needsReview {
                    Button {
                        appState.sendPaperToNotebook(year: year, number: number, note: note, fields: Array(fields))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: inNotebook ? "bookmark.fill" : "bookmark").font(.system(size: 10, weight: .bold))
                            Text(inNotebook ? "오답노트에 있음 · 다시 보내기" : "오답노트로 보내기")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: !inNotebook))
                }
                Spacer()
                Text("자동 저장").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 520)
        .onAppear(perform: load)
        .onChange(of: minutes) { _, _ in save() }
        .onChange(of: seconds) { _, _ in save() }
        .onChange(of: note) { _, _ in save() }
    }

    private func load() {
        let cell = store.cell(year: year, number: number)
        status = cell.status
        if let s = cell.seconds { minutes = "\(s / 60)"; seconds = "\(s % 60)" }
        fields = Set(cell.fields)
        note = cell.note
    }

    private func save() {
        let total: Int? = {
            let m = Int(minutes) ?? 0, s = Int(seconds) ?? 0
            return minutes.isEmpty && seconds.isEmpty ? nil : m * 60 + s
        }()
        store.update(year: year, number: number) { cell in
            cell.status = status
            cell.seconds = total
            cell.fields = Array(fields).sorted { $0.rawValue < $1.rawValue }
            cell.note = note
        }
    }
}
