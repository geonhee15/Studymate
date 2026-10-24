import SwiftUI

struct LessonView: View {
    @Bindable var appState: AppState
    let lesson: Lesson
    let unit: Unit
    @State private var bridge = WebBridge()
    @State private var currentAnchor = "why"
    @Environment(\.colorScheme) private var scheme

    private var progress: ProgressStore { appState.progress }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            MathWebView(bridge: bridge)
                .onAppear {
                    bridge.setContent(WebTemplate.lesson(lesson, unit: unit))
                    bridge.run("sm.initExamples();")
                    if let anchor = DebugEnv.lessonScroll {   // snapshots: land on a section once KaTeX has laid out
                        currentAnchor = anchor
                        bridge.run("setTimeout(function () { sm.scrollToAnchor(\(WebTemplate.jsString(anchor))); }, 600);")
                    }
                }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { appState.open(.unit(unit.number)) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text("유닛 \(unit.number)").font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Text("·").foregroundStyle(.tertiary)
                Text("\(lesson.id) \(lesson.title)").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                MasteryBadge(level: progress.mastery(lesson: lesson))
                Spacer()
                if let acc = progress.recentAccuracy(lessonID: lesson.id) {
                    Text("최근 정답률 \(Format.percent(acc))").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                if lesson.problems.isEmpty {
                    Text("연습문제 준비 중").font(.system(size: 12)).foregroundStyle(.tertiary)
                } else {
                    Button {
                        appState.startPractice(lesson: lesson)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil.and.list.clipboard").font(.system(size: 11, weight: .semibold))
                            Text("연습문제 \(lesson.problems.count)개")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                }
            }
            HStack(spacing: 4) {
                ForEach(Array(lesson.sections.enumerated()), id: \.offset) { _, section in
                    sectionTab(section.kind)
                }
                Spacer()
                if let next = appState.library.lesson(after: lesson.id) {
                    Button {
                        appState.open(.lesson(next.id))
                    } label: {
                        HStack(spacing: 4) {
                            Text("다음 \(next.id)").font(.system(size: 11.5, weight: .medium))
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func sectionTab(_ kind: LessonSectionKind) -> some View {
        let active = currentAnchor == kind.anchor
        return Button {
            currentAnchor = kind.anchor
            bridge.run("sm.scrollToAnchor(\(WebTemplate.jsString(kind.anchor)));")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: kind.icon).font(.system(size: 10, weight: .semibold))
                Text(kind.title).font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(active ? Theme.accent : Color.secondary)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(active ? Theme.accent.opacity(0.14) : Theme.chipFill(scheme)))
        }
        .buttonStyle(.plain)
    }
}
