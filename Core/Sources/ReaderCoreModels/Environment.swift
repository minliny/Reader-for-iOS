import Foundation

/// 环境变量配置
public enum Environment {
    /// 网站基础URL
    public static var siteURL: String {
        guard let url = ProcessInfo.processInfo.environment["SITE_URL"] else {
            return "https://example.com"
        }
        return url.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 调试模式开关
    public static var isDebug: Bool {
        return ProcessInfo.processInfo.environment["DEBUG"] == "true"
    }
    
    /// 超时时间（秒）
    public static var timeoutInterval: TimeInterval {
        guard let timeout = ProcessInfo.processInfo.environment["TIMEOUT_INTERVAL"] else {
            return 30.0
        }
        return TimeInterval(timeout) ?? 30.0
    }
}