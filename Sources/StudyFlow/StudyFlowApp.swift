import AppKit
import SwiftData
import SwiftUI

/// 关闭最后一个窗口后自动退出，避免应用保留在后台却没有可显示的窗口，
/// 导致下一次点击 Dock 图标时表现为“启动失败”。
final class StudyFlowAppDelegate: NSObject, NSApplicationDelegate {
    /// 关闭最后窗口后退出进程，避免应用残留。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct StudyFlowApp: App {
    @NSApplicationDelegateAdaptor(StudyFlowAppDelegate.self) private var appDelegate

    let container: ModelContainer

    init() {
        let schema = Schema([
            Subject.self,
            Assignment.self,
            Subtask.self,
            TimeBlock.self,
            SubmissionHistoryEntry.self
        ])

        do {
            // 可通过 STUDYFLOW_STORE_PATH 指定测试/便携式数据库位置；
            // 未设置时使用 macOS 沙盒容器内的默认 SwiftData 数据库。
            if let path = ProcessInfo.processInfo.environment["STUDYFLOW_STORE_PATH"],
               !path.isEmpty {
                let url = URL(fileURLWithPath: path).standardizedFileURL
                let configuration = ModelConfiguration(
                    schema: schema,
                    url: url,
                    allowsSave: true
                )
                container = try ModelContainer(for: schema, configurations: [configuration])
            } else {
                container = try ModelContainer(for: schema)
            }
        } catch {
            fatalError("无法初始化 StudyFlow 数据库：\(error.localizedDescription)")
        }
    }

    private static var didApplyPackagedIcon = false

    /// 启动时应用应用包内图标。
    static func applyPackagedIconIfNeeded() {
        guard !didApplyPackagedIcon else { return }
        didApplyPackagedIcon = true

        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url)
        else { return }
        NSApplication.shared.applicationIconImage = image
    }

    /// 创建主窗口、快捷键命令和设置窗口。
    var body: some Scene {
        WindowGroup("StudyFlow") {
            ContentView()
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
                    NotificationCenter.default.post(name: .studyFlowNewAssignment, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("新建科目") {
                    NotificationCenter.default.post(name: .studyFlowNewSubject, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("新建时间块") {
                    NotificationCenter.default.post(name: .studyFlowNewTimeBlock, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .modelContainer(container)
        }
    }
}
