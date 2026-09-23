import AppKit
import Combine
import CoreGraphics
import ServiceManagement
import SwiftUI
import WidgetKit

extension Notification.Name {
    static let putWeatherOnDesktop = Notification.Name("putWeatherOnDesktop")
}

@main
enum AppLauncher {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var statusObserver: AnyCancellable?
    private var pinnedToDesktop = true
    private let frameAutosaveName = "WeatherCF.desktopFrame.v3"

    private var desktopWidgetLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.disableRelaunchOnLogin()
        try? SMAppService.mainApp.unregister()
        setupMainMenu()
        setupStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(putOnDesktop), name: .putWeatherOnDesktop, object: nil)
        registerWidgetExtension()
        Task { @MainActor in
            let weather = WeatherController.shared
            weather.start()
            self.statusObserver = weather.objectWillChange.sink { _ in
                Task { @MainActor in
                    self.statusItem?.button?.title = weather.statusTitle
                }
            }
            self.putOnDesktop()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringWeatherForward()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        bringWeatherForward()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard pinnedToDesktop, let window = weatherWindow() else { return }
        sinkToDesktop(window)
    }

    @objc
    func showAsWindow() {
        pinnedToDesktop = false
        guard let window = weatherWindow() as? DesktopWidgetWindow else { return }
        window.pinnedToDesktop = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        bringWeatherForward()
    }

    @objc
    func putOnDesktop() {
        pinnedToDesktop = true
        guard let window = weatherWindow() as? DesktopWidgetWindow else { return }
        window.pinnedToDesktop = true
        window.desktopWidgetLevel = desktopWidgetLevel
        sinkToDesktop(window)
    }

    @objc
    func addDesktopWidget() {
        registerWidgetExtension()
        let alert = NSAlert()
        alert.messageText = "Add Weather C+F as a Widget"
        alert.informativeText = """
        The app window can stay pinned to the desktop.

        To add the system widget:
        1. Right-click an empty area of the desktop.
        2. Choose Edit Widgets.
        3. Search for Weather C+F.
        4. Add Small, Medium, or Large — each shows °F and °C together.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    func quitApp() {
        NSApp.terminate(nil)
    }

    private func registerWidgetExtension() {
        guard let appex = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("WeatherCFWidget.appex") else { return }
        let add = Process()
        add.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        add.arguments = ["-a", appex.path]
        try? add.run()
        add.waitUntilExit()

        let enable = Process()
        enable.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        enable.arguments = ["-e", "use", "-i", "com.weathercf.app.widget"]
        try? enable.run()
        enable.waitUntilExit()

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func bringWeatherForward() {
        guard let window = weatherWindow() as? DesktopWidgetWindow else { return }
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .moveToActiveSpace]
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.orderFrontRegardless()
    }

    private func sinkToDesktop(_ window: NSWindow) {
        window.hidesOnDeactivate = false
        window.level = desktopWidgetLevel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.orderFrontRegardless()
    }

    private func weatherWindow() -> NSWindow? {
        if windowController == nil {
            windowController = makeWindowController()
        }
        return windowController?.window
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Pin to Desktop", action: #selector(putOnDesktop), keyEquivalent: "d")
        appMenu.addItem(withTitle: "Open as Window", action: #selector(showAsWindow), keyEquivalent: "n")
        appMenu.addItem(withTitle: "Add System Widget…", action: #selector(addDesktopWidget), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Weather C+F", action: #selector(quitApp), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "Weather C+F"
            button.font = .systemFont(ofSize: 12, weight: .medium)
            button.toolTip = "Weather C+F"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pin to Desktop", action: #selector(putOnDesktop), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open as Window", action: #selector(showAsWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Add System Widget…", action: #selector(addDesktopWidget), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func makeWindowController() -> NSWindowController {
        let view = ContentView(weather: WeatherController.shared)
        let hosting = NSHostingController(rootView: view)
        let window = DesktopWidgetWindow(contentViewController: hosting)
        window.title = "Weather C+F"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.16, green: 0.18, blue: 0.15, alpha: 1)
        window.contentMinSize = NSSize(width: 380, height: 460)
        window.hasShadow = true
        window.isRestorable = false
        window.hidesOnDeactivate = false
        window.pinnedToDesktop = true
        window.desktopWidgetLevel = desktopWidgetLevel
        window.setFrameAutosaveName(frameAutosaveName)
        if !window.setFrameUsingName(frameAutosaveName) {
            placeDefaultFrame(window)
        }
        ensureComfortableSize(window)
        clampToVisibleScreen(window)
        window.level = desktopWidgetLevel

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [frameAutosaveName] note in
            guard let window = note.object as? NSWindow else { return }
            let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            if let visible, visible.intersects(window.frame) {
                window.saveFrame(usingName: frameAutosaveName)
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: window,
            queue: .main
        ) { [frameAutosaveName] note in
            (note.object as? NSWindow)?.saveFrame(usingName: frameAutosaveName)
        }

        let controller = NSWindowController(window: window)
        window.orderFrontRegardless()
        return controller
    }

    private func placeDefaultFrame(_ window: NSWindow) {
        let size = NSSize(width: 400, height: 480)
        let visible = preferredScreen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - size.width - 28,
            y: max(visible.minY + 24, visible.maxY - size.height - 28)
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private var preferredScreen: NSScreen {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func ensureComfortableSize(_ window: NSWindow) {
        var frame = window.frame
        let minSize = NSSize(width: 400, height: 480)
        if frame.width < minSize.width || frame.height < minSize.height {
            let extraWidth = max(0, minSize.width - frame.width)
            let extraHeight = max(0, minSize.height - frame.height)
            frame.size.width = max(frame.width, minSize.width)
            frame.size.height = max(frame.height, minSize.height)
            frame.origin.x -= extraWidth
            frame.origin.y -= extraHeight
            window.setFrame(frame, display: true)
        }
    }

    private func clampToVisibleScreen(_ window: NSWindow) {
        let frame = window.frame
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        let fullyVisible = visibleFrames.contains { $0.contains(frame) }
        let mostlyVisible = visibleFrames.contains { screen in
            screen.intersection(frame).width >= min(frame.width, 280)
                && screen.intersection(frame).height >= min(frame.height, 360)
        }
        if fullyVisible || mostlyVisible {
            return
        }
        placeDefaultFrame(window)
    }
}

private final class DesktopWidgetWindow: NSWindow {
    var pinnedToDesktop = true
    var desktopWidgetLevel: NSWindow.Level = .normal

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func becomeKey() {
        super.becomeKey()
        isMovable = true
        isMovableByWindowBackground = true
        if pinnedToDesktop {
            level = .normal
        }
    }

    override func resignKey() {
        super.resignKey()
        if pinnedToDesktop {
            hidesOnDeactivate = false
            level = desktopWidgetLevel
        }
    }
}
