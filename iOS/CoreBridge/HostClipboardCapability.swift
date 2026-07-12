// CoreBridge
//
// HostClipboardCapability — UI/reducer-initiated `clipboard.copy/paste`.
//
// Bridges the contract `HostRequest` to the system pasteboard:
// - iOS: `UIPasteboard.general`
// - macOS: `NSPasteboard.general`
//
// Tier: crossPlatform — both UIKit and AppKit expose a string-typed pasteboard
// with the same semantics. The handler is testable on macOS `swift build`.
//
// Payload contract:
// - `.clipboard_copy`:  `{ text: String }` → `{ copied: true }`
// - `.clipboard_paste`: `{}` → `{ text: String? }`

import Foundation
import ReaderUIContract

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct HostClipboardCapability: HostCapabilityHandler {
    /// Reader-UI 2.5 added `clipboard.read/write` as canonical aliases for the
    /// existing `clipboard.paste/copy` pair. Both names intentionally share
    /// this single pasteboard owner so the aliases cannot drift.
    public let supportedTypes: Set<HostRequestType> = [
        .clipboard_copy, .clipboard_paste, .clipboard_read, .clipboard_write,
    ]
    public let tier: HostCapabilityTier = .crossPlatform

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .clipboard_copy, .clipboard_write:
            return handleCopy(request.payload, type: request.type)
        case .clipboard_paste, .clipboard_read:
            return handlePaste(type: request.type)
        default:
            return .failure(.notImplemented(request.type, "HostClipboardCapability does not handle \(request.type.rawValue)"))
        }
    }

    private func handleCopy(
        _ payload: [String: AnyCodable],
        type: HostRequestType
    ) -> HostCapabilityOutcome {
        guard let text = payload["text"]?.value as? String else {
            return .failure(.invalidParams("\(type.rawValue) requires `text` string"))
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        return .failure(.notImplemented(type, "no pasteboard backend on this platform"))
        #endif
        if type == .clipboard_write {
            return .success(["written": AnyCodable(true)])
        }
        return .success(["copied": AnyCodable(true)])
    }

    private func handlePaste(type: HostRequestType) -> HostCapabilityOutcome {
        var text: String?
        #if canImport(UIKit)
        text = UIPasteboard.general.string
        #elseif canImport(AppKit)
        text = NSPasteboard.general.string(forType: .string)
        #else
        return .failure(.notImplemented(type, "no pasteboard backend on this platform"))
        #endif
        if let text = text {
            return .success(["text": AnyCodable(text)])
        }
        return .success(["text": AnyCodable(String?.none as String?)])
    }
}
