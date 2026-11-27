import ReaderCoreBridge

/// Publication follows the active page generation. The originating write
/// maintains its own terminal and is allowed to complete after retirement.
@MainActor
final class ReadingSessionCoordinator {
    private let runtime: CoreRuntimeActor
    private var pageGeneration = 0

    init(runtime: CoreRuntimeActor) { self.runtime = runtime }

    func save(
        _ params: TextReadingProgressUpdateParams,
        onDispatched: (@Sendable (CoreOperationID) -> Void)? = nil,
        publish: @escaping @MainActor (ReadingProgressUpdateData) -> Void
    ) -> Task<CoreOperation<ReadingProgressUpdateData>, any Error> {
        let observed = pageGeneration
        return Task { [runtime, weak self] in
            let result = try await runtime.request(ReaderM1.readingProgressUpdate, params, onDispatched: onDispatched)
            if self?.pageGeneration == observed { publish(result.value) }
            return result
        }
    }

    func retirePage() { pageGeneration += 1 }
}
