import AppKit
import Combine
import CoreGraphics
import ServiceManagement
import SwiftUI

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
    private let frameAutosaveName = "WeatherCF.desktopFrame"

    private var desktopWidgetLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.disableRelaunchOnLogin()
        try? SMAppService.mainApp.unregister()
        setupMainMenu()
        setupStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(putOnDesktop), name: .putWeatherOnDesktop, object: nil)
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
    func quitApp() {
        NSApp.terminate(nil)
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
        appMenu.addItem(withTitle: "放到桌面", action: #selector(putOnDesktop), keyEquivalent: "d")
        appMenu.addItem(withTitle: "作为窗口打开", action: #selector(showAsWindow), keyEquivalent: "n")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出天气 C+F", action: #selector(quitApp), keyEquivalent: "q")
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
            button.title = "天气 C+F"
            button.font = .systemFont(ofSize: 12, weight: .medium)
            button.toolTip = "天气 C+F"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "放到桌面", action: #selector(putOnDesktop), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "作为窗口打开", action: #selector(showAsWindow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func makeWindowController() -> NSWindowController {
        let view = ContentView(weather: WeatherController.shared)
        let hosting = NSHostingController(rootView: view)
        let window = DesktopWidgetWindow(contentViewController: hosting)
        window.title = "天气 C+F"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.18, green: 0.38, blue: 0.78, alpha: 1)
        window.contentMinSize = NSSize(width: 300, height: 420)
        window.isRestorable = false
        window.hidesOnDeactivate = false
        window.pinnedToDesktop = true
        window.desktopWidgetLevel = desktopWidgetLevel
        window.setFrameAutosaveName(frameAutosaveName)
        if !window.setFrameUsingName(frameAutosaveName) {
            placeDefaultFrame(window)
        }
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
        let size = NSSize(width: 340, height: 620)
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visible.maxX - size.width - 28,
            y: visible.maxY - size.height - 28
        )
        window.setContentSize(size)
        window.setFrameOrigin(origin)
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
