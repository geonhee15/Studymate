import SwiftUI

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

struct ProgressBar: View {
    var fraction: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: fraction)
    }
}

/// Khan-style four-segment mastery indicator for a lesson.
struct MasteryPips: View {
    var level: MasteryLevel
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i <= level.rawValue ? Theme.mastery(level) : Color.primary.opacity(0.1))
                    .frame(width: 10, height: 6)
            }
        }
    }
}

struct MasteryBadge: View {
    var level: MasteryLevel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon).font(.system(size: 10, weight: .semibold))
            Text(level.title).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(level == .none ? Color.secondary : Theme.mastery(level))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill((level == .none ? Color.secondary : Theme.mastery(level)).opacity(0.14)))
    }
}

struct Chip: View {
    var text: String
    var icon: String? = nil
    var color: Color = .secondary
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color == .secondary ? Theme.chipFill(scheme) : color.opacity(0.14)))
    }
}

struct Keycap: View {
    var text: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.chipFill(scheme)))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.cardStroke(scheme)))
    }
}

/// Button with a rounded, hover-highlighted card look.
struct CardButton<Label: View>: View {
    var prominent = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(prominent ? Theme.accent.opacity(hovering ? 0.24 : 0.16) : (hovering ? Theme.hoverFill(scheme) : Color.clear))
        )
        .onHover { hovering = $0 }
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false
    var destructive = false
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? Color.white : (destructive ? Theme.wrong : Color.primary))
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(prominent ? Theme.accent : Theme.chipFill(scheme))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Page header used by every detail screen.
struct PageTitle: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 24, weight: .bold))
            if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary) }
        }
    }
}

/// The five "stuck" questions (docs section 0-1) as a card.
struct StuckQuestionsCard: View {
    var compact = false
    static let questions: [(String, String)] = [
        ("반대로 세면 쉬워지나?", "\"적어도 하나\", \"~가 아닌\"이 보이면 거의 확정. (유닛 1-2)"),
        ("숫자를 작게 바꿔서 해보면?", "2026개, 100번째 같은 큰 수는 규칙이나 주기가 있다는 신호. (유닛 1-5, 4-2)"),
        ("그림 그렸어?", "기하는 물론, 문장제도 표나 수직선 하나로 풀리는 게 많다."),
        ("경우를 나눌 수 있나?", "나눌 땐 겹치지 않게, 빠짐없이."),
        ("선택지로 거를 수 있나?", "홀짝, 일의 자리, 대충 크기만 봐도 2~3개는 지워진다. (유닛 9-6)"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle").foregroundStyle(Theme.accent)
                Text("막혔을 때 5가지 질문").font(.system(size: 14, weight: .semibold))
            }
            Text("문제 읽고 바로 손이 안 가면 이 순서로 묻는다. 11~25번은 대부분 이 중 하나로 뚫린다.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach(Array(Self.questions.enumerated()), id: \.offset) { i, q in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.accent.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(q.0).font(.system(size: 13, weight: .semibold))
                        Text(q.1).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
