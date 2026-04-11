// ReaderCoreJSRenderer/JSParserEngineFactory.swift
// Production factory that wires JSRuntimeDOMBridge into NonJSParserEngine.
//
// WHY THIS FILE EXISTS:
//   NonJSParserEngine (ReaderCoreParser module) accepts a JSRenderingGate
//   via its initialiser but cannot reference JSRuntimeDOMBridge directly because
//   ReaderCoreParser must not import ReaderCoreJSRenderer.
//   This factory lives in ReaderCoreJSRenderer and can see both, so it performs
//   the wiring and exposes a single production entry-point.
//
// USAGE (app layer or integration test):
//   let parser = JSParserEngineFactory.makeJSCapableParser()
//   let results = try parser.parseSearchResponse(data, source: source, query: query)

import Foundation
import ReaderCoreProtocols
import ReaderCoreParser

public enum JSParserEngineFactory {

    /// Creates a `NonJSParserEngine` wired with a live `JSRuntimeDOMBridge`.
    ///
    /// - Parameters:
    ///   - scheduler:            Rule scheduler. Defaults to `NonJSRuleScheduler()`.
    ///   - timeoutMilliseconds:  Maximum time given to JS execution per call (100–5000 ms).
    ///                           Defaults to 1500 ms.
    /// - Returns: A parser that preprocesses `@js:<code>|<rule>` rule strings by running
    ///            the JS snippet through the DOM polyfill before applying the remaining CSS rule.
    public static func makeJSCapableParser(
        scheduler: RuleScheduler = NonJSRuleScheduler(),
        timeoutMilliseconds: Int = 1500
    ) -> NonJSParserEngine {
        let bridge = JSRuntimeDOMBridge(timeoutMilliseconds: timeoutMilliseconds)
        return NonJSParserEngine(scheduler: scheduler, jsGate: bridge)
    }
}
