import Foundation
import ReaderUIContract

#if canImport(UIKit)
import UIKit
#endif

public protocol HostBrightnessControlling: Sendable {
    func brightness() async -> Double
    func setBrightness(_ value: Double) async
}

#if canImport(UIKit)
public struct UIScreenBrightnessController: HostBrightnessControlling {
    public init() {}

    public func brightness() async -> Double {
        await MainActor.run { Double(UIScreen.main.brightness) }
    }

    public func setBrightness(_ value: Double) async {
        await MainActor.run { UIScreen.main.brightness = CGFloat(value) }
    }
}
#endif

public struct HostDisplayCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.brightness_set, .brightness_get]
    public let tier: HostCapabilityTier = .realDeviceProof

    private let controller: (any HostBrightnessControlling)?

    public init() {
        self.controller = Self.defaultController()
    }

    public init(controller: (any HostBrightnessControlling)?) {
        self.controller = controller
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .brightness_set:
            guard let value = Self.number(request.payload["value"]?.value) else {
                return .failure(.invalidParams("brightness.set requires numeric `value`"))
            }
            guard (0.0...1.0).contains(value) else {
                return .failure(.invalidParams("brightness.set `value` must be in 0...1"))
            }
            guard let controller else {
                return .failure(.notImplemented(.brightness_set, "UIScreen is unavailable"))
            }
            await controller.setBrightness(value)
            return .success(["brightness": AnyCodable(value)])
        case .brightness_get:
            guard let controller else {
                return .failure(.notImplemented(.brightness_get, "UIScreen is unavailable"))
            }
            return .success(["brightness": AnyCodable(await controller.brightness())])
        default:
            return .failure(.notImplemented(
                request.type,
                "HostDisplayCapability does not handle \(request.type.rawValue)"
            ))
        }
    }

    private static func defaultController() -> (any HostBrightnessControlling)? {
        #if canImport(UIKit)
        return UIScreenBrightnessController()
        #else
        return nil
        #endif
    }

    private static func number(_ raw: (any Sendable)?) -> Double? {
        switch raw {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as Float: return Double(value)
        case let value as NSNumber: return value.doubleValue
        default: return nil
        }
    }
}
