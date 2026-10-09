# StudyFlow — macOS / Android 学习与作业管理应用

StudyFlow 是一款面向学生与需要管理课程、作业、截止日期和学习时段用户的跨平台生产力应用。两个平台按独立分支开发：

- **macOS** 使用 SwiftUI + SwiftData，采用侧边栏、列表与 Inspector 详情布局，并遵循 Apple Human Interface Guidelines；
- **Android** 使用 Jetpack Compose + Room/SQLite，遵循 Material 3 Expressive，并针对手机、折叠屏和平板提供响应式布局。

当前版本：**1.6.2**。macOS 与 Android 功能设计保持一致，但平台实现、界面组件和发布流程分别维护。

---

## 下载最新版本

当前版本：**1.6.2**

- [macOS 1.6.2](https://github.com/HyperPlusQ/StudyFlow/releases/tag/v1.6.2) — Apple Silicon（arm64），macOS 14+
- [Android 1.6.2](https://github.com/HyperPlusQ/StudyFlow/releases/tag/v1.6.2) — APK，Android 8.0+
- 仓库内镜像：[StudyFlow-macOS.zip](Releases/StudyFlow-macOS.zip)

macOS 包解压后直接运行 `StudyFlow.app`；Android 包可下载 APK 后安装。

---

## 平台分支

- `macos`（默认分支）：macOS SwiftUI 原生实现；
- `android`：独立的 orphan 分支，Android Jetpack Compose 实现；
- 两套工程分别维护，不共享平台 UI，但共享 StudyFlow 的产品功能设计；
- Android 版本仅提供 JSON 导出，不包含 iCloud 相关功能。

---

## macOS 快速开始

### 1. 构建并打开应用

在项目根目录执行：

```bash
./Scripts/build-app.sh
open dist/StudyFlow.app
```

构建脚本会：

1. 使用当前 Mac 架构编译 Swift 源码；
2. 创建标准 `.app` 应用包；
3. 写入 `Info.plist` 与应用图标；
4. 使用 App Sandbox 与日历权限描述进行 ad hoc 签名；
5. 执行签名与属性列表校验。

如需指定架构或签名身份：

```bash
ARCH=arm64 ./Scripts/build-app.sh
CODE_SIGN_IDENTITY="-" ./Scripts/build-app.sh
```

> 推荐使用 macOS 14 或更高版本。附带的预构建应用面向 Apple Silicon（arm64）。

### 2. 使用 Xcode / Swift Package 开发

1. 在 Xcode 16 或更高版本中选择 **File → Open…**；
2. 打开本目录中的 `Package.swift`；
3. 选择 `StudyFlow` scheme；
4. 按 `⌘R` 运行，或按 `⌘B` 编译。

日常交付构建建议优先使用 `Scripts/build-app.sh`，因为它会生成带 `Info.plist`、应用图标、Sandbox、网络与文件访问 entitlements 的完整应用包。

---

## macOS 功能总览

### 科目管理

- 在侧边栏中新建、编辑与删除科目；
- 通过 `parentId` 支持任意层级的科目树；
- 每个科目拥有独立名称、颜色与 SF Symbol 图标；
- 删除父科目时，子科目自动升级，不会误删作业或时间块；
- 可按科目组合筛选，也可让作业继承所在科目的视觉标识。

### 作业与子任务

- 完整创建、查看、更新、删除作业；
- 必填/核心元数据包括：
  - 作业标题与详细说明；
  - 截止日期；
  - 提交渠道或提交方式；
  - 所属科目；
  - 优先级与自定义权重；
  - 提前提醒时长。
- 支持将大型作业拆分为可勾选的 Checklist 子任务；
- 自动计算子任务完成进度；
- 完成作业后自动移入“已完成”，再次勾选可恢复为进行中；
- 完成作业时自动收起其全部子任务并取消本地提醒；
- 网址提交方式可在列表与详情中点击，并交给系统默认浏览器打开；
- 邮箱提交方式可直接点击，交给系统默认邮件应用起草新邮件；
- 按科目记忆曾经填写的提交方式，编辑作业时可从建议菜单快速选择；
- 科目编辑窗口支持逐条手动删除提交历史。

### 搜索、筛选与智能排序

全局搜索覆盖：

- 作业标题；
- 详细说明；
- 提交渠道；
- 科目名称；
- 子任务标题。

可组合筛选：

- 科目；
- 优先级；
- 截止窗口：已逾期、今天、未来 7 天、无日期；
- 是否仅显示含 Checklist 的作业。

智能排序综合以下因素：

```text
紧急度分数 =
    自定义权重 × 35
  + 优先级 × 25
  + 截止日期紧迫性（逾期、6 小时、24 小时、3 天、7 天等分段）
  - Checklist 完成率惩罚
```

逾期作业获得最高档基础分；同分时优先展示截止日期更近、创建时间更早的作业。列表左侧还会显示前 5 名关注序号。

### 时间块（Time Blocking）

- 将待办作业转化为可执行的日程；
- 设置时间块标题、开始时间、持续时长、科目、关联作业与备注；
- 在作业详情中查看关联工作时段；
- 在仪表盘查看近期时间块；
- 支持创建、编辑、删除。

### 数据仪表盘

使用 macOS 原生 Swift Charts 展示：

- 不同学科时间投入占比；
- 各科目完成率；
- 活跃作业、已完成作业、逾期作业与 Checklist 统计；
- 近期学习时间块。

### 本地提醒

- 使用 `UNUserNotificationCenter` 请求通知权限；
- 按“截止日期前 N 小时”生成本地通知；
- 作业完成、截止时间或提醒设置变化时自动取消并重建通知。

### 软件更新、iCloud 与导出

设置窗口提供：

- 从 GitHub 的 Release/Tag 获取最新版本，比较当前版本并提供查看更新的入口；
- 网络不可用、API 受限或仓库暂无版本时显示可恢复的错误状态；
- 将全部数据导出为带 ISO-8601 日期的格式化 JSON；
- 一键预选 iCloud 云盘目录，通过 macOS 系统保存面板完成云盘备份；
- JSON 中包含科目、作业、子任务、时间块和提交方式历史；
- “关于”中显示当前版本与作者：HyperPlus。

### iCloud Drive 自动同步

在“设置 → iCloud 自动同步”中可以：

- 打开或关闭“每次打开和到时自动同步”，首次开启时使用 macOS 系统面板选择 iCloud 云盘文件夹；
- 设置每日同步时间，应用运行到该时间后自动执行一次；
- 每次启动主窗口时自动执行同步，跨过设定时间后不会重复同步当天任务；
- 随时点击“立即同步”，并查看同步状态与上次同步时间；
- 手动更改同步文件夹，安全范围书签由 App Sandbox 持久保存。

同步文件固定命名为 `StudyFlow-Sync.json`，分别保存在应用的 Application Support 与所选 iCloud 文件夹。每次同步会比较两个文件的修改时间：

```text
本地修改时间 > iCloud 修改时间  → 用本地 JSON 覆盖 iCloud JSON
iCloud 修改时间 > 本地修改时间  → 导入 iCloud JSON 并覆盖本地 JSON
修改时间相同                  → 不覆盖
只有一侧存在                  → 把存在的一侧同步到另一侧
两侧都不存在                  → 用当前 SwiftData 数据创建两个文件
```

用户保存作业、科目、子任务、时间块或提交历史时，本地比较文件会同步刷新；恢复 iCloud 中较新的数据后，应用会重建本地通知。

### 系统日历同步

通过 `EventKit` 支持：

- 在设置中打开“总是同步到系统日历”时主动请求 macOS 14 日历权限；
- 开关打开后，新建作业会自动创建日历事件；
- 编辑已同步作业会更新同一个事件，删除截止日期或完成作业会删除事件；
- 即使关闭全局开关，已同步作业的编辑与完成仍会继续更新或删除现有事件；
- 详情页可手动“添加到系统日历”或“取消日历同步”；
- 自动写入科目、提交方式与详细说明；
- 默认创建截止前 1 小时的事件与提前 24 小时的提醒，并避免重复叠加提醒。

---

## Android 功能概览

Android 分支位于独立的 `android` 分支，主要特性包括：

- Jetpack Compose + Material 3 Expressive 界面，Room/SQLite 本地持久化；
- 深色模式适配与深色模式文字颜色优化；
- 科目层级、作业 CRUD、截止日期、提交方式与子任务 Checklist；
- 全局搜索、组合筛选、智能排序、时间块与数据仪表盘；
- 本地提醒、系统日历同步、GitHub 更新检查；
- 仅支持 JSON 导出，不包含 iCloud；
- 手机竖屏使用常规底栏；横屏、折叠屏和平板使用右侧悬浮侧边栏与操作按钮；
- 大圆角 pill 悬浮底栏、高斯模糊、自适应图标与双层图标；
- 设置中提供“关于”，作者：HyperPlus。

---

## macOS 项目架构

```text
StudyFlow/
├── Package.swift
├── Sources/StudyFlow/
│   ├── StudyFlowApp.swift              # 应用入口、Scene、全局快捷键
│   ├── Models/
│   │   ├── Models.swift                # SwiftData 数据模型
│   │   └── FilterState.swift           # 列表范围与组合筛选状态
│   ├── Services/
│   │   ├── SmartScoring.swift          # 截止紧迫性智能排序
│   │   ├── NotificationManager.swift   # 本地通知授权与调度
│   │   ├── CalendarService.swift       # EventKit 同步
│   │   ├── GitHubUpdateService.swift   # GitHub 更新检查
│   │   ├── DataExportService.swift     # JSON 导出与完整快照恢复
│   │   ├── ICloudSyncCoordinator.swift # iCloud 启动/定时同步协调
│   │   ├── PersistentStore.swift       # 保存并刷新本地同步镜像
│   │   ├── SubmissionMethod.swift      # 网址与邮件目标识别
│   │   ├── SubmissionHistoryStore.swift# 科目提交方式历史
│   │   └── StudyOperations.swift       # 科目层级与安全删除操作
│   ├── Views/
│   │   ├── ContentView.swift           # 主窗口与 Inspector 布局
│   │   ├── SidebarView.swift           # 科目树与视图范围
│   │   ├── AssignmentListView.swift    # 搜索、筛选、排序和列表
│   │   ├── AssignmentDetailView.swift  # 作业详情、Checklist、时间块
│   │   ├── AssignmentEditorView.swift  # 作业编辑表单
│   │   ├── SubjectEditorView.swift     # 科目编辑
│   │   ├── TimeBlockEditorView.swift   # 时间块编辑
│   │   └── DashboardView.swift         # 数据仪表盘
│   └── Components/                     # 选择器、状态卡片、提交方式与视觉组件
├── Resources/
│   ├── Info.plist
│   ├── StudyFlow.entitlements
│   └── AppIcon.icns
└── Scripts/
    ├── build-app.sh                    # 一键构建完整 .app
    └── generate_app_icon.py            # 应用图标生成脚本
```

### 持久化

应用使用 SwiftData 持久化以下模型：

- `Subject`：科目树；
- `Assignment`：作业与截止元数据；
- `Subtask`：Checklist 子任务，使用级联删除关系；
- `TimeBlock`：工作时间块；
- `SubmissionHistoryEntry`：按科目保存的提交方式历史。

默认数据库位于当前应用的 macOS Sandbox 容器中。开启 iCloud 自动同步后，SwiftData 数据还会维护 `Application Support/StudyFlow/Sync/StudyFlow-Sync.json` 本地比较文件。若设置了 `STUDYFLOW_STORE_PATH` 环境变量，应用会改用指定的 SQLite 文件；该选项主要用于自动化测试或便携式数据目录：

```bash
STUDYFLOW_STORE_PATH=/path/to/StudyFlow.store open dist/StudyFlow.app
```

### iCloud 与同步状态

应用数据默认保存在 SwiftData SQLite 数据库中。设置窗口既支持把完整数据导出为 JSON，也支持开启 **iCloud Drive 文件自动同步**：启动应用或到达每日设定时间后，按本地与 iCloud 文件的修改时间执行“新者覆盖旧者”。

当前同步基于用户选择的 iCloud 文件夹与 JSON 快照，不使用 CloudKit；这样可以明确控制冲突结果并保持数据可迁移。数据模型使用稳定 UUID 关联对象，未来仍可接入 `ModelConfiguration(cloudKitDatabase:)`。

---

## macOS 权限说明

`Resources/Info.plist` 与 `Resources/StudyFlow.entitlements` 已包含：

- `com.apple.security.app-sandbox`：macOS App Sandbox；
- `com.apple.security.personal-information.calendars`：日历访问；
- `com.apple.security.network.client`：从 GitHub 检查软件更新；
- `com.apple.security.files.user-selected.read-write`：通过系统面板导出 JSON，并持久访问用户选择的 iCloud 同步文件夹；
- `NSCalendarsFullAccessUsageDescription`：macOS 14 日历权限用途说明；
- `NSCalendarsUsageDescription`：兼容性用途说明。

首次同步日历时，macOS 会显示系统权限提示。若此前拒绝，可在：

**系统设置 → 隐私与安全性 → 日历**

中重新允许 StudyFlow。

通知首次启动时会请求权限；若拒绝，可在：

**系统设置 → 通知**

中恢复。

---

## macOS 设计与交互

- 原生 `NavigationSplitView` 侧边栏结构；
- 原生 Inspector 详情面板；
- 分组表单、菜单、弹窗、上下文菜单与系统快捷键；
- `⌘N` 新建作业，`⇧⌘N` 新建科目，`⇧⌘T` 新建时间块；
- 支持列表选择、键盘操作、辅助功能标签与文本选择；
- 使用系统动态颜色、SF Symbols、材质背景与高 DPI 原生渲染；
- 最小窗口尺寸为 1000 × 680，默认窗口为 1280 × 820。

---

## 质量校验

### macOS

- Swift 6 全量类型检查；
- 优化编译与完整应用包构建；
- `codesign --verify --deep --strict`；
- `plutil -lint` 属性列表校验；
- SwiftData 测试数据库初始化检查；
- 1.4.1 构建包、版本号与 ZIP 完整性验证通过。

### Android

- `assembleRelease`、单元测试与 Lint Release 构建通过；
- v2/v3 APK 签名校验通过；
- 真机深色模式与设置“关于”界面验证通过。

---

## 许可

本项目采用 [GNU General Public License v3.0](LICENSE) 开源发布。
