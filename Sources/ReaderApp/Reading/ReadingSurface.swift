/// The coordinator submits canonical chapter positions and receives measured
/// scalar positions. The renderer owns its native layout until retirement.
@MainActor
protocol ReadingSurface {
    associatedtype Document

    func open(_ document: Document, session: String, anchor: Int, style: EbookStyle) async throws -> EbookScriptEvent.Value
    func reflow(style: EbookStyle, anchor: Int?) async throws -> EbookScriptEvent.Value
    func select(start: Int, end: Int) async throws -> EbookScriptEvent.Value?
    func selection() async throws -> EbookScriptEvent.Value?
    func position() async throws -> EbookScriptEvent.Value?
    func restore(_ scalar: Int) async throws -> EbookScriptEvent.Value?
    func retire() async
}
