import AppKit
import StudyFlowKit
import SwiftData
import SwiftUI

@main
struct StudyFlowApp: App {
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

    var body: some Scene {
        WindowGroup("StudyFlow") {
            StudyFlowRootView(
                exporter: exporter,
                cloudFolderProvider: cloudFolderProvider
            )
            .modelContainer(container)
            .frame(minWidth: 1_000, minHeight: 680)
            .onAppear {
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
