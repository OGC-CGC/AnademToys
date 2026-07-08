import Foundation

enum ArchiveFormat: String, CaseIterable, Identifiable {
    case zip
    case tar
    case sevenZip
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zip:
            "ZIP"
        case .tar:
            "TAR"
        case .sevenZip:
            "7Z"
        case .unknown:
            "未知格式"
        }
    }

}
