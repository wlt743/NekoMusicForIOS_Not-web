import SwiftUI

enum ImportSource: String, CaseIterable {
    case netease = "网易云音乐"
    case qq = "QQ音乐"
    
    var icon: String {
        switch self {
        case .netease: return "cloud.fill"
        case .qq: return "music.quarternote.3"
        }
    }
    
    var color: Color {
        switch self {
        case .netease: return .red
        case .qq: return .green
        }
    }
    
    var placeholder: String {
        switch self {
        case .netease: return "粘贴网易云歌单链接或ID"
        case .qq: return "粘贴QQ音乐歌单链接或ID"
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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Source Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择来源")
                            .font(.headline)
                        
                        Picker("来源", selection: $selectedSource) {
                            ForEach(ImportSource.allCases, id: \.self) { source in
                                HStack {
                                    Image(systemName: source.icon)
                                    Text(source.rawValue)
                                }
                                .tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Input Field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("歌单链接或ID")
                            .font(.headline)
                        
                        HStack {
                            TextField(selectedSource.placeholder, text: $inputText)
                                .textFieldStyle(.plain)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !inputText.isEmpty {
                                Button {
                                    inputText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button {
                                if let clipboardString = UIPasteboard.general.string {
                                    inputText = clipboardString
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Text("支持歌单分享链接或直接输入歌单ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("导入后将自动创建同名歌单")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Import Button
                    Button {
                        Task { await performImport() }
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                            }
                            Image(systemName: "square.and.arrow.down")
                            Text(isImporting ? "导入中..." : "开始导入")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: inputText.isEmpty ? [.gray] : [selectedSource.color, selectedSource.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(inputText.isEmpty || isImporting)
                    .padding(.horizontal)
                    
                    // Help Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("使用说明")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            helpItem(number: "1", text: "在网易云/QQ音乐中打开歌单，点击分享")
                            helpItem(number: "2", text: "复制分享链接")
                            helpItem(number: "3", text: "粘贴到上方输入框")
                            helpItem(number: "4", text: "点击「开始导入」，系统将匹配曲库中的歌曲")
                        }
                        
                        Text("注意：仅匹配NekoMusic曲库中已有的歌曲")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("导入歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
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
    
    private func helpItem(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
            errorMessage = "无法解析歌单ID，请检查输入"
            showError = true
            return
        }
        
        isImporting = true
        
        do {
            let result: ImportResult
            let token = authService.token
            
            switch selectedSource {
            case .netease:
                result = try await service.importNeteasePlaylist(
                    playlistId: id,
                    token: token
                )
            case .qq:
                result = try await service.importQQPlaylist(
                    disstid: id,
                    token: token
                )
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
