import SwiftUI

enum ImportSource: String, CaseIterable, Identifiable {
    case netease = "网易云音乐"
    case qq = "QQ音乐"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .netease: return "cloud"
        case .qq: return "music.quarternote.3"
        }
    }

    var placeholder: String {
        switch self {
        case .netease: return "粘贴网易云歌单链接或 ID"
        case .qq: return "粘贴 QQ 音乐歌单链接或 ID"
        }
    }
}

struct PlaylistImportView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSource: ImportSource = .netease
    @State private var inputText = ""
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var errorMessage: String?
    @State private var showResult = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("来源") {
                    Picker("来源", selection: $selectedSource) {
                        ForEach(ImportSource.allCases) { source in
                            Label(source.rawValue, systemImage: source.icon)
                                .tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField(selectedSource.placeholder, text: $inputText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            inputText = clipboard
                        }
                    } label: {
                        Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("歌单链接或 ID")
                } footer: {
                    Text("支持歌单分享链接或直接输入歌单 ID")
                }

                Section {
                    Button {
                        Task { await performImport() }
                    } label: {
                        HStack {
                            Spacer()
                            if isImporting {
                                ProgressView()
                            } else {
                                Text("开始导入")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inputText.isEmpty || isImporting)
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("导入后将自动创建同名歌单，仅匹配曲库中已有的歌曲")
                }

                Section("使用说明") {
                    Label("在网易云 / QQ 音乐中打开歌单并分享", systemImage: "1.circle")
                    Label("复制分享链接", systemImage: "2.circle")
                    Label("粘贴到上方输入框", systemImage: "3.circle")
                    Label("点击「开始导入」，系统会匹配曲库中的歌曲", systemImage: "4.circle")
                }
            }
            .navigationTitle("导入歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("导入结果", isPresented: $showResult) {
                Button("确定") {
                    if importResult?.matchedCount ?? 0 > 0 {
                        dismiss()
                    }
                }
            } message: {
                if let result = importResult {
                    Text("歌单「\(result.playlistName)」\n共 \(result.totalTracks) 首\n匹配成功 \(result.matchedCount) 首\n未匹配 \(result.failedCount) 首")
                }
            }
            .alert("导入失败", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private func performImport() async {
        let service = PlaylistImportService.shared
        var playlistId: String?

        switch selectedSource {
        case .netease:
            playlistId = service.parseNeteasePlaylistId(inputText)
        case .qq:
            playlistId = service.parseQQPlaylistId(inputText)
        }

        guard let id = playlistId else {
            errorMessage = "无法解析歌单 ID，请检查输入"
            showError = true
            return
        }

        isImporting = true

        do {
            let result: ImportResult
            let token = authService.token

            switch selectedSource {
            case .netease:
                result = try await service.importNeteasePlaylist(playlistId: id, token: token)
            case .qq:
                result = try await service.importQQPlaylist(disstid: id, token: token)
            }

            await MainActor.run {
                self.importResult = result
                self.isImporting = false
                self.showResult = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isImporting = false
                self.showError = true
            }
        }
    }
}
