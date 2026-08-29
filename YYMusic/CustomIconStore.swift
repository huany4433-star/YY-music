import SwiftUI
import UIKit

// MARK: - 自定义品牌图标

/// 用户可在「设置 → 外观」上传一张图片作为 App 内品牌图标，
/// 显示在播放页（无封面时）、登录页、「我的」页等位置。
///
/// 说明：iOS 不允许用户上传任意图片作为「手机桌面图标」，
/// 只能使用 App 内置的备选图标；这里实现的是 App 内部展示的自定义图标
/// （与「上传壁纸」同一思路，图片保存在沙盒内，重启后依然生效）。
final class CustomIconStore: ObservableObject {
    static let shared = CustomIconStore()
    static let didChange = Notification.Name("yymusic.customIcon.didChange")

    private static var fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom-icon.png")
    }()

    @Published private(set) var hasCustomIcon: Bool

    private init() {
        hasCustomIcon = FileManager.default.fileExists(atPath: Self.fileURL.path)
    }

    /// 当前自定义图标（未设置时返回 nil）
    var customIcon: UIImage? {
        guard hasCustomIcon, let data = try? Data(contentsOf: Self.fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// 保存用户选择的图片（统一转成 PNG 存储，可被设置备份/恢复复用）
    func save(_ data: Data) {
        do {
            let writeData: Data
            if let image = UIImage(data: data), let png = image.pngData() {
                writeData = png
            } else {
                writeData = data
            }
            try writeData.write(to: Self.fileURL, options: .atomic)
            hasCustomIcon = true
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        } catch {
            YYMusicLogger.shared.log("自定义图标保存失败：\(error.localizedDescription)", level: .error)
        }
    }

    /// 恢复默认（清除自定义图标）
    func clear() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        if hasCustomIcon {
            hasCustomIcon = false
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }
}