import AppKit

@main
struct StudymateMain {
    @MainActor
    static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--probe") {
            let what = CommandLine.arguments.count > i + 1 ? CommandLine.arguments[i + 1] : "content"
            exit(Probe.run(what))
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
