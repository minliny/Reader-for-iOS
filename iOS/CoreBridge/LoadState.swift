import Foundation
import ReaderCoreModels

public enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(AppReaderError)
    case unsupported(String)
    case partial(Value, warning: String)
}

extension LoadState {
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var value: Value? {
        switch self {
        case .loaded(let v), .partial(let v, _):
            return v
        default:
            return nil
        }
    }

    public var error: AppReaderError? {
        if case .failed(let e) = self { return e }
        return nil
    }

    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    public var isUnsupported: Bool {
        if case .unsupported = self { return true }
        return false
    }

    public var isPartial: Bool {
        if case .partial = self { return true }
        return false
    }

    public var warningMessage: String? {
        if case .partial(_, let warning) = self { return warning }
        return nil
    }
}