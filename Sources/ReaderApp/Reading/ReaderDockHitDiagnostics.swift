#if DEBUG
import SwiftUI
import UIKit
import OSLog

/// Passive, reader-scoped diagnostics. Never changes a control, an existing
/// recognizer, an accessibility action, or the result of a native hit test.
@MainActor
final class ReaderDockHitDiagnostics: ObservableObject {
    struct Input {
        let module: String
        let progress: CGFloat
        let endpointInput: Bool
    }
    private static let logger = Logger(subsystem: "io.reader.minliny", category: "reader-gestures")
    private weak var window: UIWindow?
    private weak var preview: ReaderDebugPreviewHitView?
    private var previewRole = ""
    private var attachmentID: UUID?
    private var generation = UUID()
    private var observer: ReaderRejectAllTouchObserver?
    private var input = Input(module: "", progress: 0, endpointInput: false)
    private var remainingSamples = 16
    private var remainingAXSamples = 4
    private var querying = false

    func update(_ value: Input) {
        if input.module != value.module { remainingSamples = 16; remainingAXSamples = 4; generation = UUID() }
        input = value
    }
    fileprivate func attach(to incoming: UIWindow?, attachmentID: UUID) {
        guard self.attachmentID != attachmentID || window !== incoming else { return }
        detach(attachmentID: nil)
        self.attachmentID = attachmentID
        window = incoming
        guard let incoming else { return }
        let observer = ReaderRejectAllTouchObserver(owner: self)
        self.observer = observer
        incoming.addGestureRecognizer(observer)
        Self.logger.debug("view event=dock-hit-observer attached=true window=\(String(describing: ObjectIdentifier(incoming)), privacy: .public)")
    }
    fileprivate func detach(attachmentID: UUID? = nil) {
        if let attachmentID, self.attachmentID != attachmentID { return }
        generation = UUID()
        if let observer {
            observer.isEnabled = false
            observer.view?.removeGestureRecognizer(observer)
            Self.logger.debug("view event=dock-hit-observer attached=false")
        }
        observer = nil; window = nil; self.attachmentID = nil
    }
    fileprivate func register(_ view: ReaderDebugPreviewHitView) {
        if preview !== view || previewRole != view.role {
            generation = UUID(); remainingSamples = 16; remainingAXSamples = 4
            Self.logger.debug("view event=dock-hit-probe role=\(view.role, privacy: .public) registered=true")
        }
        preview = view
        previewRole = view.role
    }
    fileprivate func unregister(_ view: ReaderDebugPreviewHitView) {
        if preview === view { preview = nil; previewRole = ""; generation = UUID() }
    }
    fileprivate func observed(_ touch: UITouch, by observer: UIGestureRecognizer) {
        guard observer === self.observer, let window, observer.view === window,
              touch.window === window, window.windowScene?.activationState == .foregroundActive,
              input.module == "rules", remainingSamples > 0 else { return }
        remainingSamples -= 1
        let point = touch.location(in: window)
        let facts = "module=\(input.module) p=\(input.progress) endpointInput=\(input.endpointInput) phase=\(touch.phase.rawValue) timestamp=\(touch.timestamp) point=\(point) window=\(ObjectIdentifier(window)) target=\(Self.chain(from: touch.view, in: window))"
        Self.logger.debug("view event=dock-native-touch \(facts, privacy: .public)")
        // The delegate rejects this touch before returning. Query after native
        // event dispatch, with no retained UITouch/UIEvent and no replayed tap.
        let expected = generation
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window, self.generation == expected,
                  window.windowScene?.activationState == .foregroundActive,
                  self.input.module == "rules", self.input.endpointInput else { return }
            self.samplePreview(in: window)
        }
    }
    private func samplePreview(in window: UIWindow) {
        guard !querying, let preview, preview.window === window, preview.bounds.width > 0,
              preview.bounds.height > 0 else { return }
        let rect = preview.convert(preview.bounds, to: window)
        guard rect.minX.isFinite, rect.minY.isFinite, rect.width.isFinite, rect.height.isFinite else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let ancestors = Self.chain(from: preview.superview, in: window)
        guard window.bounds.contains(center) else {
            Self.logger.debug("view event=dock-preview-geometry role=\(preview.role, privacy: .public) rect=\(String(describing: rect), privacy: .public) inWindow=false ancestors=\(ancestors, privacy: .public)")
            return
        }
        querying = true
        defer { querying = false }
        // Public geometry query only. This does not create an event, activate
        // the preview action, or establish XCTest/AX hittability.
        let candidate = window.hitTest(center, with: nil)
        let facts = "role=\(preview.role) rect=\(rect) center=\(center) query=window.hitTest(nil-event) candidate=\(Self.chain(from: candidate, in: window)) ancestors=\(ancestors)"
        Self.logger.debug("view event=dock-preview-geometry \(facts, privacy: .public)")
        sampleAccessibility(for: preview, layout: rect, in: window)
    }

    /// Public AX getters only. A logical SwiftUI element need not be a UIView;
    /// the automation/container trees may also differ from the native view tree.
    private func sampleAccessibility(for preview: ReaderDebugPreviewHitView, layout: CGRect, in window: UIWindow) {
        guard remainingAXSamples > 0 else { return }
        let targets: [String: String]
        switch preview.role {
        case "replacement-preview": targets = ["预览已保存规则": "preview", "校验草稿": "validation"]
        case "txt-preview": targets = ["预览当前草稿": "preview", "校验草稿": "validation"]
        default: return
        }
        var ancestor = preview.superview
        var scroll: UIScrollView?
        for _ in 0..<12 {
            guard let current = ancestor else { break }
            if let current = current as? UIScrollView { scroll = current; break }
            ancestor = current.superview
        }
        guard let scroll, scroll.window === window else { return }
        let scrollRect = scroll.convert(scroll.bounds, to: window)
        guard scrollRect.contains(CGPoint(x: layout.midX, y: layout.midY)) else { return }
        remainingAXSamples -= 1
        let expected = generation
        let screenSpace = window.screen.coordinateSpace
        let layoutScreen = screenSpace.convert(layout, from: window)
        let maximumNodes = 192, maximumDepth = 10, maximumChildren = 32, maximumMatches = 6
        struct Node { let element: NSObject; let depth: Int; let route: String }
        var queue = [Node(element: scroll, depth: 0, route: "root")]
        var seen: Set<ObjectIdentifier> = [ObjectIdentifier(scroll)]
        var index = 0, matches = 0
        var truncated = false
        func enqueue(_ value: Any, depth: Int, route: String) {
            guard let element = value as? NSObject else { return }
            let identity = ObjectIdentifier(element)
            guard !seen.contains(identity) else { return }
            guard depth <= maximumDepth, queue.count < maximumNodes else { truncated = true; return }
            seen.insert(identity); queue.append(Node(element: element, depth: depth, route: route))
        }
        while index < queue.count, index < maximumNodes, matches < maximumMatches {
            guard self.window === window, self.preview === preview, generation == expected,
                  window.windowScene?.activationState == .foregroundActive else { return }
            let entry = queue[index]; index += 1
            let node = entry.element
            // Read labels only for an exact comparison. No unowned label,
            // identifier, value, hint, draft, or chapter text enters the log.
            if let label = node.accessibilityLabel, let kind = targets[label] {
                matches += 1
                let frameScreen = node.accessibilityFrame
                let pointScreen = node.accessibilityActivationPoint
                let finiteFrame = frameScreen.minX.isFinite && frameScreen.minY.isFinite &&
                    frameScreen.width.isFinite && frameScreen.height.isFinite
                let finitePoint = pointScreen.x.isFinite && pointScreen.y.isFinite
                let frameWindow = finiteFrame ? window.convert(frameScreen, from: screenSpace) : .null
                let pointWindow = finitePoint ? window.convert(pointScreen, from: screenSpace) : CGPoint(x: CGFloat.nan, y: CGFloat.nan)
                let finite = finiteFrame && finitePoint && pointWindow.x.isFinite && pointWindow.y.isFinite
                let inWindow = finite && window.bounds.contains(pointWindow)
                let inScroll = finite && scrollRect.contains(pointWindow)
                // querying is already held by samplePreview. This nil-event
                // lookup dispatches no touch and invokes no accessibility action.
                let candidate = inWindow ? window.hitTest(pointWindow, with: nil) : nil
                let containerFrame = (node as? UIAccessibilityElement).map { String(describing: $0.accessibilityFrameInContainerSpace) } ?? "unavailable"
                let facts = "role=\(preview.role) kind=\(kind) route=\(entry.route) depth=\(entry.depth) frameScreen=\(frameScreen) pointScreen=\(pointScreen) frameWindow=\(frameWindow) pointWindow=\(pointWindow) layoutWindow=\(layout) layoutScreen=\(layoutScreen) layoutRoundTrip=\(window.convert(layoutScreen, from: screenSpace)) pathBoundsScreen=\(String(describing: node.accessibilityPath?.bounds)) frameInContainer=\(containerFrame) traits=\(node.accessibilityTraits.rawValue) isElement=\(node.isAccessibilityElement) hiddenChildren=\(node.accessibilityElementsHidden) modal=\(node.accessibilityViewIsModal) containerType=\(node.accessibilityContainerType.rawValue) finite=\(finite) pointInWindow=\(inWindow) pointInScroll=\(inScroll)"
                Self.logger.debug("view event=dock-preview-ax \(facts, privacy: .public)")
                Self.logger.debug("view event=dock-preview-ax-hit role=\(preview.role, privacy: .public) kind=\(kind, privacy: .public) query=window.hitTest(nil-event) candidate=\(Self.chain(from: candidate, in: window), privacy: .public)")
                Self.logger.debug("view event=dock-preview-ax-ancestors role=\(preview.role, privacy: .public) kind=\(kind, privacy: .public) entries=\(Self.accessibilityChain(from: node), privacy: .public)")
            }
            let count = node.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                if count > maximumChildren { truncated = true }
                for child in 0..<min(count, maximumChildren) {
                    if let value = node.accessibilityElement(at: child) { enqueue(value, depth: entry.depth + 1, route: "dynamic") }
                }
            }
            if let values = node.accessibilityElements {
                if values.count > maximumChildren { truncated = true }
                for value in values.prefix(maximumChildren) { enqueue(value, depth: entry.depth + 1, route: "elements") }
            }
            if #available(iOS 17.0, *), let values = node.automationElements {
                if values.count > maximumChildren { truncated = true }
                for value in values.prefix(maximumChildren) { enqueue(value, depth: entry.depth + 1, route: "automation") }
            }
            if let view = node as? UIView {
                if view.subviews.count > maximumChildren { truncated = true }
                for value in view.subviews.prefix(maximumChildren) { enqueue(value, depth: entry.depth + 1, route: "subviews") }
            }
        }
        if index < queue.count { truncated = true }
        Self.logger.debug("view event=dock-preview-ax-scan role=\(preview.role, privacy: .public) visited=\(index) enqueued=\(queue.count) matches=\(matches) truncated=\(truncated) maxNodes=192 maxDepth=10 maxChildren=32 maxMatches=6 remainingScans=\(self.remainingAXSamples)")
    }

    private static func accessibilityChain(from first: NSObject) -> String {
        var current: NSObject? = first
        var seen = Set<ObjectIdentifier>()
        var entries: [String] = []
        while let node = current, entries.count < 8, seen.insert(ObjectIdentifier(node)).inserted {
            let type = String(String(reflecting: Swift.type(of: node)).prefix(64))
            entries.append("\(type)#\(ObjectIdentifier(node)){element=\(node.isAccessibilityElement),hiddenChildren=\(node.accessibilityElementsHidden),modal=\(node.accessibilityViewIsModal),containerType=\(node.accessibilityContainerType.rawValue)}")
            if let element = node as? UIAccessibilityElement { current = element.accessibilityContainer as? NSObject }
            else { current = (node as? UIView)?.superview }
        }
        return entries.joined(separator: " <- ")
    }
    private static func chain(from first: UIView?, in window: UIWindow) -> String {
        var result: [String] = []
        var current = first
        while let view = current, result.count < 8 {
            let type = String(String(reflecting: Swift.type(of: view)).prefix(64))
            var entry = "\(type)#\(ObjectIdentifier(view)){rect=\(view.convert(view.bounds, to: window)),hidden=\(view.isHidden),alpha=\(view.alpha),interaction=\(view.isUserInteractionEnabled),clips=\(view.clipsToBounds)"
            if let scroll = view as? UIScrollView {
                entry += ",scrollOffset=\(scroll.contentOffset),scrollBounds=\(scroll.bounds),insets=\(scroll.adjustedContentInset),scrollEnabled=\(scroll.isScrollEnabled),dragging=\(scroll.isDragging),decelerating=\(scroll.isDecelerating)"
            }
            if let control = view as? UIControl { entry += ",enabled=\(control.isEnabled)" }
            result.append(entry + "}")
            if view === window { break }
            current = view.superview
        }
        return result.isEmpty ? "nil" : result.joined(separator: " <- ")
    }
}

/// Always rejects input, even if its reader owner has already retired. There
/// are no target/actions, failure dependencies, or changes to other delegates.
private final class ReaderRejectAllTouchObserver: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private weak var owner: ReaderDockHitDiagnostics?
    init(owner: ReaderDockHitDiagnostics) {
        self.owner = owner
        super.init(target: nil, action: nil)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        owner?.observed(touch, by: self)
        return false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool { false }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

struct ReaderDockHitDiagnosticsAttachment: UIViewRepresentable {
    let owner: ReaderDockHitDiagnostics
    let input: ReaderDockHitDiagnostics.Input
    func makeUIView(context: Context) -> ReaderDockHitAttachmentView {
        let view = ReaderDockHitAttachmentView()
        view.owner = owner; owner.update(input)
        return view
    }
    func updateUIView(_ view: ReaderDockHitAttachmentView, context: Context) {
        view.owner = owner; owner.update(input); view.updateAttachment()
    }
    static func dismantleUIView(_ view: ReaderDockHitAttachmentView, coordinator: ()) { view.retire() }
}

final class ReaderDockHitAttachmentView: UIView {
    weak var owner: ReaderDockHitDiagnostics?
    private let attachmentID = UUID()
    private var retired = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false; isAccessibilityElement = false; accessibilityElementsHidden = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); updateAttachment() }
    func updateAttachment() {
        guard !retired else { return }
        owner?.attach(to: window, attachmentID: attachmentID)
    }
    func retire() { retired = true; owner?.detach(attachmentID: attachmentID) }
}

private struct ReaderDockHitDiagnosticsKey: EnvironmentKey {
    static let defaultValue: ReaderDockHitDiagnostics? = nil
}
extension EnvironmentValues {
    var readerDockHitDiagnostics: ReaderDockHitDiagnostics? {
        get { self[ReaderDockHitDiagnosticsKey.self] }
        set { self[ReaderDockHitDiagnosticsKey.self] = newValue }
    }
}

/// A noninteractive native background measuring the existing Button layout.
/// No query occurs on layout; only a bounded real-touch observation samples it.
struct ReaderDebugPreviewHitProbe: UIViewRepresentable {
    let role: String
    @Environment(\.readerDockHitDiagnostics) private var owner
    init(role: String) { self.role = role }
    func makeUIView(context: Context) -> ReaderDebugPreviewHitView {
        let view = ReaderDebugPreviewHitView()
        view.owner = owner; view.role = role; owner?.register(view)
        return view
    }
    func updateUIView(_ view: ReaderDebugPreviewHitView, context: Context) {
        view.owner = owner; view.role = role; owner?.register(view)
    }
    static func dismantleUIView(_ view: ReaderDebugPreviewHitView, coordinator: ()) { view.owner?.unregister(view) }
}

final class ReaderDebugPreviewHitView: UIView {
    weak var owner: ReaderDockHitDiagnostics?
    var role = ""
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false; isAccessibilityElement = false; accessibilityElementsHidden = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
#endif
