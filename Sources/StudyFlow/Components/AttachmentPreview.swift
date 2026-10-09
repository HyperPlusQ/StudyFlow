import AppKit
import QuickLookUI
import SwiftUI

/// 附件预览用的临时文件管理：内存里的图片先落盘，交给系统 QuickLook 渲染。
@MainActor
enum AttachmentPreviewStore {
    private static let directoryName = "StudyFlowAttachmentPreviews"

    static func writeTemporaryFile(fileName: String, mimeType: String, data: Data) -> URL? {
        guard !data.isEmpty else { return nil }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(directoryName, isDirectory: true)
        let safeName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileExtension = BackupArchive.fileExtension(for: mimeType)
        let baseName = safeName.isEmpty
            ? UUID().uuidString
            : "\(UUID().uuidString)-\(safeName)"
        let url = directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(fileExtension)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            NSLog("StudyFlow 无法写入预览临时文件：\(error.localizedDescription)")
            return nil
        }
    }

    static func remove(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// 系统 QuickLook 图片视图：沿用访达“快速查看”的渲染，支持缩放与系统视觉效果。
private struct QuickLookImageView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view: QLPreviewView = QLPreviewView(frame: .zero)
        view.shouldCloseWithWindow = false
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        guard (nsView.previewItem as? URL) != url else { return }
        nsView.previewItem = url as NSURL
    }
}

/// 全屏图片预览内容：黑底 + QuickLook 渲染 + 右上角关闭按钮（Esc 同样可关）。
struct AttachmentQuickLookViewer: View {
    let url: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            QuickLookImageView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            closeButton
        }
        .onExitCommand(perform: onDismiss)
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.55))
                .font(.system(size: 26))
                .shadow(radius: 3)
        }
        .buttonStyle(.plain)
        .padding(18)
        .help("关闭预览")
        .accessibilityLabel("关闭预览")
    }
}

/// 用系统全屏窗口承载 QuickLook 预览：点击附件即全屏展示，带关闭按钮。
/// macOS 没有 fullScreenCover，这里走 AppKit 的原生全屏（系统 Space 动画与退出方式）。
@MainActor
final class AttachmentPreviewWindowController: NSObject, NSWindowDelegate {
    static let shared = AttachmentPreviewWindowController()

    private var window: NSWindow?
    private var previewURL: URL?

    func present(attachment: ImageAttachment) {
        present(
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            data: attachment.imageData
        )
    }

    func present(fileName: String, mimeType: String, data: Data) {
        // 同一时间只保留一个预览窗口，先清理上一个（含其临时文件）。
        let previousWindow = window
        let previousURL = previewURL
        window = nil
        previewURL = nil
        AttachmentPreviewStore.remove(previousURL)
        previousWindow?.close()

        guard let url = AttachmentPreviewStore.writeTemporaryFile(
            fileName: fileName,
            mimeType: mimeType,
            data: data
        ) else { return }
        guard let screen = NSScreen.main else {
            AttachmentPreviewStore.remove(url)
            return
        }

        let previewWindow = NSWindow(
            contentRect: screen.visibleFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        previewWindow.titleVisibility = .hidden
        previewWindow.titlebarAppearsTransparent = true
        previewWindow.backgroundColor = .black
        previewWindow.isReleasedWhenClosed = false
        previewWindow.delegate = self
        previewWindow.contentViewController = NSHostingController(
            rootView: AttachmentQuickLookViewer(url: url) { [weak self] in
                self?.dismiss()
            }
        )

        window = previewWindow
        previewURL = url
        previewWindow.makeKeyAndOrderFront(nil)
        previewWindow.toggleFullScreen(nil)
    }

    /// 关闭预览窗口；关闭回调里统一清理临时文件。
    func dismiss() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        AttachmentPreviewStore.remove(previewURL)
        previewURL = nil
        window = nil
    }
}
