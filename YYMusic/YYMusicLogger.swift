import Foundation
import SwiftUI

// MARK: - 日志级别

enum YYMusicLogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"

    var tint: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }
}

// MARK: - 单条日志

struct YYMusicLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let level: YYMusicLogLevel
    let message: String
}

// MARK: - 全局日志中心

/// 全局日志中心：内存环形缓存（供 App 内查看）+ 文件持久化（Documents/YYMusicLogs/beans-日期.log，可导出分享）。
/// 任意线程可调用 log()，界面更新自动切回主线程。
final class YYMusicLogger: ObservableObject {
    static let shared = YYMusicLogger()

    @Published private(set) var entries: [YYMusicLogEntry] = []

    private let maxEntries = 800
    private let maxLogFileBytes = 2 * 1024 * 1024
    private let lock = NSLock()
    private var recentEntries: [YYMusicLogEntry] = []

    private static let lineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
    private static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private init() {
        log("YY Music 启动（版本 \(Self.appVersion)）", level: .info)
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static func dateString(_ date: Date) -> String {
        lineFormatter.string(from: date)
    }

    /// 记录一条日志（任意线程可调用）
    func log(_ message: String, level: YYMusicLogLevel = .debug) {
        let entry = YYMusicLogEntry(date: Date(), level: level, message: message)
        lock.lock()
        recentEntries.append(entry)
        if recentEntries.count > maxEntries {
            recentEntries.removeFirst(recentEntries.count - maxEntries)
        }
        let snapshot = recentEntries
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.entries = snapshot
        }
        write(entry.line)
    }

    /// 全部日志文本（按时间正序）
    var fullText: String {
        lock.lock()
        let snapshot = recentEntries
        lock.unlock()
        return snapshot.map(\.line).joined(separator: "\n")
    }

    /// 清空内存日志与日志文件
    func clear() {
        lock.lock()
        recentEntries = []
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.entries = []
        }
        try? FileManager.default.removeItem(at: logDirectory)
        log("日志已清空", level: .info)
    }

    // MARK: - 文件持久化

    private var logDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YYMusicLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var currentFileURL: URL {
        logDirectory.appendingPathComponent("beans-\(Self.fileStampFormatter.string(from: Date())).log")
    }

    /// 导出日志文件（不存在则先生成一份完整日志）
    func exportLogURL() -> URL {
        let url = currentFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? fullText.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    private func write(_ line: String) {
        let url = currentFileURL
        // 单日日志过大时轮转到 .1，避免无限膨胀
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        if fileSize > maxLogFileBytes {
            let rotated = url.deletingPathExtension().appendingPathExtension("1.log")
            try? FileManager.default.removeItem(at: rotated)
            try? FileManager.default.moveItem(at: url, to: rotated)
        }
        let payload = (line + "\n").data(using: .utf8) ?? Data()
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(payload)
        } else {
            try? payload.write(to: url, options: .atomic)
        }
    }
}

extension YYMusicLogEntry {
    var line: String {
        "[\(YYMusicLogger.dateString(date))] [\(level.rawValue)] \(message)"
    }
}
