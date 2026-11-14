
import Foundation
import UIKit

enum PosterBoardCompatibility {

    static let targetVersion = "18.7.10"
    static let targetBuild = "22H374"
    static let targetDevice = "iPhone11,2"

    static var isTargetVersion: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return version.majorVersion == 18 &&
               version.minorVersion == 7 &&
               version.patchVersion == 10
    }

    enum AccessResult {
        case success
        case failed(String)
    }

    static func checkAccess(
        readAllowed: Bool,
        writeAllowed: Bool
    ) -> AccessResult {

        guard readAllowed else {
            return .failed(
                "Không có quyền đọc dữ liệu PosterBoard."
            )
        }

        guard writeAllowed else {
            return .failed(
                "Không có quyền ghi dữ liệu PosterBoard."
            )
        }

        return .success
    }
}
