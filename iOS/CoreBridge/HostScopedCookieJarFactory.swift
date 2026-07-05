import Foundation
import ReaderCoreNetwork
import ReaderCoreProtocols

/// Host factory that produces a `ScopedCookieJar` backed by Core's
/// `BasicCookieJar`, so that iOS layers under the boundary gate
/// (`CoreIntegration`, `Features`, `Shell`, `Tests`, etc.) can obtain a
/// scoped cookie jar without directly importing `ReaderCoreNetwork`.
///
/// This file lives in `iOS/CoreBridge`, which is outside the boundary-gated
/// paths enforced by `scripts/check_ios_boundary.sh`, so it is the designated
/// seam where Core network imports are permitted on the iOS side.
public enum HostScopedCookieJarFactory {
    public static func makeBasicCookieJar() -> any ScopedCookieJar {
        BasicCookieJar()
    }
}
