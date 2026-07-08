import Foundation

enum ArchiveFormat: String, CaseIterable, Identifiable {
    case zip
    case tar
    case sevenZip
    case rar
    case rar5
    case xar
    case cpio
    case cab
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
        case .rar:
            "RAR"
        case .rar5:
            "RAR5"
        case .xar:
            "XAR"
        case .cpio:
            "CPIO"
        case .cab:
            "CAB"
        case .unknown:
            "未知格式"
        }
    }

}
