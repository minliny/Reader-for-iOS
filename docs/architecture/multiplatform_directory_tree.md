# Multiplatform Directory Tree

```text
shared/
  specs/
  contracts/
  test-fixtures/
core/
  models/
  protocols/
  parser/
  network/
  cache/
  cookie/
  error_mapping/
platform_adapters/
  apple/
  linux/
  windows/
  android/
  harmonyos/
shells/
  ios/
  macos/
  windows/
  android/
  harmonyos/
samples/
  booksources/
  metadata/
  fixtures/
  expected/
  matrix/
reports/
  latest/
docs/
  architecture/
  AI_HANDOFF/
```

Shared assets: `shared/`, `core/`, `samples/`, `reports/`, `docs/`.

Platform-specific assets: `platform_adapters/*`, `shells/*`.

This directory tree is a recommended rollout target, not a claim that every directory already exists or that any platform UI has been implemented.
