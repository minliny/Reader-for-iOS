import Foundation
import ReaderUIContract

/// Reader-UI HostRequest/HostResult wire boundary.
///
/// Capability implementations may keep private compatibility aliases while
/// they migrate, but every successful value leaving `HostCapabilityRegistry`
/// is projected to the canonical HostResult shape. Missing required result
/// fields fail closed instead of producing a schema-invalid success.
public enum HostCanonicalContract {
    private struct Shape {
        let allowed: Set<String>
        let required: Set<String>

        init(_ allowed: [String], required: [String] = []) {
            self.allowed = Set(allowed)
            self.required = Set(required)
        }
    }

    /// Exact canonical type set. Keep this exhaustive so a newly generated
    /// `HostRequestType` cannot silently bypass request/result validation.
    public static let typeNames: Set<String> = Set(requestShapes.keys.map(\.rawValue))

    public static func validateRequest(_ request: HostRequest) -> HostCapabilityError? {
        guard let shape = requestShapes[request.type] else {
            return .invalidParams("unsupported canonical HostRequest type: \(request.type.rawValue)")
        }
        let keys = Set(request.payload.keys)
        let unknown = keys.subtracting(shape.allowed)
        guard unknown.isEmpty else {
            return .invalidParams(
                "\(request.type.rawValue) contains non-canonical payload fields: \(unknown.sorted())"
            )
        }
        let missing = shape.required.subtracting(keys)
        guard missing.isEmpty else {
            return .invalidParams(
                "\(request.type.rawValue) is missing canonical payload fields: \(missing.sorted())"
            )
        }
        return validateRequestSemantics(request)
    }

    public static func projectResult(
        for type: HostRequestType,
        result: [String: AnyCodable]
    ) -> Result<[String: AnyCodable], HostCapabilityError> {
        guard let shape = resultShapes[type] else {
            return .failure(.underlying("no canonical HostResult shape for \(type.rawValue)"))
        }
        var projected = result.filter { shape.allowed.contains($0.key) }
        projected = projectNestedResult(type: type, result: projected)
        let missing = shape.required.subtracting(projected.keys)
        guard missing.isEmpty else {
            return .failure(.underlying(
                "\(type.rawValue) capability returned schema-invalid success; missing fields: \(missing.sorted())"
            ))
        }
        guard validateResultSemantics(type: type, result: projected) else {
            return .failure(.underlying(
                "\(type.rawValue) capability returned a schema-invalid HostResult"
            ))
        }
        return .success(projected)
    }

    // MARK: - Request shapes (Reader-UI host-request.schema.json 1.2.0)

    private static let requestShapes: [HostRequestType: Shape] = [
        .http_execute: Shape(["url", "method", "headers", "body", "charset", "followRedirects", "maxRedirects"], required: ["url", "method", "headers"]),
        .http_cancel: Shape(["requestId"], required: ["requestId"]),
        .webview_open: Shape(["url", "profileId"], required: ["url"]),
        .webview_close: Shape(["profileId"]),
        .webview_evaluate: Shape(["url", "script", "timeoutMs", "profileId"], required: ["url", "script"]),
        .cookie_get: Shape(["url", "name", "sessionId"], required: ["url"]),
        .cookie_set: Shape(["url", "cookie", "sessionId"], required: ["url", "cookie"]),
        .cookie_clear: Shape(["url", "domain", "sessionId"]),
        .file_read: Shape(["path", "encoding", "byteOffset", "maxBytes"], required: ["path"]),
        .file_write: Shape(["path", "content", "contentBase64", "encoding", "createDirectories", "append"], required: ["path"]),
        .file_delete: Shape(["path"], required: ["path"]),
        .storage_path: Shape(["scope"], required: ["scope"]),
        .persistence_get: Shape(["namespace", "key"], required: ["namespace", "key"]),
        .persistence_put: Shape(["namespace", "key", "value", "expectedRevision"], required: ["namespace", "key", "value", "expectedRevision"]),
        .credential_get: Shape(["key"], required: ["key"]),
        .credential_set: Shape(["key", "value"], required: ["key", "value"]),
        .credential_delete: Shape(["key"], required: ["key"]),
        .tts_system_start: ttsStartShape,
        .tts_system_stop: emptyShape,
        .tts_system_pause: emptyShape,
        .tts_system_resume: emptyShape,
        .permission_request: Shape(["scope"], required: ["scope"]),
        .permission_check: Shape(["scope"], required: ["scope"]),
        .background_schedule: Shape(["taskId", "delayMs"], required: ["taskId"]),
        .background_cancel: Shape(["taskId"], required: ["taskId"]),
        .timer_foreground_arm: foregroundTimerShape,
        .timer_foreground_cancel: foregroundTimerShape,
        .notification_show: Shape(["id", "title", "body"], required: ["id", "title", "body"]),
        .notification_cancel: Shape(["id"], required: ["id"]),
        .share_invoke: Shape(["text", "title", "url", "files"], required: ["text"]),
        .clipboard_copy: Shape(["text"], required: ["text"]),
        .clipboard_paste: emptyShape,
        .device_vibrate: Shape(["durationMs"]),
        .device_screen_keep_on: Shape(["enabled"], required: ["enabled"]),
        .device_screen_release: emptyShape,
        .file_select: Shape(["mimeTypes", "allowsMultiple"]),
        .font_registerFile: Shape(["path", "familyName"], required: ["path", "familyName"]),
        .font_unregisterFile: Shape(["path", "familyName"], required: ["path", "familyName"]),
        .clipboard_read: emptyShape,
        .clipboard_write: Shape(["text"], required: ["text"]),
        .tts_start: ttsStartShape,
        .tts_stop: emptyShape,
        .tts_pause: emptyShape,
        .brightness_set: Shape(["value"], required: ["value"]),
        .brightness_get: emptyShape,
        .screen_keepAwake: emptyShape,
        .screen_allowSleep: emptyShape,
        .haptics_light: emptyShape,
        .haptics_medium: emptyShape,
        .haptics_heavy: emptyShape,
        .network_status: emptyShape,
        .webdav_connect: Shape(["url", "serverURL", "username", "password"]),
        .webdav_backup: Shape(["serverURL", "username", "password"]),
        .webdav_restore: Shape(["remoteURL", "serverURL", "username", "password"], required: ["remoteURL"]),
        .share_text: Shape(["text"], required: ["text"]),
        .share_file: Shape(["path"], required: ["path"]),
        .background_task_start: Shape(["name"], required: ["name"]),
        .background_task_end: Shape(["taskId"], required: ["taskId"]),
    ]

    private static let emptyShape = Shape([])
    private static let ttsStartShape = Shape(
        ["text", "rate", "pitch", "language", "voice", "articleId", "sliceIndex", "correlationId", "generation"],
        required: ["text"]
    )
    private static let foregroundTimerShape = Shape(
        ["timerId", "correlationId", "delayMs", "generation", "oneShot", "foregroundOnly"],
        required: ["timerId", "correlationId", "delayMs", "generation", "oneShot", "foregroundOnly"]
    )

    // MARK: - Result shapes (Reader-UI host-result.schema.json 1.0.0)

    private static let resultShapes: [HostRequestType: Shape] = [
        .http_execute: Shape(["status", "body", "bodyBase64", "headers", "finalUrl", "charsetHint", "cookies"], required: ["status", "body"]),
        .http_cancel: Shape(["cancelled"], required: ["cancelled"]),
        .webview_open: Shape(["opened", "profileId"], required: ["opened"]),
        .webview_close: Shape(["closed"], required: ["closed"]),
        .webview_evaluate: Shape(["result", "finalUrl", "title"], required: ["result"]),
        .cookie_get: Shape(["cookies"], required: ["cookies"]),
        .cookie_set: Shape(["stored"], required: ["stored"]),
        .cookie_clear: Shape(["cleared"], required: ["cleared"]),
        .file_read: Shape(["content", "contentBase64", "encoding", "byteLength"]),
        .file_write: Shape(["written", "byteLength"], required: ["written"]),
        .file_delete: Shape(["deleted"], required: ["deleted"]),
        .storage_path: Shape(["path"], required: ["path"]),
        .persistence_get: Shape(["found", "value", "revision"], required: ["found"]),
        .persistence_put: Shape(["stored", "revision"], required: ["stored", "revision"]),
        .credential_get: Shape(["exists", "value"], required: ["exists"]),
        .credential_set: Shape(["stored"], required: ["stored"]),
        .credential_delete: Shape(["deleted"], required: ["deleted"]),
        .tts_system_start: Shape(["started"], required: ["started"]),
        .tts_system_stop: acknowledgedShape,
        .tts_system_pause: acknowledgedShape,
        .tts_system_resume: acknowledgedShape,
        .permission_request: Shape(["granted"], required: ["granted"]),
        .permission_check: Shape(["granted"], required: ["granted"]),
        .background_schedule: Shape(["scheduled"], required: ["scheduled"]),
        .background_cancel: Shape(["cancelled"], required: ["cancelled"]),
        .timer_foreground_arm: Shape(["armed", "replaced", "timerId", "generation"], required: ["armed"]),
        .timer_foreground_cancel: Shape(["cancelled", "timerId", "generation"], required: ["cancelled"]),
        .notification_show: Shape(["shown", "id"], required: ["shown"]),
        .notification_cancel: Shape(["cancelled"], required: ["cancelled"]),
        .share_invoke: sharedShape,
        .clipboard_copy: Shape(["copied"], required: ["copied"]),
        .clipboard_paste: clipboardTextShape,
        .device_vibrate: Shape(["vibrated"], required: ["vibrated"]),
        .device_screen_keep_on: Shape(["enabled"], required: ["enabled"]),
        .device_screen_release: Shape(["released"], required: ["released"]),
        .file_select: Shape(["selected", "files"], required: ["selected", "files"]),
        .font_registerFile: Shape(["registered", "path", "familyName", "fontNames"], required: ["registered", "path", "familyName", "fontNames"]),
        .font_unregisterFile: Shape(["logicalUnregistered", "physicallyUnregistered", "restartRequired"], required: ["logicalUnregistered", "physicallyUnregistered", "restartRequired"]),
        .clipboard_read: clipboardTextShape,
        .clipboard_write: Shape(["written"], required: ["written"]),
        .tts_start: Shape(["started", "rate", "pitch", "language"], required: ["started"]),
        .tts_stop: Shape(["stopped"], required: ["stopped"]),
        .tts_pause: Shape(["paused"], required: ["paused"]),
        .brightness_set: brightnessShape,
        .brightness_get: brightnessShape,
        .screen_keepAwake: Shape(["applied", "keepAwake"], required: ["applied", "keepAwake"]),
        .screen_allowSleep: Shape(["applied", "keepAwake"], required: ["applied", "keepAwake"]),
        .haptics_light: hapticShape,
        .haptics_medium: hapticShape,
        .haptics_heavy: hapticShape,
        .network_status: Shape(["connected", "status", "interface", "isExpensive", "isConstrained"], required: ["connected", "status", "interface", "isExpensive", "isConstrained"]),
        .webdav_connect: Shape(["connected", "statusCode", "message"], required: ["connected", "statusCode", "message"]),
        .webdav_backup: Shape(["backedUp", "remoteURL", "statusCode", "resourceCount"], required: ["backedUp", "remoteURL", "statusCode", "resourceCount"]),
        .webdav_restore: Shape(["restored", "remoteURL", "statusCode", "applied"], required: ["restored", "remoteURL", "statusCode", "applied"]),
        .share_text: sharedShape,
        .share_file: Shape(["shared", "path"], required: ["shared", "path"]),
        .background_task_start: Shape(["started", "taskId", "name"], required: ["started", "taskId", "name"]),
        .background_task_end: Shape(["ended", "taskId"], required: ["ended", "taskId"]),
    ]

    private static let acknowledgedShape = Shape(["acknowledged"], required: ["acknowledged"])
    private static let sharedShape = Shape(["shared"], required: ["shared"])
    private static let clipboardTextShape = Shape(["text"], required: ["text"])
    private static let brightnessShape = Shape(["brightness"], required: ["brightness"])
    private static let hapticShape = Shape(["performed", "style"], required: ["performed", "style"])

    // MARK: - Semantic validation

    private static func validateRequestSemantics(_ request: HostRequest) -> HostCapabilityError? {
        func string(_ key: String) -> String? { request.payload[key]?.value as? String }
        func nonBlank(_ key: String) -> Bool {
            guard let value = string(key) else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        switch request.type {
        case .file_write:
            let hasText = request.payload["content"]?.value is String
            let hasBase64 = request.payload["contentBase64"]?.value is String
            if hasText == hasBase64 {
                return .invalidParams("file.write requires exactly one of `content` or `contentBase64`")
            }
        case .webdav_connect:
            let credentialKeys = ["serverURL", "username", "password"]
            let count = credentialKeys.filter { request.payload[$0] != nil }.count
            if count != 0 && count != credentialKeys.count && request.payload["url"] == nil {
                return .invalidParams("webdav.connect credentials must be complete")
            }
        case .webdav_backup:
            let keys = ["serverURL", "username", "password"]
            let count = keys.filter { request.payload[$0] != nil }.count
            if count != 0 && count != keys.count {
                return .invalidParams("webdav.backup credentials must be complete")
            }
        case .webdav_restore:
            guard nonBlank("remoteURL") else {
                return .invalidParams("webdav.restore requires non-empty `remoteURL`")
            }
        case .brightness_set:
            guard let value = numeric(request.payload["value"]?.value), (0 ... 1).contains(value) else {
                return .invalidParams("brightness.set `value` must be in 0...1")
            }
        default:
            for key in requestShapes[request.type]?.required ?? [] where key != "headers" {
                if request.payload[key]?.value is String, !nonBlank(key) {
                    return .invalidParams("\(request.type.rawValue) requires non-empty `\(key)`")
                }
            }
        }
        return nil
    }

    private static func projectNestedResult(
        type: HostRequestType,
        result: [String: AnyCodable]
    ) -> [String: AnyCodable] {
        var projected = result
        if type == .cookie_get || type == .http_execute,
           let cookies = dictionaries(result["cookies"]?.value) {
            let allowed = Set(["name", "value", "domain", "path", "secure", "httpOnly"])
            projected["cookies"] = AnyCodable(cookies.map { cookie in
                AnyCodable(cookie.filter { allowed.contains($0.key) })
            })
        }
        if type == .file_select, let files = dictionaries(result["files"]?.value) {
            let allowed = Set(["path", "name", "mimeType", "size"])
            projected["files"] = AnyCodable(files.map { file in
                AnyCodable(file.filter { allowed.contains($0.key) })
            })
        }
        return projected
    }

    private static func validateResultSemantics(
        type: HostRequestType,
        result: [String: AnyCodable]
    ) -> Bool {
        func bool(_ key: String) -> Bool { result[key]?.value is Bool }
        func string(_ key: String) -> Bool { result[key]?.value is String }
        switch type {
        case .file_read:
            return (result["content"]?.value is String) != (result["contentBase64"]?.value is String)
        case .persistence_get:
            guard let found = result["found"]?.value as? Bool else { return false }
            return found ? string("value") && string("revision") : Set(result.keys) == ["found"]
        case .credential_get:
            guard let exists = result["exists"]?.value as? Bool else { return false }
            return exists ? string("value") : Set(result.keys) == ["exists"]
        case .network_status:
            guard let status = result["status"]?.value as? String else { return false }
            return ["online", "limited", "offline"].contains(status)
        case .haptics_light, .haptics_medium, .haptics_heavy:
            guard let style = result["style"]?.value as? String else { return false }
            return ["light", "medium", "heavy"].contains(style) && bool("performed")
        default:
            return true
        }
    }

    private static func dictionaries(_ raw: (any Sendable)?) -> [[String: AnyCodable]]? {
        if let values = raw as? [[String: AnyCodable]] { return values }
        if let values = raw as? [AnyCodable] {
            return values.compactMap { value in
                if let dict = value.value as? [String: AnyCodable] { return dict }
                if let dict = value.value as? [String: Any] {
                    return dict.mapValues(AnyCodable.init)
                }
                return nil
            }
        }
        if let values = raw as? [[String: Any]] {
            return values.map { $0.mapValues(AnyCodable.init) }
        }
        return nil
    }

    private static func numeric(_ raw: (any Sendable)?) -> Double? {
        switch raw {
        case let value as Double: return value
        case let value as Float: return Double(value)
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        default: return nil
        }
    }
}
