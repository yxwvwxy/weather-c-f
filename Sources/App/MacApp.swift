import AppKit
import Combine
import CoreGraphics
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

    private var desktopWidgetLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        putOnDesktop()
        return true
    }

    @objc
    func showAsWindow() {
        guard let window = weatherWindow() else { return }
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func putOnDesktop() {
        guard let window = weatherWindow() else { return }
        window.level = desktopWidgetLevel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.orderFrontRegardless()
    }

    @objc
    func quitApp() {
        NSApp.terminate(nil)
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
        let window = NSWindow(contentViewController: hosting)
        window.title = "天气 C+F"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.18, green: 0.38, blue: 0.78, alpha: 1)
        window.setContentSize(NSSize(width: 340, height: 620))
        window.minSize = NSSize(width: 300, height: 420)
        window.center()
        window.level = desktopWidgetLevel

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        return controller
    }
}
