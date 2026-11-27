import Foundation
import os

/// One collector per bounded HTTP attempt. URLSession delivers Data blocks on
/// its serial delegate queue. Cancellation can arrive from the calling task.
final class HostResponseCollector: NSObject, URLSessionDataDelegate {
    private typealias Payload = (Data, HTTPURLResponse)

    private struct State: Sendable {
        var task: URLSessionDataTask?
        var continuation: CheckedContinuation<Payload, any Error>?
        var response: HTTPURLResponse?
        var body = Data()
        var finished = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let limit: Int
    private let redirects: HostRedirectPolicy

    init(limit: Int, redirects: HostRedirectPolicy) {
        self.limit = limit
        self.redirects = redirects
    }

    func read(_ request: URLRequest, session: URLSession) async throws -> (Data, HTTPURLResponse) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request)
                let started = state.withLock { state in
                    guard !state.finished else { return false }
                    state.task = task
                    state.continuation = continuation
                    return true
                }
                if started {
                    task.resume()
                } else {
                    task.cancel()
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            self.finish(.failure(CancellationError()), cancelTask: true)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        redirects.urlSession(session, task: task, willPerformHTTPRedirection: response,
                             newRequest: request, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse else {
            finish(.failure(NetworkHostFailure.invalid("Missing HTTP response")))
            completionHandler(.cancel)
            return
        }
        if redirects.observations().limitExceeded {
            finish(.failure(NetworkHostFailure(code: .httpError, phase: .transport, message: "HTTP redirect limit exceeded")))
            completionHandler(.cancel)
            return
        }
        if response.expectedContentLength > limit {
            finish(.failure(bodyLimitExceeded))
            completionHandler(.cancel)
            return
        }
        if response.statusCode >= 400 {
            // The caller maps the HTTP status from headers. Error bodies do
            // not consume the cap or delay the original terminal.
            finish(.success((Data(), response)))
            completionHandler(.cancel)
            return
        }
        let active = state.withLock { state in
            guard !state.finished else { return false }
            state.response = response
            return true
        }
        completionHandler(active ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let exceedsLimit = state.withLock { state in
            guard !state.finished else { return false }
            guard data.count <= limit - state.body.count else { return true }
            state.body.append(data)
            return false
        }
        if exceedsLimit { finish(.failure(bodyLimitExceeded), cancelTask: true) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            finish(.failure(error))
        } else if let payload = state.withLock({ state in state.response.map { (state.body, $0) } }) {
            finish(.success(payload))
        } else {
            finish(.failure(NetworkHostFailure.invalid("Missing HTTP response")))
        }
    }

    private var bodyLimitExceeded: NetworkHostFailure {
        .invalid("HTTP response exceeds byte budget")
    }

    private func finish(_ result: Result<Payload, any Error>, cancelTask: Bool = false) {
        let pending = state.withLock { state in
            guard !state.finished else { return (nil as URLSessionDataTask?, nil as CheckedContinuation<Payload, any Error>?) }
            let pending = (state.task, state.continuation)
            state = State(finished: true)
            return pending
        }
        if cancelTask { pending.0?.cancel() }
        pending.1?.resume(with: result)
    }
}
