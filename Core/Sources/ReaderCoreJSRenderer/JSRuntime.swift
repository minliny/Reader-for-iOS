import Foundation
import JavaScriptCore

public final class JSRuntime: @unchecked Sendable {
    private let timeoutMilliseconds: Int
    private let queue: DispatchQueue
    private let preExecutionDelayMilliseconds: Int
    private let additionalEvaluationScripts: [String]

    public convenience init(timeoutMilliseconds: Int = 1500) {
        self.init(
            configuredTimeoutMilliseconds: timeoutMilliseconds,
            preExecutionDelayMilliseconds: 0,
            additionalEvaluationScripts: []
        )
    }

    private init(
        configuredTimeoutMilliseconds timeoutMilliseconds: Int,
        preExecutionDelayMilliseconds: Int,
        additionalEvaluationScripts: [String]
    ) {
        self.timeoutMilliseconds = max(1, min(timeoutMilliseconds, 1500))
        self.queue = DispatchQueue(label: "ReaderCoreJSRenderer.JSRuntime.\(UUID().uuidString)")
        self.preExecutionDelayMilliseconds = max(0, preExecutionDelayMilliseconds)
        self.additionalEvaluationScripts = additionalEvaluationScripts
    }

    internal static func makeForTesting(
        timeoutMilliseconds: Int = 1500,
        preExecutionDelayMilliseconds: Int = 0,
        additionalEvaluationScripts: [String] = []
    ) -> JSRuntime {
        JSRuntime(
            configuredTimeoutMilliseconds: timeoutMilliseconds,
            preExecutionDelayMilliseconds: preExecutionDelayMilliseconds,
            additionalEvaluationScripts: additionalEvaluationScripts
        )
    }

    public func execute(html: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let fallbackHTML = html
        var outputHTML = fallbackHTML

        queue.async {
            autoreleasepool {
                defer { semaphore.signal() }

                if self.preExecutionDelayMilliseconds > 0 {
                    Thread.sleep(forTimeInterval: Double(self.preExecutionDelayMilliseconds) / 1000.0)
                }

                let virtualMachine = JSVirtualMachine()

                guard let context = JSContext(virtualMachine: virtualMachine) else {
                    return
                }

                var didThrow = false
                context.exceptionHandler = { _, _ in
                    didThrow = true
                }

                context.setObject(fallbackHTML as NSString, forKeyedSubscript: "__inputHTML" as NSString)

                let scripts = [Self.networkLockdownScript, Self.bootstrapDocumentScript] + self.additionalEvaluationScripts
                for script in scripts {
                    _ = context.evaluateScript(script)
                    if didThrow {
                        outputHTML = fallbackHTML
                        return
                    }
                }

                if let resolvedHTML = context.evaluateScript("document.documentElement.outerHTML")?.toString(), !didThrow {
                    outputHTML = resolvedHTML
                }
            }
        }

        let waitResult = semaphore.wait(timeout: .now() + .milliseconds(timeoutMilliseconds))
        if waitResult == .timedOut {
            return fallbackHTML
        }

        return outputHTML
    }

    private static let networkLockdownScript = """
    (function () {
      var blocked = function () {
        throw new Error("Network access is disabled in JSRuntime.");
      };

      this.fetch = blocked;
      this.XMLHttpRequest = undefined;
      this.WebSocket = undefined;
      this.EventSource = undefined;
      this.Worker = undefined;
      this.SharedWorker = undefined;
      this.importScripts = blocked;
      this.navigator = Object.freeze({
        sendBeacon: blocked
      });
    })();
    """

    private static let bootstrapDocumentScript = """
    (function (html) {
      var root = Object.freeze({
        outerHTML: String(html)
      });

      this.document = Object.freeze({
        documentElement: root
      });
    })(__inputHTML);
    """
}
