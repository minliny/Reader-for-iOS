# Engineering Architecture Skeleton

## Directory Tree

```text
Core/
  Sources/
    ReaderCoreModels/
    ReaderCoreProtocols/
      PlatformAdapterProtocols.swift
    ReaderCoreNetwork/
    ReaderCoreParser/
    ReaderCoreCache/
    ReaderPlatformAdapters/
  Tests/

Adapters/
  HTTP/
  Storage/
  Scheduler/

Platforms/
  iOS/
  Android/
  Windows/

docs/
  architecture/
```

## Adapter Protocols

```swift
public protocol HTTPAdapterProtocol: HTTPClient {}

public protocol StorageAdapterProtocol: Sendable {
    func read(key: String) async throws -> Data?
    func write(_ data: Data, key: String) async throws
    func remove(key: String) async throws
}

public protocol SchedulerAdapterProtocol: Sendable {
    func schedule(taskId: String, executeAfter interval: TimeInterval) async throws
    func cancel(taskId: String) async throws
}

public protocol LoggingAdapterProtocol: Sendable {
    func log(_ level: LogLevel, message: String, metadata: [String: String]) async
}
```

## Dependency Inversion

- Core defines protocols in `ReaderCoreProtocols`
- Adapter implements those protocols outside Core behavior ownership
- Shell owns only startup and wiring
- Dependency direction stays `Shell -> Adapter -> Core`

## Minimal Shell Path

```text
Platform shell entry
  -> build CoreAdapterDependencies
  -> inject HTTP / Storage / Scheduler / Logging adapters
  -> call Core services
  -> return model/result to shell
```

## Guardrails

- no UI implementation
- no platform feature logic
- no new capability
- no policy taxonomy change
