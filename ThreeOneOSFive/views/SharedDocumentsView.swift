
import SwiftUI
import UniformTypeIdentifiers

struct SharedDocumentsView: View {

    @StateObject private var manager = SharedFolderManager()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                HStack {
                    Image(systemName: "folder.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading) {
                        Text(manager.folderName.isEmpty
                             ? "Chưa chọn thư mục"
                             : manager.folderName)
                            .font(.headline)

                        Text("Documents được chia sẻ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()

                HStack {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Chọn thư mục", systemImage: "folder.badge.plus")
                    }

                    Spacer()

                    Button {
                        manager.refresh()
                    } label: {
                        Label("Làm mới", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.horizontal)

                if let error = manager.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                List(manager.files) { item in
                    HStack {
                        Image(systemName: item.isDirectory
                              ? "folder.fill"
                              : "doc.fill")
                            .foregroundColor(
                                item.isDirectory ? .yellow : .blue
                            )

                        VStack(alignment: .leading) {
                            Text(item.name)
                                .lineLimit(1)

                            Text(item.isDirectory
                                 ? "Thư mục"
                                 : "\(item.size) bytes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            manager.copyToAppDocuments(item)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }

                Button(role: .destructive) {
                    manager.removeFolderAccess()
                } label: {
                    Text("Thu hồi quyền thư mục đã chọn")
                }
                .padding(.bottom)
            }
            .navigationTitle("Quản lý Documents")
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        manager.saveFolder(url)
                    }

                case .failure(let error):
                    manager.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
