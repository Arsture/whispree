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
    private var settingsWindow: NSWindow?
    private var overlayPanel: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    // Services
    private(set) var audioService: AudioService!
    private(set) var sttService: STTService!
    private(set) var llmService: LLMService!
    private(set) var textInsertionService: TextInsertionService!
    private(set) var modelManager: ModelManager!
    private(set) var hotkeyManager: HotkeyManager!

    // Coordinators
    private(set) var recordingCoordinator: RecordingCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupServices()
        setupStatusItem()
        setupOverlayObserver()
        checkFirstLaunch()

        // Auto-request permissions
        if !TextInsertionService.isAccessibilityEnabled() {
            TextInsertionService.requestAccessibilityPermission()
        }
        Task {
            let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
            if !micGranted {
                print("Microphone permission denied")
            }
        }
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (FreeWhisper)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About FreeWhisper", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide FreeWhisper", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FreeWhisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
        showSettings()
    }

    // MARK: - Services

    private func setupServices() {
        audioService = AudioService()
        sttService = STTService()
        llmService = LLMService()
        textInsertionService = TextInsertionService()
        modelManager = ModelManager(sttService: sttService, llmService: llmService)
        hotkeyManager = HotkeyManager(appState: appState)

        recordingCoordinator = RecordingCoordinator(
            appState: appState,
            audioService: audioService,
            sttService: sttService,
            llmService: llmService,
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
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "FreeWhisper")
            button.title = " FW"
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        showMainWindow()
    }

    // MARK: - Main Window (Dashboard)

    func showMainWindow() {
        if let mainWindow, mainWindow.isVisible {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FreeWhisper"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 380, height: 400)
        window.contentView = NSHostingView(
            rootView: MainDashboardView(
                modelManager: modelManager,
                onOpenSettings: { [weak self] in
                    self?.showSettings()
                }
            )
            .environmentObject(appState)
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to FreeWhisper"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: OnboardingView(modelManager: modelManager) { [weak self] in
                guard let self else { return }
                self.appState.settings.hasCompletedOnboarding = true
                self.appState.settings.save()
                DispatchQueue.main.async {
                    self.onboardingWindow?.orderOut(nil)
                    self.onboardingWindow = nil
                    self.showMainWindow()
                }
            }
            .environmentObject(self.appState)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
    }

    // MARK: - Settings

    func showSettings() {
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FreeWhisper Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView()
                .environmentObject(appState)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
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
