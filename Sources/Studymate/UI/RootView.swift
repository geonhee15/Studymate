import SwiftUI

struct RootView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !appState.chromeHidden {
                SubjectTabBar(selection: $appState.subject)
                    .padding(.leading, 78)   // room for the traffic lights
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            switch appState.subject {
            case .amc8:
                AMC8View(appState: appState)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(Theme.accent)
        .ignoresSafeArea()
    }
}

/// Icon + name per subject, like the ATFM top tab bar. New subjects only need a `Subject` case.
struct SubjectTabBar: View {
    @Binding var selection: Subject
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Subject.allCases) { subject in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = subject }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: subject.icon).font(.system(size: 12, weight: .semibold))
                        Text(subject.title).font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(selection == subject ? Theme.accent : Color.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == subject ? Theme.accent.opacity(0.16) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("Studymate")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(3)
        .card(radius: 11)
    }
}

/// Sidebar + detail for the AMC 8 subject.
struct AMC8View: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            if !appState.chromeHidden {
                AMC8Sidebar(appState: appState)
                    .frame(width: 228)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider().opacity(0.5)
            }
            ZStack {
                if let session = appState.session {
                    ProblemSessionView(appState: appState, session: session)
                        .id(ObjectIdentifier(session))
                        .transition(.opacity)
                } else {
                    detail
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.route {
        case .home: HomeView(appState: appState)
        case .unit(let n):
            if let unit = appState.library.unit(n) { UnitView(appState: appState, unit: unit) } else { missing }
        case .lesson(let id):
            if let lesson = appState.library.lesson(id), let unit = appState.library.unit(lesson.unit) {
                LessonView(appState: appState, lesson: lesson, unit: unit).id(lesson.id)
            } else { missing }
        case .cheatsheet: CheatsheetView(appState: appState)
        case .mistakes: MistakeNotebookView(appState: appState)
        case .pastpapers: PastPaperView(appState: appState)
        case .mock: MockExamView(appState: appState)
        case .stats: StatsView(appState: appState)
        case .settings: SettingsView(appState: appState)
        }
    }

    private var missing: some View {
        EmptyStateView(icon: "questionmark.folder", title: "콘텐츠가 없어요", message: "Resources/Content/amc8 에서 해당 유닛 파일을 찾지 못했어요.")
    }
}

struct AMC8Sidebar: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var scheme

    private var current: SidebarItem { appState.route.sidebarItem }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                row(.home, icon: "house", title: "홈")
                SectionLabel(text: "유닛").padding(.top, 14).padding(.bottom, 4).padding(.leading, 10)
                ForEach(appState.library.units) { unit in
                    unitRow(unit)
                }
                SectionLabel(text: "연습").padding(.top, 14).padding(.bottom, 4).padding(.leading, 10)
                row(.mistakes, icon: "bookmark", title: "오답노트", badge: appState.mistakes.due.count)
                row(.pastpapers, icon: "tablecells", title: "기출 트래커")
                row(.mock, icon: "timer", title: "실전 모의고사")
                row(.stats, icon: "chart.bar", title: "통계")
                SectionLabel(text: "참고").padding(.top, 14).padding(.bottom, 4).padding(.leading, 10)
                row(.cheatsheet, icon: "rectangle.on.rectangle", title: "치트시트")
                row(.settings, icon: "gearshape", title: "설정")
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
    }

    private func row(_ item: SidebarItem, icon: String, title: String, badge: Int = 0) -> some View {
        SidebarRow(icon: icon, title: title, selected: current == item, badge: badge) {
            appState.open(item.route)
        }
    }

    private func unitRow(_ unit: Unit) -> some View {
        let progress = appState.progress.unitProgress(unit)
        return SidebarRow(icon: unit.icon, title: "\(unit.number). \(unit.title)", selected: current == .unit(unit.number), progress: progress) {
            appState.open(.unit(unit.number))
        }
    }
}

struct SidebarRow: View {
    var icon: String
    var title: String
    var selected: Bool
    var badge: Int = 0
    var progress: Double? = nil
    var action: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Color.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                    if let progress, progress > 0 {
                        ProgressBar(fraction: progress, color: Theme.accent, height: 3).frame(width: 90)
                    }
                }
                Spacer(minLength: 4)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Capsule().fill(Theme.accent))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Theme.sidebarSelection(scheme) : (hovering ? Theme.hoverFill(scheme) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
