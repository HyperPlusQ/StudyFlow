import SwiftData
import SwiftUI

@main
struct StudyFlowApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Subject.self,
            Assignment.self,
            Subtask.self,
            TimeBlock.self
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

    var body: some Scene {
        WindowGroup("StudyFlow") {
            ContentView()
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
        }
    }
}
