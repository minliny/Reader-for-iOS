import CoreFoundation
import Foundation
import ReaderUIContract
import ReaderUIRuntime

/// Lossless conversion and strict typed-result projection at the native Host
/// boundary. No object/array is stringified and no unknown Core/Host result
/// field is allowed to escape into a Reader-UI callback.
enum ReaderUIJSONBridge {
    static func payload(from payload: [String: AnyCodable]) throws -> ReaderUIJSONPayload {
        try payload.reduce(into: [:]) { result, pair in
            result[pair.key] = try value(from: pair.value.value, path: "payload.\(pair.key)")
        }.readerUIValidated()
    }

    static func result(from object: [String: Any]) throws -> ReaderUIJSONResult {
        try object.reduce(into: [:]) { result, pair in
            result[pair.key] = try value(from: pair.value, path: "result.\(pair.key)")
        }.readerUIValidated()
    }

    static func foundationObject(from payload: ReaderUIJSONPayload) -> [String: Any] {
        payload.mapValues(foundationValue)
    }

    /// Projects a raw Core/Host result through the generated result schema and
    /// invokes the canonical validator before returning it to a runtime state
    /// transition. `oneOf` results are tried independently and must produce one
    /// valid projected candidate.
    static func projectTypedResult(
        event: String,
        effectType: String,
        rawResult: ReaderUIJSONResult
    ) throws -> ReaderUIJSONResult {
        guard let contract = GeneratedRuntimeTypedPayloadContracts.byEvent[event],
              let resultContract = contract.resultSchemas[effectType] else {
            throw ReaderUIRuntimeFailure(
                code: "UNDECLARED_TYPED_RESULT",
                message: "\(event) does not declare a result for \(effectType)"
            )
        }
        let raw = try rawResult.readerUIValidated()
        let candidates = projectedValues(value: .object(raw), schema: resultContract.schema)
        var accepted: [ReaderUIJSONResult] = []
        var lastFailure: Error?
        for candidate in candidates {
            guard case .object(let object) = candidate else { continue }
            do {
                _ = try validateReaderUITypedResult(
                    event: event,
                    effectType: effectType,
                    result: object
                )
                if !accepted.contains(object) { accepted.append(object) }
            } catch {
                lastFailure = error
            }
        }
        guard accepted.count == 1, let result = accepted.first else {
            if let lastFailure { throw lastFailure }
            throw ReaderUIRuntimeFailure(
                code: "INVALID_TYPED_RESULT",
                message: "\(event)/\(effectType) did not produce exactly one canonical result"
            )
        }
        return result
    }

    // MARK: - Conversion

    private static func value(from raw: Any, path: String) throws -> ReaderUIJSONValue {
        if raw is NSNull { return .null }
        if let value = raw as? ReaderUIJSONValue { return try value.validated(path: path) }
        if let value = raw as? AnyCodable { return try self.value(from: value.value, path: path) }
        if let value = raw as? Bool { return .bool(value) }
        if let value = raw as? String { return .string(value) }
        if let value = raw as? Int { return .number(Double(value)) }
        if let value = raw as? Int64 { return .number(Double(value)) }
        if let value = raw as? UInt { return .number(Double(value)) }
        if let value = raw as? UInt64 { return .number(Double(value)) }
        if let value = raw as? Double {
            guard value.isFinite else { throw invalid(path, "must be finite") }
            return .number(value)
        }
        if let value = raw as? Float {
            guard value.isFinite else { throw invalid(path, "must be finite") }
            return .number(Double(value))
        }
        if let value = raw as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
            let number = value.doubleValue
            guard number.isFinite else { throw invalid(path, "must be finite") }
            return .number(number)
        }
        if let values = raw as? [AnyCodable] {
            return .array(try values.enumerated().map { index, item in
                try value(from: item.value, path: "\(path)[\(index)]")
            })
        }
        if let values = raw as? [Any] {
            return .array(try values.enumerated().map { index, item in
                try value(from: item, path: "\(path)[\(index)]")
            })
        }
        if let object = raw as? [String: AnyCodable] {
            return .object(try object.reduce(into: [:]) { result, pair in
                result[pair.key] = try value(from: pair.value.value, path: "\(path).\(pair.key)")
            })
        }
        if let object = raw as? [String: Any] {
            return .object(try object.reduce(into: [:]) { result, pair in
                result[pair.key] = try value(from: pair.value, path: "\(path).\(pair.key)")
            })
        }
        if let optional = raw as? String? {
            return optional.map(ReaderUIJSONValue.string) ?? .null
        }
        throw invalid(path, "contains unsupported value \(String(describing: type(of: raw)))")
    }

    private static func foundationValue(_ value: ReaderUIJSONValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let values): return values.map(foundationValue)
        case .object(let object): return object.mapValues(foundationValue)
        }
    }

    private static func invalid(_ path: String, _ message: String) -> ReaderUIRuntimeFailure {
        ReaderUIRuntimeFailure(code: "INVALID_JSON_PAYLOAD", message: "\(path) \(message)")
    }

    // MARK: - Schema projection

    private static func projectedValues(
        value: ReaderUIJSONValue,
        schema: ReaderUIJSONValue
    ) -> [ReaderUIJSONValue] {
        guard case .object(let schemaObject) = schema else { return [value] }
        if case .array(let branches)? = schemaObject["oneOf"] {
            return selectedOneOfBranches(value: value, branches: branches).flatMap {
                projectedValues(value: value, schema: $0)
            }
        }
        guard let type = schemaObject["type"]?.stringValue else { return [value] }
        switch (type, value) {
        case ("object", .object(let object)):
            let properties: ReaderUIJSONPayload
            if case .object(let values)? = schemaObject["properties"] { properties = values }
            else { properties = [:] }
            var candidates: [ReaderUIJSONPayload] = [[:]]
            for key in object.keys.sorted() {
                let childSchemas: [ReaderUIJSONValue]
                if let child = properties[key] {
                    childSchemas = projectedValues(value: object[key]!, schema: child)
                } else if schemaObject["additionalProperties"]?.boolValue == false {
                    continue
                } else if case .object? = schemaObject["additionalProperties"],
                          let child = schemaObject["additionalProperties"] {
                    childSchemas = projectedValues(value: object[key]!, schema: child)
                } else {
                    childSchemas = [object[key]!]
                }
                var next: [ReaderUIJSONPayload] = []
                for candidate in candidates {
                    for child in childSchemas {
                        var copy = candidate
                        copy[key] = child
                        next.append(copy)
                    }
                }
                candidates = next
            }
            return candidates.map(ReaderUIJSONValue.object)
        case ("array", .array(let array)):
            guard let itemSchema = schemaObject["items"] else { return [value] }
            var candidates: [[ReaderUIJSONValue]] = [[]]
            for item in array {
                let children = projectedValues(value: item, schema: itemSchema)
                candidates = candidates.flatMap { prefix in
                    children.map { prefix + [$0] }
                }
            }
            return candidates.map(ReaderUIJSONValue.array)
        default:
            return [value]
        }
    }

    private static func selectedOneOfBranches(
        value: ReaderUIJSONValue,
        branches: [ReaderUIJSONValue]
    ) -> [ReaderUIJSONValue] {
        guard case .object(let object) = value else { return branches }
        let scored: [(ReaderUIJSONValue, Int)] = branches.compactMap { branch in
            guard case .object(let schema) = branch else { return (branch, 0) }
            let required: [String]
            if case .array(let values)? = schema["required"] {
                required = values.compactMap(\.stringValue)
            } else {
                required = []
            }
            guard required.allSatisfy({ object[$0] != nil }) else { return nil }
            let properties: ReaderUIJSONPayload
            if case .object(let values)? = schema["properties"] { properties = values }
            else { properties = [:] }
            for (key, propertySchema) in properties {
                guard let raw = object[key],
                      case .object(let property) = propertySchema,
                      let constant = property["const"] else { continue }
                guard raw == constant else { return nil }
            }
            return (branch, object.keys.filter { properties[$0] != nil }.count)
        }
        guard let maximum = scored.map(\.1).max() else { return branches }
        return scored.filter { $0.1 == maximum }.map(\.0)
    }
}
