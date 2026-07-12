import Foundation
import ReaderUIContract

#if canImport(CoreText)
import CoreText
#endif

/// Registers an imported font for the current process. The handler consumes a
/// concrete file URL produced by `file.select`; it never copies or invents font
/// data, and CoreText remains the validation authority.
public struct HostFontCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.font_registerFile, .font_unregisterFile]
    public let tier: HostCapabilityTier = .simulatorProof

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard supportedTypes.contains(request.type) else {
            return .failure(.notImplemented(
                request.type,
                "HostFontCapability does not handle \(request.type.rawValue)"
            ))
        }
        guard let path = request.payload["path"]?.value as? String, !path.isEmpty else {
            return .failure(.invalidParams("\(request.type.rawValue) requires non-empty `path`"))
        }
        let url = Self.fileURL(from: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            if request.type == .font_unregisterFile {
                return .success([
                    "logicalUnregistered": AnyCodable(true),
                    "physicallyUnregistered": AnyCodable(false),
                    "restartRequired": AnyCodable(true),
                ])
            }
            return .failure(.invalidParams("\(request.type.rawValue) file does not exist at \(url.path)"))
        }
        let allowedExtensions = Set(["ttf", "otf", "ttc"])
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            return .failure(.invalidParams("\(request.type.rawValue) supports .ttf/.otf/.ttc files"))
        }

        #if canImport(CoreText)
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        if request.type == .font_unregisterFile {
            var unmanagedError: Unmanaged<CFError>?
            let physicallyUnregistered = CTFontManagerUnregisterFontsForURL(
                url as CFURL,
                .process,
                &unmanagedError
            )
            _ = unmanagedError?.takeRetainedValue()
            return .success([
                "logicalUnregistered": AnyCodable(true),
                "physicallyUnregistered": AnyCodable(physicallyUnregistered),
                "restartRequired": AnyCodable(!physicallyUnregistered),
            ])
        }

        var unmanagedError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            &unmanagedError
        )
        let error = unmanagedError?.takeRetainedValue()
        if !registered {
            let nsError = error as Error? as NSError?
            if nsError?.domain != kCTFontManagerErrorDomain as String ||
                nsError?.code != CTFontManagerError.alreadyRegistered.rawValue {
                return .failure(.underlying(
                    "font.registerFile failed: \(nsError?.localizedDescription ?? "unknown CoreText error")"
                ))
            }
        }
        let discoveredNames = Self.postScriptNames(at: url)
        guard let familyName = Self.familyNames(at: url).first ?? discoveredNames.first, !familyName.isEmpty else {
            // Registration already mutated CoreText. Compensate before
            // reporting an identity-resolution failure so the next W4
            // transaction does not inherit an untracked physical font.
            var cleanupError: Unmanaged<CFError>?
            _ = CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &cleanupError)
            _ = cleanupError?.takeRetainedValue()
            return .failure(.underlying("font.registerFile could not resolve the registered font family"))
        }
        let names = discoveredNames.isEmpty ? [familyName] : discoveredNames
        return .success([
            "registered": AnyCodable(true),
            "path": AnyCodable(url.absoluteString),
            "familyName": AnyCodable(familyName),
            "fontNames": AnyCodable(names.map(AnyCodable.init)),
        ])
        #else
        return .failure(.notImplemented(.font_registerFile, "CoreText is unavailable"))
        #endif
    }

    private static func fileURL(from path: String) -> URL {
        if let url = URL(string: path), url.isFileURL { return url }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    #if canImport(CoreText)
    private static func postScriptNames(at url: URL) -> [String] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else {
            return []
        }
        return descriptors.compactMap { descriptor in
            CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
        }
    }

    private static func familyNames(at url: URL) -> [String] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else {
            return []
        }
        return descriptors.compactMap { descriptor in
            CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
        }
    }
    #endif
}
