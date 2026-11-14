
import Foundation
import Combine

struct SharedFileItem: Identifiable {
    let id = UUID()
    let name: String
    let relativePath: String
    let isDirectory: Bool
    let size: Int64
}

@MainActor
final class SharedFolderManager: ObservableObject {

    @Published var files: [SharedFileItem] = []
    @Published var errorMessage: String?
    @Published var folderName = ""

    private let bookmarkKey = "3105.shared.folder.bookmark"

    var hasSelectedFolder: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    func saveFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "iOS không cấp quyền truy cập thư mục."
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            folderName = url.lastPathComponent

            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard let bookmark = UserDefaults.standard.data(
            forKey: bookmarkKey
        ) else {
            errorMessage = "Bạn chưa chọn thư mục."
            return
        }

        do {
            var stale = false

            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )

            if stale {
                errorMessage = "Quyền thư mục đã hết hiệu lực. Hãy chọn lại."
                files = []
                return
            }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Không thể mở quyền truy cập thư mục."
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var result: [SharedFileItem] = []
            var readError: Error?

            coordinator.coordinate(
                readingItemAt: url,
                options: [],
                error: &coordinationError
            ) { readableURL in
                do {
                    let keys: [URLResourceKey] = [
                        .isDirectoryKey,
                        .fileSizeKey
                    ]

                    let entries = try FileManager.default.contentsOfDirectory(
                        at: readableURL,
                        includingPropertiesForKeys: keys,
                        options: [.skipsHiddenFiles]
                    )

                    result = entries.map { item in
                        let values = try? item.resourceValues(
                            forKeys: Set(keys)
                        )

                        return SharedFileItem(
                            name: item.lastPathComponent,
                            relativePath: item.lastPathComponent,
                            isDirectory: values?.isDirectory ?? false,
                            size: Int64(values?.fileSize ?? 0)
                        )
                    }.sorted {
                        if $0.isDirectory != $1.isDirectory {
                            return $0.isDirectory
                        }
                        return $0.name.localizedCaseInsensitiveCompare(
                            $1.name
                        ) == .orderedAscending
                    }

                } catch {
                    readError = error
                }
            }

            if let error = coordinationError ?? readError as NSError? {
                throw error
            }

            files = result
            folderName = url.lastPathComponent
            errorMessage = nil

        } catch {
            files = []
            errorMessage = error.localizedDescription
        }
    }

    func copyToAppDocuments(_ item: SharedFileItem) {
        guard let bookmark = UserDefaults.standard.data(
            forKey: bookmarkKey
        ) else {
            errorMessage = "Không tìm thấy thư mục nguồn."
            return
        }

        do {
            var stale = false

            let root = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )

            guard !stale,
                  root.startAccessingSecurityScopedResource() else {
                errorMessage = "Quyền truy cập đã hết hiệu lực."
                return
            }

            defer {
                root.stopAccessingSecurityScopedResource()
            }

            let source = root.appendingPathComponent(
                item.relativePath,
                isDirectory: item.isDirectory
            )

            let destination = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent(item.name)

            guard !FileManager.default.fileExists(
                atPath: destination.path
            ) else {
                errorMessage = "Tệp đích đã tồn tại."
                return
            }

            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var copyError: Error?

            coordinator.coordinate(
                readingItemAt: source,
                options: [],
                error: &coordinationError
            ) { readableURL in
                do {
                    try FileManager.default.copyItem(
                        at: readableURL,
                        to: destination
                    )
                } catch {
                    copyError = error
                }
            }

            if let error = coordinationError ?? copyError as NSError? {
                throw error
            }

            errorMessage = nil

        } catch {
            errorMessage = "Sao chép thất bại: \(error.localizedDescription)"
        }
    }

    func removeFolderAccess() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        files = []
        folderName = ""
        errorMessage = nil
    }
}
