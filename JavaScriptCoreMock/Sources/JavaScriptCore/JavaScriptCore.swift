import Foundation
public class JSContext { public init() {}; public func evaluateScript(_ script: String) -> JSValue? { return nil }; public func setObject(_ object: Any!, forKeyedSubscript key: (NSCopying & NSObjectProtocol)!) {}; public var exceptionHandler: ((JSContext?, JSValue?) -> Void)? }
public class JSValue { public func toBool() -> Bool { return false }; public func toDouble() -> Double { return 0 }; public func toString() -> String { return "" }; public func isUndefined() -> Bool { return false }; public func isNull() -> Bool { return false }; public func isString() -> Bool { return false }; public func isNumber() -> Bool { return false }; public func isBoolean() -> Bool { return false }; public func isObject() -> Bool { return false }; public func isArray() -> Bool { return false } }
public protocol JSExport {}
public class JSVirtualMachine { public init() {} }
extension JSContext { public convenience init?(virtualMachine: JSVirtualMachine) { self.init() } }
