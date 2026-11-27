# iOS Review Rules

This repository is a SwiftUI Host thin shell over `Reader-Core` via the C ABI and Swift wrapper.

- Keep all business state, parsing, storage, and synchronization rules in `Reader-Core`; never duplicate Core state machines or persistence in Swift.
- Verify that generated protocol DTOs, C ABI bindings, and theme tokens match their authoritative sources in `Reader-Core` and `Reader-UI`.
- Distinguish pure Swift/unit checks from Simulator UI/XCTest evidence and physical-device runs; skipped (`XCTSkip`) or unexecuted layers remain `NOT_RUN` / `OPEN`.
- Never commit private signing materials, provisioning profiles, or personal test artifacts.
- Do not merge or publish without explicit authorization and verified evidence.
