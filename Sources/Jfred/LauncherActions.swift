import Foundation

struct LauncherAction: Identifiable, Equatable {
    enum Kind: String {
        case open
        case reveal
        case copyPath
        case copyName
        case copyValue
        case openBrowser
        case quickLook
        case largeType
        case pasteClipboard
        case pasteValue
        case email
        case call
        case searchWeb
        case maps
    }

    var kind: Kind
    var title: String
    var subtitle: String
    var symbol: String

    var id: String { "\(kind.rawValue):\(title)" }
}
