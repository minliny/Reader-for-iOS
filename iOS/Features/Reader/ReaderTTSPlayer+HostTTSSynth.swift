import Foundation
import ReaderShellValidation

/// Extension to bridge the existing `ReaderTTSPlayer` (Features/Reader) to
/// the `HostTTSSynth` protocol from CoreBridge.
///
/// `ReaderTTSPlayer` already implements `speak(_:)` / `pause()` / `resume()`
/// / `stop()` with matching signatures — this extension just declares
/// conformance so the HostAdapter TTS provider can return it.
///
/// The extension is in the ReaderApp target (compiled into the app), not in
/// CoreBridge, because CoreBridge must not depend on the Features/Reader
/// module.
@MainActor
extension ReaderTTSPlayer: HostTTSSynth {}
