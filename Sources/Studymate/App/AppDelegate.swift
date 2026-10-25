import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var library: ContentLibrary!
    private var progress: ProgressStore!
    private var mistakes: MistakeStore!
    private var papers: PastPaperStore!
    private var mocks: MockStore!
    private var scratch: ScratchStore!
    private var appState: AppState!
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenuBuilder.install { NSApp.terminate(nil) }

        let library = ContentLibrary()
        let progress = ProgressStore()
        let mistakes = MistakeStore()
        let papers = PastPaperStore()
        let mocks = MockStore()
        let scratch = ScratchStore()
        if DebugEnv.seedSample, DataDirectory.isDebugOverride {
            SampleData.seed(library: library, progress: progress, mistakes: mistakes, papers: papers, mocks: mocks, scratch: scratch)
        }
        let appState = AppState(library: library, progress: progress, mistakes: mistakes, papers: papers, mocks: mocks, scratchStore: scratch)
        self.library = library
        self.progress = progress
        self.mistakes = mistakes
        self.papers = papers
        self.mocks = mocks
        self.scratch = scratch
        self.appState = appState
        for issue in library.issues { NSLog("Studymate content: %@", issue) }

        let root = RootView(appState: appState)
        let controller = MainWindowController(root: root)
        windowController = controller
        ThemeManager.shared.onChange = { [weak controller] in controller?.applyTheme() }
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let tab = DebugEnv.startTab { appState.open(debugTab: tab) }
        if let spec = DebugEnv.scratch { appState.applyScratchDebug(spec) }
        if let keys = DebugEnv.keys {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                MainActor.assumeIsolated { DebugDriver.run(keys, appState: appState) }
            }
        }
        if let script = DebugEnv.problemScript {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                MainActor.assumeIsolated { appState.runProblemScript(script) }
            }
        }
        if let path = DebugEnv.snapshotPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + DebugEnv.snapshotDelay) {
                MainActor.assumeIsolated {
                    self.windowController?.writeSnapshot(to: path)
                    if DebugEnv.snapshotQuits { NSApp.terminate(nil) }
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        progress?.flush()
        mistakes?.flush()
        papers?.flush()
        mocks?.flush()
        appState?.session?.scratch.flush()
        if let mock = appState?.mockSession { for (_, doc) in mock.scratches { doc.flush() } }
        scratch?.flush()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowController?.showWindow(nil)
        return true
    }
}
