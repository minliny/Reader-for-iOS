import UIKit
import WebKit
import XCTest

@MainActor
enum GoldenBrowserDocument {
    static func render(width: CGFloat, height: CGFloat) async throws -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: bounds, configuration: configuration)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.showsHorizontalScrollIndicator = false
        web.scrollView.showsVerticalScrollIndicator = false
        let host = UIViewController()
        host.view.addSubview(web)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let prior = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = bounds
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            web.stopLoading()
            window.isHidden = true
            window.rootViewController = nil
            prior?.makeKey()
        }

        web.loadHTMLString(document, baseURL: nil)
        for _ in 0..<60 {
            if let marker = try? await web.evaluateJavaScript(
                "document.readyState === 'complete' && document.body.dataset.fixture"
            ) as? String, marker == "reader-golden-login" {
                let snapshot = WKSnapshotConfiguration()
                snapshot.rect = bounds
                snapshot.snapshotWidth = NSNumber(value: Double(width))
                snapshot.afterScreenUpdates = true
                return try await web.takeSnapshot(configuration: snapshot)
            }
            try await Task.sleep(for: .milliseconds(35))
        }
        throw CocoaError(.fileReadCorruptFile)
    }

    private static let document = """
    <!doctype html>
    <html lang="zh-CN">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <meta name="color-scheme" content="light">
    <style>
    * { box-sizing: border-box; }
    body { margin: 0; color: #212b25; background: #fff; font: 16px -apple-system, sans-serif; }
    main { padding: 34px 26px; max-width: 430px; margin: auto; }
    h1 { margin: 0 0 10px; font-size: 24px; }
    p { margin: 0 0 26px; color: #556158; line-height: 1.6; }
    label { display: block; margin: 0 0 6px; font-size: 14px; font-weight: 600; }
    .field { border: 1px solid #879589; border-radius: 6px; height: 41px; margin: 0 0 16px; }
    .submit { border-radius: 6px; color: white; background: #27614c; line-height: 42px;
              text-align: center; font-weight: 600; margin-top: 24px; }
    </style>
    <body data-fixture="reader-golden-login">
    <main>
    <h1>沿河书屋</h1>
    <p>登录后继续访问此书源。</p>
    <label>用户名</label><div class="field"></div>
    <label>密码</label><div class="field"></div>
    <div class="submit">登录</div>
    </main>
    </body></html>
    """
}
