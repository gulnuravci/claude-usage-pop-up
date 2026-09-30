import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store: UsageStore
    private var statusItem: NSStatusItem!
    private var panel: WidgetPanel!
    private let dragger = WindowDragger()
    private var cancellables = Set<AnyCancellable>()
    private var titleTimer: Timer?

    private let defaults = UserDefaults.standard
    private var widgetVisible: Bool {
        get { defaults.object(forKey: "widgetVisible") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "widgetVisible") }
    }
    private var notificationsOn: Bool {
        get { defaults.object(forKey: "notificationsOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "notificationsOn") }
    }

    init(demo: Bool) {
        store = UsageStore(demo: demo)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPanel()

        store.notify = { [weak self] title, body in
            guard self?.notificationsOn == true else { return }
            Notifier.post(title: title, body: body)
        }
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        titleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatusItem() }
        }

        Notifier.requestPermission()
        LoginItem.enableOnFirstLaunch()
        store.start()
    }

    // MARK: Floating widget

    private func setUpPanel() {
        let root = WidgetView(store: store, dragger: dragger) { [weak self] in self?.setWidget(visible: false) }
        panel = WidgetPanel(content: root)
        dragger.window = panel
        dragger.onMoved = { [weak self] frame in
            self?.defaults.set(NSStringFromPoint(NSPoint(x: frame.minX, y: frame.maxY)), forKey: "widgetTopLeft")
        }

        if let saved = defaults.string(forKey: "widgetTopLeft") {
            panel.setFrameTopLeftPoint(NSPointFromString(saved))
        }
        if defaults.string(forKey: "widgetTopLeft") == nil || !isOnScreen(panel.frame) {
            moveToDefaultPosition()
        }
        if widgetVisible { panel.orderFrontRegardless() }
    }

    private func moveToDefaultPosition() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        panel.setFrameTopLeftPoint(NSPoint(x: screen.maxX - panel.frame.width - 12, y: screen.maxY - 8))
    }

    private func isOnScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame.insetBy(dx: 40, dy: 40)) }
    }

    private func setWidget(visible: Bool) {
        widgetVisible = visible
        if visible {
            if !isOnScreen(panel.frame) { moveToDefaultPosition() }
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let session = store.snapshot?.session
        let percent = session?.percent ?? 0
        let color: NSColor = store.mood == .party ? NSColor(Palette.sage) : NSColor(Palette.color(for: percent))
        button.image = Self.ringImage(percent: store.snapshot == nil ? 0 : percent, color: color)

        var title = store.snapshot == nil ? " –" : " \(Format.percent(percent))"
        if let session, percent >= 100, let resetsAt = session.resetsAt {
            title = " 💤 \(Format.countdown(to: resetsAt))"
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .medium)
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if percent >= Config.panicAt { attributes[.foregroundColor] = NSColor(Palette.cherry) }
        button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let snapshot = store.snapshot {
            for meter in [snapshot.session, snapshot.weekly].compactMap({ $0 }) + snapshot.extras {
                var line = "\(meter.label): \(Format.percent(meter.percent))"
                if let resetsAt = meter.resetsAt {
                    line += "  ·  resets in \(Format.countdown(to: resetsAt)) (\(Format.clock(resetsAt)))"
                }
                menu.addItem(withTitle: line, action: nil, keyEquivalent: "")
            }
        }
        if let error = store.error {
            let item = NSMenuItem(title: "⚠︎ " + (error.errorDescription ?? "Something went wrong"), action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        if let updated = store.lastUpdated {
            let f = RelativeDateTimeFormatter()
            menu.addItem(withTitle: "Updated \(f.localizedString(for: updated, relativeTo: Date()))", action: nil, keyEquivalent: "")
        }

        menu.addItem(.separator())
        add(to: menu, widgetVisible ? "Hide Widget" : "Show Widget", #selector(toggleWidget))
        if widgetVisible {
            let minimized = defaults.bool(forKey: "widgetMinimized")
            add(to: menu, minimized ? "Expand Widget" : "Minimize Widget", #selector(toggleMinimized))
        }
        add(to: menu, "Refresh Now", #selector(refresh), key: "r")
        add(to: menu, "Open Usage Page…", #selector(openUsagePage))

        menu.addItem(.separator())
        add(to: menu, "Notifications", #selector(toggleNotifications)).state = notificationsOn ? .on : .off
        if LoginItem.isSupported {
            add(to: menu, "Launch at Login", #selector(toggleLoginItem)).state = LoginItem.isEnabled ? .on : .off
        }

        menu.addItem(.separator())
        add(to: menu, "Quit", #selector(quit), key: "q")
    }

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleWidget() { setWidget(visible: !widgetVisible) }
    @objc private func toggleMinimized() { defaults.set(!defaults.bool(forKey: "widgetMinimized"), forKey: "widgetMinimized") }
    @objc private func refresh() { store.refreshNow() }
    @objc private func openUsagePage() { NSWorkspace.shared.open(Config.usagePageURL) }
    @objc private func toggleNotifications() { notificationsOn.toggle() }
    @objc private func toggleLoginItem() { LoginItem.set(enabled: !LoginItem.isEnabled) }
    @objc private func quit() { NSApp.terminate(nil) }

    /// A tiny progress ring for the menu bar.
    private static func ringImage(percent: Double, color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let ring = rect.insetBy(dx: 2, dy: 2)
            let track = NSBezierPath(ovalIn: ring)
            track.lineWidth = 2.4
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            track.stroke()

            guard percent > 0 else { return true }
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY), radius: ring.width / 2,
                          startAngle: 90, endAngle: 90 - 360 * min(percent, 100) / 100, clockwise: true)
            arc.lineWidth = 2.4
            arc.lineCapStyle = .round
            color.setStroke()
            arc.stroke()
            return true
        }
    }
}

// MARK: - Window

/// Borderless, always-on-top, visible on every Space, and never steals focus.
final class WidgetPanel: NSPanel {
    init<Content: View>(content: Content) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSHostingView(rootView: content)
        contentView = host
        setContentSize(host.fittingSize)

        // SwiftUI resizes the window as rows come and go (or when you minimize). Keep the top edge
        // put, and hug whichever side of the screen the widget lives on.
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            guard let self, let pinned = self.pinnedFrame, self.frame.size != pinned.size else { return }
            let screen = (self.screen ?? NSScreen.main)?.visibleFrame ?? pinned
            let hugRight = pinned.midX > screen.midX
            self.setFrameOrigin(NSPoint(x: hugRight ? pinned.maxX - self.frame.width : pinned.minX,
                                        y: pinned.maxY - self.frame.height))
        }
    }

    private var pinnedFrame: NSRect?

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        pinnedFrame = frame
    }

    override func setFrameTopLeftPoint(_ point: NSPoint) {
        super.setFrameTopLeftPoint(point)
        pinnedFrame = frame
    }

    override var canBecomeKey: Bool { true }
}

/// Moves the panel while you drag the card around.
@MainActor
final class WindowDragger {
    weak var window: NSWindow?
    var onMoved: (NSRect) -> Void = { _ in }
    private var start: (mouse: NSPoint, origin: NSPoint)?

    func dragChanged() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if start == nil { start = (mouse, window.frame.origin) }
        guard let start else { return }
        window.setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x,
                                      y: start.origin.y + mouse.y - start.mouse.y))
    }

    func dragEnded() {
        start = nil
        if let window { onMoved(window.frame) }
    }
}

// MARK: - System integrations (only available when running as an installed .app)

private var isRunningAsApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

enum LoginItem {
    static var isSupported: Bool { isRunningAsApp }
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Launch at login change failed: \(error)")
        }
    }

    /// Turn on launch-at-login the first time the installed app runs; afterwards it's your call.
    static func enableOnFirstLaunch() {
        let key = "didSetUpLoginItem"
        guard isSupported, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(enabled: true)
    }
}

enum Notifier {
    static func requestPermission() {
        guard isRunningAsApp else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(title: String, body: String) {
        guard isRunningAsApp else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
