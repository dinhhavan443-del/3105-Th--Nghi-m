
import Foundation
import Combine

struct SharedFileItem: Identifiable, Hashable {
    let name: String
    let relativePath: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date?

    var id: String { relativePath }

    var sizeText: String {
        isDirectory
            ? "Thư mục"
            : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

@MainActor
final class SharedFolderManager: ObservableObject {

    @Published private(set) var files: [SharedFileItem] = []
    @Published var errorMessage: String?
    @Published private(set) var folderName = ""
    @Published private(set) var currentRelativePath = ""
    @Published private(set) var isLoading = false

    private let bookmarkKey = "3105.shared.folder.bookmark"

    var hasSelectedFolder: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    var currentFolderDisplayName: String {
        let name = currentRelativePath
            .split(separator: "/")
            .last
            .map(String.init)

        return name ?? folderName
    }

    // MARK: - Chọn thư mục

    func saveFolder(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()

        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)

            folderName = url.lastPathComponent
            currentRelativePath = ""
            errorMessage = nil

            refresh()
        } catch {
            errorMessage = "Không lưu được quyền thư mục: \(error.localizedDescription)"
        }
    }

    // MARK: - Đọc bookmark

    private func resolveRoot() throws -> (URL, Bool) {
        guard let bookmark = UserDefaults.standard.data(
            forKey: bookmarkKey
        ) else {
            throw NSError(
                domain: "ThreeOneOSFive.SharedFolder",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Bạn chưa chọn thư mục Documents."
                ]
            )
        }

        var stale = false

        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )

        return (url, stale)
    }

    // MARK: - Làm mới danh sách

    func refresh() {
        isLoading = true
        errorMessage = nil

        do {
            let (root, stale) = try resolveRoot()

            if stale {
                files = []
                errorMessage = "Quyền truy cập đã cũ. Hãy chọn lại thư mục."
                isLoading = false
                return
            }

            let didStart = root.startAccessingSecurityScopedResource()

            defer {
                if didStart {
                    root.stopAccessingSecurityScopedResource()
                }
            }

            let target = safeURL(
                root: root,
                relativePath: currentRelativePath
            )

            let keys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey
            ]

            var result: [SharedFileItem] = []
            var coordinationError: NSError?
            var readError: Error?

            NSFileCoordinator().coordinate(
                readingItemAt: target,
                options: [],
                error: &coordinationError
            ) { readableURL in
                do {
                    let urls = try FileManager.default.contentsOfDirectory(
                        at: readableURL,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles]
                    )

                    result = urls.compactMap { url in
                        guard let relative = relativePath(
                            root: root,
                            child: url
                        ) else {
                            return nil
                        }

                        let values = try? url.resourceValues(
                            forKeys: keys
                        )

                        return SharedFileItem(
                            name: url.lastPathComponent,
                            relativePath: relative,
                            isDirectory: values?.isDirectory ?? false,
                            size: Int64(values?.fileSize ?? 0),
                            modifiedAt: values?.contentModificationDate
                        )
                    }
                    .sorted {
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

            if let error = coordinationError {
                throw error
            }

            if let error = readError {
                throw error
            }

            files = result
            folderName = root.lastPathComponent
            errorMessage = nil

        } catch {
            files = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Mở thư mục con

    func openFolder(_ item: SharedFileItem) {
        guard item.isDirectory else { return }

        currentRelativePath = item.relativePath
        refresh()
    }

    func goBack() {
        guard !currentRelativePath.isEmpty else { return }

        var components = currentRelativePath.split(separator: "/")
        if !components.isEmpty {
            components.removeLast()
        }

        currentRelativePath = components.joined(separator: "/")
        refresh()
    }

    // MARK: - Sao chép vào Documents của ứng dụng

    func copyToAppDocuments(_ item: SharedFileItem) {
        do {
            let (root, stale) = try resolveRoot()

            guard !stale else {
                throw NSError(
                    domain: "ThreeOneOSFive.SharedFolder",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Quyền thư mục đã hết hiệu lực."
                    ]
                )
            }

            let didStart = root.startAccessingSecurityScopedResource()

            defer {
                if didStart {
                    root.stopAccessingSecurityScopedResource()
                }
            }

            let source = safeURL(
                root: root,
                relativePath: item.relativePath
            )

            let documents = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]

            var destination = documents.appendingPathComponent(
                item.name,
                isDirectory: item.isDirectory
            )

            if FileManager.default.fileExists(atPath: destination.path) {
                let name = destination.deletingPathExtension().lastPathComponent
                let ext = destination.pathExtension
                let suffix = UUID().uuidString.prefix(6)

                let newName = ext.isEmpty
                    ? "\(name)_\(suffix)"
                    : "\(name)_\(suffix).\(ext)"

                destination = documents.appendingPathComponent(
                    newName,
                    isDirectory: item.isDirectory
                )
            }

            var coordinationError: NSError?
            var copyError: Error?

            NSFileCoordinator().coordinate(
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

            if let error = coordinationError {
                throw error
            }

            if let error = copyError {
                throw error
            }

            errorMessage = "Đã sao chép vào Documents của 3105."

        } catch {
            errorMessage = "Sao chép thất bại: \(error.localizedDescription)"
        }
    }

    // MARK: - Thu hồi quyền

    func removeFolderAccess() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)

        files = []
        folderName = ""
        currentRelativePath = ""
        errorMessage = nil
    }

    // MARK: - Chống truy cập vượt thư mục gốc

    private func safeURL(
        root: URL,
        relativePath: String
    ) -> URL {
        let components = relativePath
            .split(separator: "/")
            .map(String.init)
            .filter {
                !$0.isEmpty && $0 != "." && $0 != ".."
            }

        return components.reduce(root) { partial, component in
            partial.appendingPathComponent(component)
        }
    }

    private func relativePath(
        root: URL,
        child: URL
    ) -> String? {
        let rootPath = root.standardizedFileURL.path
        let childPath = child.standardizedFileURL.path

        guard childPath.hasPrefix(rootPath + "/") else {
            return nil
        }

        return String(childPath.dropFirst(rootPath.count + 1))
    }
}
