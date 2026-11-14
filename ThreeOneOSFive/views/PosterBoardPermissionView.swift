
import SwiftUI

struct PosterBoardPermissionView: View {

    @State private var isChecking = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {

            Button {
                checkPermission()
            } label: {
                Text(isChecking
                     ? "Đang kiểm tra..."
                     : "Kiểm tra quyền PosterBoard")
                    .font(.headline)
            }
            .disabled(isChecking)
        }
        .alert("Thao tác hình nền thất bại",
               isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func checkPermission() {
        guard !isChecking else { return }

        isChecking = true

        Task { @MainActor in
            defer { isChecking = false }

            // Thay bằng kết quả kiểm tra quyền thực tế
            // từ cơ chế truy cập hợp pháp của dự án.

            let readAllowed = false
            let writeAllowed = false

            switch PosterBoardCompatibility.checkAccess(
                readAllowed: readAllowed,
                writeAllowed: writeAllowed
            ) {
            case .success:
                errorMessage = ""
            case .failed(let message):
                errorMessage = message
                showError = true
            }
        }
    }
}
