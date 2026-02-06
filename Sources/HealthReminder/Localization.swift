import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: args)
}

