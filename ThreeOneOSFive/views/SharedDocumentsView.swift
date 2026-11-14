
import SwiftUI
import UniformTypeIdentifiers

struct SharedDocumentsView: View {

    @StateObject private var manager = SharedFolderManager()
    @State private var showPicker = false
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                folderHeader

                if !manager.currentRelativePath.isEmpty {
                    Button {
                        manager.goBack()
                    } label: {
                        Label("Quay lại thư mục trước", systemImage: "arrow.left")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Divider()
                }

                if let error = manager.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }

                if manager.isLoading {
                    Spacer()
                    ProgressView("Đang đọc thư mục...")
                    Spacer()
                } else if !manager.hasSelectedFolder {
                    emptyState
                } else if manager.files.isEmpty {
                    emptyFolderState
                } else {
                    fileList
                }

                bottomActions
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        manager.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(manager.isLoading || !manager.hasSelectedFolder)
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    manager.saveFolder(url)

                case .failure(let error):
                    // Người dùng có thể hủy trình chọn tệp.
                    manager.errorMessage = error.localizedDescription
                }
            }
            .alert("Đã sao chép", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tệp đã được sao chép vào Documents của ứng dụng 3105.")
            }
        }
    }

    private var folderHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 34))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(manager.hasSelectedFolder
                     ? manager.currentFolderDisplayName
                     : "Chưa chọn thư mục")
                    .font(.headline)
                    .lineLimit(1)

                Text(manager.hasSelectedFolder
                     ? manager.currentRelativePath.isEmpty
                        ? "Thư mục gốc đã chọn"
                        : manager.currentRelativePath
                     : "Chọn thư mục từ ứng dụng Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Circle()
                .fill(manager.hasSelectedFolder ? Color.green : Color.gray)
                .frame(width: 9, height: 9)
        }
        .padding()
    }

    private var fileList: some View {
        List {
            Section("Tệp và thư mục") {
                ForEach(manager.files) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.isDirectory
                              ? "folder.fill"
                              : "doc.fill")
                            .font(.title3)
                            .foregroundStyle(
                                item.isDirectory ? .yellow : .blue
                            )
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            Text(item.sizeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if item.isDirectory {
                            Button {
                                manager.openFolder(item)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                manager.copyToAppDocuments(item)
                                showCopiedAlert =
                                    manager.errorMessage?.hasPrefix("Đã sao chép") == true
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .padding(8)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Sao chép \(item.name)")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if item.isDirectory {
                            manager.openFolder(item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Chưa cấp quyền thư mục")
                .font(.headline)

            Text("Chọn một thư mục trong Files để 3105 có thể duyệt nội dung bạn cho phép.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button {
                showPicker = true
            } label: {
                Label("Chọn thư mục", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFolderState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text("Thư mục trống")
                .font(.headline)

            Text("Không tìm thấy tệp hoặc thư mục con có thể hiển thị.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button {
                showPicker = true
            } label: {
                Label(
                    manager.hasSelectedFolder
                        ? "Chọn thư mục khác"
                        : "Chọn thư mục từ Files",
                    systemImage: "folder.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if manager.hasSelectedFolder {
                Button(role: .destructive) {
                    manager.removeFolderAccess()
                } label: {
                    Label("Thu hồi quyền thư mục", systemImage: "lock.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
