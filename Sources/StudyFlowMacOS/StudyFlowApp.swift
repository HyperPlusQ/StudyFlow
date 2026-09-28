import AppKit
import StudyFlowKit
import SwiftData
import SwiftUI

/// Keeps the single-window app recoverable after its last window closes.
///
/// SwiftUI leaves a closed `WindowGroup` scene without a visible window, so
/// clicking the Dock icon can otherwise activate an app that has nowhere to
/// present its content. Quitting after the final window closes gives the next
/// launch a clean SwiftUI scene while preserving all SwiftData state.
final class StudyFlowAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct StudyFlowApp: App {
    @NSApplicationDelegateAdaptor(StudyFlowAppDelegate.self) private var appDelegate

    let container: ModelContainer
    let exporter = MacDataExporter()
    let cloudFolderProvider = MacCloudFolderProvider()

    init() {
        do {
            container = try StudyFlowStorage.makeContainer()
        } catch {
            fatalError("无法初始化 StudyFlow 数据库：\(error.localizedDescription)")
        }
    }

    private static var didApplyPackagedIcon = false

    static func applyPackagedIconIfNeeded() {
        guard !didApplyPackagedIcon else { return }
        didApplyPackagedIcon = true

        // Prefer the packaged application bundle so release builds never force
        // the SwiftPM resource accessor before the app icon has been found.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
            return
        }

        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = image
    }

    var body: some Scene {
        WindowGroup("StudyFlow") {
            StudyFlowRootView(
                exporter: exporter,
                cloudFolderProvider: cloudFolderProvider
            )
            .modelContainer(container)
            .frame(minWidth: 1_000, minHeight: 680)
            .onAppear {
                StudyFlowApp.applyPackagedIconIfNeeded()
                NSApplication.shared.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .defaultSize(width: 1_280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建作业") {
                    StudyFlowCommands.postNewAssignment()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("新建科目") {
                    StudyFlowCommands.postNewSubject()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("新建时间块") {
                    StudyFlowCommands.postNewTimeBlock()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        Settings {
            StudyFlowSettingsView(
                exporter: exporter,
                cloudFolderProvider: cloudFolderProvider
            )
            .modelContainer(container)
        }
    }
}
