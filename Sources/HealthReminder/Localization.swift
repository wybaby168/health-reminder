import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
}
