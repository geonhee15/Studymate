import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var scheme
    private var theme: ThemeManager { ThemeManager.shared }
    @State private var confirmReset = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "설정")
                VStack(spacing: 0) {
                    SettingsRow(title: "외관", subtitle: "이 앱 창만 라이트/다크로. 시스템 설정은 그대로") {
                        Picker("", selection: Binding(get: { theme.appearance }, set: { theme.setAppearance($0) })) {
                            ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 200)
                    }
                    Divider().padding(.horizontal, 12)
                    SettingsRow(title: "테마", subtitle: theme.current.subtitle) {
                        Picker("", selection: Binding(get: { theme.current }, set: { theme.set($0) })) {
                            ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden().controlSize(.small).frame(width: 130)
                    }
                }
                .card()
                VStack(spacing: 0) {
                    SettingsRow(title: "집중 모드", subtitle: "문제 풀 때 과목 탭과 사이드바를 숨겨요") {
                        Toggle("", isOn: $appState.focusMode).toggleStyle(.switch).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    SettingsRow(title: "문제를 한국어로 먼저", subtitle: "기본은 영어 원문 (실제 시험 기준). T 키로 언제든 전환") {
                        Toggle("", isOn: $appState.koreanFirst).toggleStyle(.switch).labelsHidden()
                    }
                }
                .card()
                VStack(spacing: 0) {
                    SettingsRow(title: "데이터 폴더", subtitle: DataDirectory.url.path) {
                        Button("Finder에서 보기") { NSWorkspace.shared.activateFileViewerSelecting([DataDirectory.url]) }
                            .controlSize(.small)
                    }
                    Divider().padding(.horizontal, 12)
                    SettingsRow(title: "학습 기록 초기화", subtitle: "시도 기록과 숙련도를 지워요. 오답노트와 기출 기록은 남아요", subtitleIsError: false) {
                        Button("초기화…") { confirmReset = true }.controlSize(.small)
                    }
                }
                .card()
                infoCard
            }
            .padding(24)
        }
        .confirmationDialog("학습 기록을 초기화할까요?", isPresented: $confirmReset) {
            Button("초기화", role: .destructive) { appState.progress.reset() }
            Button("취소", role: .cancel) {}
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.accent.opacity(0.14)))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studymate").font(.system(size: 13, weight: .semibold))
                    Text("v\(appVersion) · Swift · AppKit + SwiftUI · KaTeX 오프라인 · macOS 14+")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Text("AMC 8을 준비하면서 매일 쓰는 학습 앱. 레슨은 docs/AMC8_concepts.md, 문제는 Resources/Content/amc8/unitN/*.json 에서 읽어요.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("GitHub") { NSWorkspace.shared.open(URL(string: "https://github.com/geonhee15/Studymate")!) }.controlSize(.small)
                Button("ATFM") { NSWorkspace.shared.open(URL(string: "https://github.com/geonhee15/ATFM")!) }.controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    var subtitleIsError = false
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(subtitleIsError ? Color.red : Color.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
