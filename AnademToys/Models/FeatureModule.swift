import Foundation
import SwiftUI

enum FeatureModule: String, CaseIterable, Identifiable {
    case urlSchemes
    case generalSettings
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urlSchemes:
            "URL Scheme"
        case .generalSettings:
            "通用设置"
        case .about:
            "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .urlSchemes:
            "link"
        case .generalSettings:
            "gearshape"
        case .about:
            "info.circle"
        }
    }
}
