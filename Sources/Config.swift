import Foundation
import Combine

/// 连接配置的持久化
final class ConfigStore: ObservableObject {
    private enum K {
        static let target = "xz.target"
        static let mode = "xz.mode"
    }

    enum Mode: String, CaseIterable, Identifiable {
        case stream   // ws-scrcpy / 网页串流
        case app      // 跳转原生 App（ToDesk / RustDesk）

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stream: return "串流地址（ws-scrcpy / 网页）"
            case .app:    return "原生 App Scheme"
            }
        }

        var placeholder: String {
            switch self {
            case .stream: return "http://100.64.0.12:8000"
            case .app:    return "todesk://"
            }
        }
    }

    @Published var mode: Mode {
        didSet { defaults.set(mode.rawValue, forKey: K.mode) }
    }

    @Published var target: String {
        didSet { defaults.set(target, forKey: K.target) }
    }

    /// 冷启动时若已有配置就直连
    @Published var autoConnect: Bool = true

    private let defaults = UserDefaults.standard

    init() {
        let rawMode = defaults.string(forKey: K.mode) ?? Mode.stream.rawValue
        self.mode = Mode(rawValue: rawMode) ?? .stream
        self.target = defaults.string(forKey: K.target) ?? ""
    }

    var hasTarget: Bool { !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// 规范化后的 URL（非 http(s) 的 scheme 原样返回，交给系统打开）
    var resolvedURL: URL? {
        let t = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") {
            return URL(string: t)
        }
        if t.contains("://") { return URL(string: t) }
        return URL(string: "http://" + t)
    }
}
