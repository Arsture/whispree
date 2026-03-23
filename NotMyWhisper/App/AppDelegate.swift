import AppKit
import AVFoundation
import SwiftUI
import KeyboardShortcuts
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var overlayPanel: NSPanel?
    private var quickFixPanel: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    // Services
    private(set) var audioService: AudioService!
    private(set) var sttService: STTService!
    private(set) var llmService: LLMService!
    private(set) var textInsertionService: TextInsertionService!
    private(set) var modelManager: ModelManager!
    private(set) var hotkeyManager: HotkeyManager!
    private(set) var quickFixService: QuickFixService!

    // Coordinators
    private(set) var recordingCoordinator: RecordingCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupEditKeyboardShortcuts()
        setupServices()
        setupStatusItem()
        setupOverlayObserver()
        checkFirstLaunch()
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (NotMyWhisper)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About NotMyWhisper", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide NotMyWhisper", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit NotMyWhisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (for text fields to work with Cmd+C/V/X)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsFromMenu() {
        showMainWindow()
    }

    // MARK: - Edit Keyboard Shortcuts (Copy/Paste Fix)

    /// SwiftUI의 NSHostingView에서 Edit 메뉴 키보드 단축키가 동작하지 않는 문제를 해결.
    /// NSEvent 로컬 모니터로 Cmd+C/V/X/A/Z를 가로채서 직접 first responder에 dispatch.
    private func setupEditKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }

            let action: Selector?
            let isShift = event.modifierFlags.contains(.shift)

            switch event.charactersIgnoringModifiers {
            case "v": action = #selector(NSText.paste(_:))
            case "c": action = #selector(NSText.copy(_:))
            case "x": action = #selector(NSText.cut(_:))
            case "a": action = #selector(NSText.selectAll(_:))
            case "z": action = isShift ? NSSelectorFromString("redo:") : NSSelectorFromString("undo:")
            default: action = nil
            }

            if let action, NSApp.sendAction(action, to: nil, from: nil) {
                return nil // 이벤트 소비됨
            }
            return event
        }
    }

    // MARK: - Services

    private func setupServices() {
        audioService = AudioService()
        sttService = STTService()
        llmService = LLMService()
        textInsertionService = TextInsertionService()
        modelManager = ModelManager(appState: appState, sttService: sttService, llmService: llmService)
        hotkeyManager = HotkeyManager(appState: appState)
        quickFixService = QuickFixService()

        recordingCoordinator = RecordingCoordinator(
            appState: appState,
            audioService: audioService,
            textInsertionService: textInsertionService
        )

        hotkeyManager.onRecordingToggle = { [weak self] shouldRecord in
            guard let self else { return }
            if shouldRecord {
                self.recordingCoordinator.startRecording()
            } else {
                self.recordingCoordinator.stopRecording()
            }
        }

        hotkeyManager.onCancel = { [weak self] in
            self?.recordingCoordinator.cancel()
        }

        hotkeyManager.onQuickFix = { [weak self] in
            self?.handleQuickFix()
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "NotMyWhisper")
            button.title = " FW"
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        showMainWindow()
    }

    // MARK: - Main Window (Unified)

    func showMainWindow() {
        if let mainWindow, mainWindow.isVisible {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotMyWhisper"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 600, height: 450)
        window.contentView = NSHostingView(
            rootView: UnifiedView()
                .environmentObject(appState)
                .environmentObject(hotkeyManager)
                .environmentObject(modelManager)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.mainWindow = window
    }

    // MARK: - Onboarding

    private func checkFirstLaunch() {
        if !appState.settings.hasCompletedOnboarding {
            showOnboarding()
        } else {
            showMainWindow()
            Task {
                await modelManager.loadModelsIfAvailable()
            }
        }
    }

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 680),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to NotMyWhisper"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: OnboardingView() { [weak self] in
                guard let self else { return }
                self.appState.settings.hasCompletedOnboarding = true
                self.appState.settings.save()
                DispatchQueue.main.async {
                    self.onboardingWindow?.orderOut(nil)
                    self.onboardingWindow = nil
                    self.showMainWindow()
                    Task {
                        await self.appState.switchSTTProvider(to: self.appState.settings.sttProviderType)
                        await self.appState.switchLLMProvider(to: self.appState.settings.llmProviderType)
                    }
                }
            }
            .environmentObject(self.appState)
            .environmentObject(self.hotkeyManager)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
    }

    // MARK: - Quick Fix

    private func handleQuickFix() {
        // Capture the frontmost app (where the user selected text)
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let targetApp = frontmost else { return }

        // Allow self-targeting during onboarding for Quick Fix demo
        if targetApp.bundleIdentifier == Bundle.main.bundleIdentifier
            && appState.settings.hasCompletedOnboarding {
            return
        }

        Task {
            // Simulate Cmd+C to capture selected text
            guard let selectedText = await quickFixService.captureSelectedText() else { return }

            showQuickFixPanel(originalText: selectedText, targetApp: targetApp)
        }
    }

    private func showQuickFixPanel(originalText: String, targetApp: NSRunningApplication) {
        quickFixPanel?.orderOut(nil)
        quickFixPanel = nil

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.title = "Quick Fix"
        panel.center()
        panel.isReleasedWhenClosed = false

        panel.contentView = NSHostingView(
            rootView: QuickFixPanelView(
                originalText: originalText,
                onConfirmWord: { [weak self] correctedText in
                    guard let self else { return }
                    self.quickFixPanel?.orderOut(nil)
                    self.quickFixPanel = nil

                    Task {
                        _ = await self.quickFixService.replaceText(with: correctedText, in: targetApp)
                        self.quickFixService.addWordToDictionary(correctedText, appState: self.appState)
                    }
                },
                onConfirmMapping: { [weak self] fromText, toText in
                    guard let self else { return }
                    self.quickFixPanel?.orderOut(nil)
                    self.quickFixPanel = nil

                    Task {
                        _ = await self.quickFixService.replaceText(with: toText, in: targetApp)
                        self.quickFixService.addCorrectionToDictionary(from: fromText, to: toText, appState: self.appState)
                    }
                },
                onCancel: { [weak self] in
                    self?.quickFixPanel?.orderOut(nil)
                    self?.quickFixPanel = nil
                }
            )
        )

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.quickFixPanel = panel
    }

    // MARK: - Recording Overlay

    private func setupOverlayObserver() {
        appState.$transcriptionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .recording, .transcribing, .correcting:
                    self.showOverlay()
                case .idle, .inserting:
                    // Brief delay before hiding after inserting
                    if state == .idle {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if self.appState.transcriptionState == .idle {
                                self.hideOverlay()
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func showOverlay() {
        guard appState.settings.showOverlay else { return }

        if overlayPanel != nil {
            overlayPanel?.orderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        // Position at top center of screen
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 320) / 2
            let y = screen.visibleFrame.maxY - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.contentView = NSHostingView(
            rootView: TranscriptionOverlayView()
                .environmentObject(appState)
        )
        panel.orderFront(nil)
        self.overlayPanel = panel
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }
}
