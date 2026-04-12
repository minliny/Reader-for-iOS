# Adapters Skeleton

This directory is reserved for platform-facing adapter implementations.

- `HTTP/`: transport bridge implementations
- `Storage/`: persistence bridge implementations
- `Scheduler/`: timer/background scheduling bridge implementations

Constraints:
- no Core compatibility semantics
- no UI
- no parser behavior
- no failure taxonomy ownership
