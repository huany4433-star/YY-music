import SwiftUI
import UIKit


/// 日志查看器：展示内存日志（可按级别筛选）或导入的日志文件原文
struct LogViewerSheet: View {
    @ObservedObject private var logger = YYMusicLogger.shared
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let importedText: String?

    @State private var filter: YYMusicLogLevel? = nil
    @State private var showShare = false

    private var filtered: [YYMusicLogEntry] {
        guard let filter else { return logger.entries }
        return logger.entries.filter { $0.level == filter }
    }

    var body: some View {
        let _ = theme.accent
        YYMusicNavigationStack {
            VStack(spacing: 0) {
                if let importedText {
                    ScrollView {
                        Text(importedText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.beansLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .beansScrollIndicatorsHidden()
                } else {
                    Picker("级别", selection: $filter) {
                        Text("全部").tag(nil as YYMusicLogLevel?)
                        ForEach(YYMusicLogLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as YYMusicLogLevel?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    if filtered.isEmpty {
                        EmptyStateView(icon: "doc.text", text: "暂无日志")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(filtered) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(entry.level.rawValue)
                                            .font(YYMusicFont.appFont(9, .bold, .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(entry.level.tint))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.message)
                                                .font(YYMusicFont.appFont(12, .medium))
                                                .foregroundStyle(Color.beansLabel)
                                                .textSelection(.enabled)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text(YYMusicLogger.dateString(entry.date))
                                                .font(YYMusicFont.appFont(9, .regular, .monospaced))
                                                .foregroundStyle(Color.beansComment)
                                        }
                                    }
                                    .padding(9)
                                    .background {
                                        YYMusicGlass(shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                        }
                        .beansScrollIndicatorsHidden()
                    }
                }
            }
            .navigationTitle(importedText == nil ? "日志" : "导入的日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            if let importedText {
                                UIPasteboard.general.string = importedText
                            } else {
                                UIPasteboard.general.string = logger.fullText
                            }
                            ToastCenter.shared.show("日志已复制")
                        } label: {
                            Label("复制全部", systemImage: "doc.on.doc")
                        }
                        if importedText == nil {
                            Button {
                                showShare = true
                            } label: {
                                Label("导出日志", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .modifier(YYMusicSheetModifier(detents: [.large], dragIndicator: true))
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [YYMusicLogger.shared.exportLogURL()])
        }
    }
}
