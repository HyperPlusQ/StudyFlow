# StudyFlow — iOS 原生学习与作业管理应用

StudyFlow 是一款面向 iPhone 与 iPad 的原生生产力应用，使用 **SwiftUI + SwiftData** 构建。应用以底部原生标签栏组织概览、作业、日程、科目和设置页面，并针对不同屏幕比例使用弹性布局与 Liquid Glass 视觉规范。

当前分支仅包含 iOS、WidgetKit 扩展与共享 Swift Package 代码，不再包含桌面端入口、桌面端图标资源或应用打包脚本。

---

## 环境要求

- Xcode 16 或更高版本
- iOS 17.0+
- Swift 6 / Swift Package Manager
- 真机安装需要有效的 Apple Development 签名证书
- 小组件需要主应用与扩展使用相同 App Group：`group.com.openai.studyflow`

## 快速开始

1. 使用 Xcode 打开 `StudyFlow.xcodeproj`；
2. 选择 `StudyFlow` scheme 与目标 iPhone/iPad 模拟器；
3. 按 `⌘R` 构建并运行；
4. 小组件调试时选择 `StudyFlowWidgets` scheme 安装扩展，然后长按主屏幕添加 StudyFlow 小组件。

命令行构建：

```bash
xcodebuild -project StudyFlow.xcodeproj \
  -scheme StudyFlow \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

运行共享代码测试：

```bash
swift test --package-path .
```

## 功能总览

### 科目与作业

- 新建、编辑、删除多层级科目；
- 完整管理作业标题、详细说明、截止日期、提交方式、优先级、权重和提醒；
- 将大作业拆分为可勾选的子任务并显示完成进度；
- 完成的作业自动进入“完成”列表，可随时恢复；
- 按科目记录曾经输入的提交方式，可从建议菜单复用，也可逐条删除；
- 网址提交方式使用系统浏览器打开，邮箱提交方式使用系统邮件应用起草邮件。

### 搜索、筛选与智能排序

- 全局搜索标题、说明、提交方式、科目与子任务；
- 按科目、优先级、截止窗口和子任务状态组合筛选；
- 依据截止紧迫度、优先级、自定义权重与子任务进度计算关注分数；
- “今天、一周、全部、完成”使用原生分段控件切换。

### 时间管理

- 通过 Time Blocking 将待办作业转换为日程时间块；
- 查看今天、明天及后续日期的安排；
- 概览页展示进行中、今日截止、逾期与完成率等信息。

### 系统集成

- 使用 `UNUserNotificationCenter` 提供截止前提醒；
- 使用 `EventKit` 同步系统日历；
- 开启“总是同步到系统日历”后，新建、编辑、完成或删除作业都会同步对应事件；
- 设置中可从 GitHub Release/Tag 检查新版本。

### iCloud 与数据交换

- 支持选择 iCloud 云盘文件夹并自动同步 `StudyFlow-Sync.json`；
- 可设置启动同步与每日同步时间，按本地/云端修改时间用较新文件覆盖较旧文件；
- 支持导出 JSON、导出到 iCloud 云盘和导入 JSON；
- 导入前会校验文件，并要求用户确认覆盖当前数据。

### 小组件

WidgetKit 扩展提供三种规格：

- 小号：聚焦最紧急作业；
- 中号：展示更多截止信息与进度；
- 大号：同时显示作业摘要和统计信息。

主应用每次保存数据后会更新共享 JSON 快照，小组件每 15 分钟读取一次。

## 目录结构

```text
StudyFlow-iOS/
├── Configuration/                 # iOS Info.plist 与 App Group entitlements
├── Package.swift                  # StudyFlowKit 与小组件共享包
├── Sources/
│   ├── StudyFlowiOS/              # 应用入口
│   ├── StudyFlowKit/              # SwiftUI 页面、SwiftData 与系统服务
│   ├── StudyFlowWidgets/          # WidgetKit 扩展
│   └── StudyFlowWidgetShared/     # 小组件共享快照模型与存储
├── Tests/
│   └── StudyFlowKitTests/         # 共享逻辑单元测试
├── StudyFlow.xcodeproj/           # 主应用与小组件 target
├── README.md
└── 使用指南.md
```

## 权限说明

- **通知**：用于截止日期提醒；
- **日历**：用于创建、更新与删除作业事件；
- **文件访问**：通过系统 `fileImporter` / `fileExporter` 导入导出 JSON；
- **iCloud 云盘**：通过安全作用域书签访问用户选择的同步文件夹。

所有权限均按需请求。日历和 iCloud 同步失败时不会阻止应用的其他功能。

## 数据说明

业务数据默认保存在应用沙盒内的 SwiftData/SQLite 数据库。设置中的自动同步使用普通 JSON 文件与修改时间比较，不依赖 CloudKit。导入操作会替换当前科目、作业、子任务、时间块和提交方式历史，请先导出备份。

## 版本

当前工程版本：**1.6.0**
