import SwiftUI
import UIKit
import Combine
#if DEBUG
import OSLog
#endif

/// The App installs this delegate through UIApplicationDelegateAdaptor. UIKit
/// remains the orientation authority; the reader contributes only its current
/// window's supported mask while that window owns an active reading session.
@MainActor
final class ReaderOrientationDelegate: NSObject, UIApplicationDelegate {
    override init() { super.init(); ReaderOrientationClaims.delegateInstalled = true }
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        let fallback = ReaderOrientationSupport.allowed(for: window?.traitCollection.userInterfaceIdiom ?? UIDevice.current.userInterfaceIdiom)
        let mask: UIInterfaceOrientationMask
        if let scene = window?.windowScene,
           let claim = ReaderOrientationClaims.claims[ObjectIdentifier(scene)], claim.scene === scene {
            mask = claim.mask.intersection(fallback)
        } else { mask = fallback }
        #if DEBUG
        ReaderOrientationDiagnostics.record(event: "delegate.mask", window: window, scene: window?.windowScene,
            context: "fallback=\(fallback.rawValue) returned=\(mask.rawValue)")
        #endif
        return mask
    }
}

@MainActor
enum ReaderOrientationSupport {
    static func allowed(for idiom: UIUserInterfaceIdiom, bundle: Bundle = .main) -> UIInterfaceOrientationMask {
        let tablet = idiom == .pad
        let key = tablet ? "UISupportedInterfaceOrientations~ipad" : "UISupportedInterfaceOrientations"
        let values = bundle.object(forInfoDictionaryKey: key) as? [String]
            ?? bundle.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String] ?? []
        var mask: UIInterfaceOrientationMask = []
        for value in values {
            switch value {
            case "UIInterfaceOrientationPortrait": mask.insert(.portrait)
            case "UIInterfaceOrientationPortraitUpsideDown": mask.insert(.portraitUpsideDown)
            case "UIInterfaceOrientationLandscapeLeft": mask.insert(.landscapeLeft)
            case "UIInterfaceOrientationLandscapeRight": mask.insert(.landscapeRight)
            default: break
            }
        }
        return mask.isEmpty ? (tablet ? .all : .allButUpsideDown) : mask
    }
    static func supports(_ orientation: ReaderOrientation, idiom: UIUserInterfaceIdiom? = nil) -> Bool {
        let idiom = idiom ?? UIDevice.current.userInterfaceIdiom
        switch orientation {
        case .system: return true
        case .portrait: return !allowed(for: idiom).intersection(.portrait).isEmpty
        case .landscape: return !allowed(for: idiom).intersection(.landscape).isEmpty
        }
    }
}

@MainActor
private enum ReaderOrientationClaims {
    struct Claim {
        weak var scene: UIWindowScene?
        let ownerID: UUID
        let mask: UIInterfaceOrientationMask
    }
    static var delegateInstalled = false
    static var claims: [ObjectIdentifier: Claim] = [:]
}

#if DEBUG
/// Observes the public UIKit authority without requesting geometry or changing
/// a controller/scene delegate. A resolved lock does not identify its origin.
@MainActor
private enum ReaderOrientationDiagnostics {
    private static let logger = Logger(subsystem: "io.reader.minliny", category: "reader-orientation")
    private static var recording = false
    @discardableResult
    static func record(event: String, window: UIWindow?, scene: UIWindowScene?, context: String,
                       previous: String? = nil) -> String? {
        // A controller may consult application policy from its mask override.
        // Do not recursively log that query or use UIApplication's aggregate mask.
        guard !recording else { return previous }
        recording = true
        defer { recording = false }
        let actualScene = window?.windowScene ?? scene
        let claim: ReaderOrientationClaims.Claim? = actualScene.flatMap { scene in
            guard let claim = ReaderOrientationClaims.claims[ObjectIdentifier(scene)], claim.scene === scene else { return nil }
            return claim
        }
        var facts = "\(context) sensor=\(UIDevice.current.orientation.rawValue) sensorNotifications=\(UIDevice.current.isGeneratingDeviceOrientationNotifications)"
        facts += " window=\(window.map { String(describing: ObjectIdentifier($0)) } ?? "nil") frame=\(String(describing: window?.frame)) bounds=\(String(describing: window?.bounds))"
        if let actualScene {
            facts += " scene=\(ObjectIdentifier(actualScene)) active=\(actualScene.activationState.rawValue) claimOwner=\(claim?.ownerID.uuidString ?? "nil") claimMask=\(claim?.mask.rawValue ?? 0)"
            if #available(iOS 26.0, *) {
                let geometry = actualScene.effectiveGeometry
                facts += " effectiveOrientation=\(geometry.interfaceOrientation.rawValue) effectiveBounds=\(geometry.coordinateSpace.bounds) effectiveLocked=\(geometry.isInterfaceOrientationLocked) resizing=\(geometry.isInteractivelyResizing)"
            } else {
                facts += " interfaceOrientation=\(actualScene.interfaceOrientation.rawValue) sceneBounds=\(actualScene.coordinateSpace.bounds) effectiveLocked=unavailable"
            }
        }
        if let root = window?.rootViewController {
            facts += controller(root, role: "root")
            if let presented = root.presentedViewController { facts += controller(presented, role: "presented") }
            if #available(iOS 26.0, *), let child = root.childForInterfaceOrientationLock {
                facts += controller(child, role: "lockChild")
            }
        }
        if facts != previous { logger.debug("event=\(event, privacy: .public) \(facts, privacy: .public)") }
        return facts
    }
    private static func controller(_ controller: UIViewController, role: String) -> String {
        var facts = " \(role)=\(String(reflecting: type(of: controller))) \(role)Mask=\(controller.supportedInterfaceOrientations.rawValue) \(role)Preferred=\(controller.preferredInterfaceOrientationForPresentation.rawValue) \(role)View=\(String(describing: controller.viewIfLoaded?.bounds))"
        if #available(iOS 26.0, *) { facts += " \(role)PrefersLock=\(controller.prefersInterfaceOrientationLocked)" }
        return facts
    }
}
#endif

/// Thin lifecycle adapter for UIApplication's idle timer and the actual
/// UIWindowScene. It does not infer a window from connectedScenes or screen size.
@MainActor
final class ReaderDisplaySessionOwner: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    var onError: ((String) -> Void)?
    private let ownerID = UUID()
    private weak var scene: UIWindowScene?
    private var attachmentID: UUID?
    private var readerPresent = false
    private var foreground = false
    private var baselineIdle: Bool?
    private var baselineOrientation: UIInterfaceOrientation?
    private var screenTimeout: ReaderScreenAwakeMode = .system
    private var awakeLease = false
    private var awakeTimer: Task<Void, Never>?
    private var awakeGeneration = UUID()
    private var orientation: ReaderOrientation = .system
    private var orientationApplied: ReaderOrientation?
    private var windowSize: CGSize?
    private var orientationRequestGeneration = UUID()
    private var projectionGeneration = UUID()
    #if DEBUG
    private weak var diagnosticWindow: UIWindow?
    private var diagnosticLayout: String?
    #endif

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(activated(_:)), name: UIScene.didActivateNotification, object: nil)
        center.addObserver(self, selector: #selector(deactivated(_:)), name: UIScene.willDeactivateNotification, object: nil)
        center.addObserver(self, selector: #selector(deactivated(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        #if DEBUG
        center.addObserver(self, selector: #selector(sensorChanged(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        #endif
    }
    deinit { awakeTimer?.cancel(); NotificationCenter.default.removeObserver(self) }

    func enterReader() {
        readerPresent = true; acquireIfPossible()
        #if DEBUG
        traceOrientation("reader.enter")
        #endif
    }
    func leaveReader() {
        #if DEBUG
        traceOrientation("reader.leave")
        #endif
        readerPresent = false; releaseClaim(restoreOrientation: true)
    }

    func update(keepAwake: Bool, orientation: ReaderOrientation) {
        update(screenTimeout: keepAwake ? .alwaysOn : .system, orientation: orientation)
    }

    func update(screenTimeout: ReaderScreenAwakeMode, orientation: ReaderOrientation) {
        let directionChanged = self.orientation != orientation
        let timeoutChanged = self.screenTimeout != screenTimeout
        self.screenTimeout = screenTimeout
        self.orientation = orientation
        #if DEBUG
        traceOrientation("intent.update")
        #endif
        if directionChanged { orientationApplied = nil }
        if timeoutChanged { rearmAwakeLease() }
        applyIntent()
    }

    /// Host33f7 ReaderScreenAwakeLease: each real reader interaction begins a
    /// fresh finite lease. Expiry returns to system policy, never global timeout.
    func interaction() { rearmAwakeLease() }

    private func rearmAwakeLease() {
        awakeGeneration = UUID(); awakeTimer?.cancel(); awakeTimer = nil
        guard readerPresent, foreground, let baselineIdle, scene != nil else { awakeLease = false; return }
        awakeLease = screenTimeout != .system
        UIApplication.shared.isIdleTimerDisabled = baselineIdle || awakeLease
        guard let seconds = screenTimeout.leaseSeconds else { return }
        let expected = awakeGeneration
        awakeTimer = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            catch { return }
            guard let self, self.awakeGeneration == expected, self.readerPresent, self.foreground,
                  let baseline = self.baselineIdle else { return }
            self.awakeLease = false; self.awakeTimer = nil
            UIApplication.shared.isIdleTimerDisabled = baseline
        }
    }

    fileprivate func attach(scene incoming: UIWindowScene, attachmentID: UUID) {
        self.attachmentID = attachmentID
        #if DEBUG
        traceOrientation("attachment.update")
        #endif
        guard scene !== incoming else {
            let currentSize = incoming.coordinateSpace.bounds.size
            if windowSize != currentSize {
                windowSize = currentSize
                orientationApplied = nil
                applyIntent()
            }
            return
        }
        releaseClaim(restoreOrientation: true)
        scene = incoming
        windowSize = incoming.coordinateSpace.bounds.size
        foreground = incoming.activationState == .foregroundActive
        acquireIfPossible()
    }
    fileprivate func detach(attachmentID: UUID) {
        guard self.attachmentID == attachmentID else { return }
        #if DEBUG
        traceOrientation("attachment.detach")
        #endif
        releaseClaim(restoreOrientation: true)
        self.attachmentID = nil
        scene = nil
        windowSize = nil
        foreground = false
    }

    private func acquireIfPossible() {
        guard readerPresent, foreground, let scene else { return }
        if baselineIdle == nil {
            baselineIdle = UIApplication.shared.isIdleTimerDisabled
            baselineOrientation = scene.interfaceOrientation
            rearmAwakeLease()
        }
        applyIntent()
        publishActive(true)
    }

    private func applyIntent() {
        #if DEBUG
        traceOrientation("intent.apply")
        #endif
        guard readerPresent, foreground, let baselineIdle, let scene else { return }
        // Another pre-existing App claim to keep the screen on is not cancelled
        // when this reader's own keep-awake preference is switched off.
        UIApplication.shared.isIdleTimerDisabled = baselineIdle || awakeLease
        guard orientationApplied != orientation else { return }
        // Every new direction intent (including a window-size reapplication or
        // returning to system behavior) retires the previous request's callback.
        orientationRequestGeneration = UUID()
        let allowed = ReaderOrientationSupport.allowed(for: scene.traitCollection.userInterfaceIdiom)
        let desired: UIInterfaceOrientationMask
        switch orientation { case .system: desired = allowed; case .portrait: desired = .portrait; case .landscape: desired = .landscape }
        guard !desired.intersection(allowed).isEmpty else {
            orientationApplied = orientation
            onError?("当前窗口不支持所选阅读方向")
            return
        }
        if orientation == .system {
            let hadClaim = ownsOrientationClaim(in: scene)
            revokeOrientationClaim(from: scene)
            orientationApplied = orientation
            guard hadClaim else { return }
        } else {
            guard ReaderOrientationClaims.delegateInstalled else {
                orientationApplied = orientation
                onError?("当前窗口暂时无法锁定阅读方向")
                return
            }
            ReaderOrientationClaims.claims[ObjectIdentifier(scene)] = .init(scene: scene, ownerID: ownerID, mask: desired)
        }
        orientationApplied = orientation
        #if DEBUG
        traceOrientation("intent.mask-applied")
        #endif
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        if orientation != .system, let current = Self.mask(for: scene.interfaceOrientation),
           !current.intersection(desired).isEmpty { return }
        let expected = orientationRequestGeneration
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: desired.intersection(allowed))) { [weak self, weak scene] _ in
            Task { @MainActor in
                guard let self, self.orientationRequestGeneration == expected,
                      self.readerPresent, self.foreground, self.scene === scene else { return }
                if let scene {
                    self.revokeOrientationClaim(from: scene)
                    scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
                }
                #if DEBUG
                self.traceOrientation("intent.geometry-rejected")
                #endif
                self.onError?("当前窗口无法切换到所选阅读方向")
            }
        }
    }

    private func releaseClaim(restoreOrientation: Bool) {
        awakeGeneration = UUID(); awakeTimer?.cancel(); awakeTimer = nil; awakeLease = false
        let idle = baselineIdle
        let priorOrientation = baselineOrientation
        baselineIdle = nil
        baselineOrientation = nil
        orientationApplied = nil
        orientationRequestGeneration = UUID()
        if let scene {
            let hadOrientationClaim = ownsOrientationClaim(in: scene)
            revokeOrientationClaim(from: scene)
            scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            if restoreOrientation, hadOrientationClaim, scene.activationState == .foregroundActive, let priorOrientation,
               let mask = Self.mask(for: priorOrientation),
               !mask.intersection(ReaderOrientationSupport.allowed(for: scene.traitCollection.userInterfaceIdiom)).isEmpty {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in
                    // The retired reader cannot present a late error on a new page.
                }
            }
        }
        if let idle { UIApplication.shared.isIdleTimerDisabled = idle }
        publishActive(false)
        #if DEBUG
        traceOrientation("claim.release")
        #endif
    }

    private func revokeOrientationClaim(from scene: UIWindowScene) {
        let key = ObjectIdentifier(scene)
        guard ownsOrientationClaim(in: scene) else { return }
        ReaderOrientationClaims.claims.removeValue(forKey: key)
    }

    private func ownsOrientationClaim(in scene: UIWindowScene) -> Bool {
        guard let claim = ReaderOrientationClaims.claims[ObjectIdentifier(scene)] else { return false }
        return claim.ownerID == ownerID && claim.scene === scene
    }

    private static func mask(for value: UIInterfaceOrientation) -> UIInterfaceOrientationMask? {
        switch value {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }

    private func publishActive(_ value: Bool) {
        let current = UUID()
        projectionGeneration = current
        DispatchQueue.main.async { [weak self] in
            guard let self, self.projectionGeneration == current else { return }
            if self.isActive != value { self.isActive = value }
        }
    }
    @objc private func activated(_ notification: Notification) {
        guard let incoming = notification.object as? UIWindowScene, incoming === scene else { return }
        foreground = true
        acquireIfPossible()
    }
    @objc private func deactivated(_ notification: Notification) {
        guard let incoming = notification.object as? UIWindowScene, incoming === scene else { return }
        foreground = false
        releaseClaim(restoreOrientation: false)
    }
    #if DEBUG
    fileprivate func recordGeometry(window: UIWindow?, event: String, changedOnly: Bool = false) {
        diagnosticWindow = window
        let previous = changedOnly ? diagnosticLayout : nil
        let snapshot = ReaderOrientationDiagnostics.record(event: event, window: window, scene: scene,
            context: diagnosticContext, previous: previous)
        if changedOnly { diagnosticLayout = snapshot }
    }
    private var diagnosticContext: String {
        "owner=\(ownerID.uuidString) attachment=\(attachmentID?.uuidString ?? "nil") reader=\(readerPresent) foreground=\(foreground) intent=\(orientation.rawValue) applied=\(orientationApplied?.rawValue ?? "nil") delegateInstalled=\(ReaderOrientationClaims.delegateInstalled)"
    }
    private func traceOrientation(_ event: String) {
        ReaderOrientationDiagnostics.record(event: event, window: diagnosticWindow, scene: scene,
            context: diagnosticContext)
    }
    @objc private func sensorChanged(_ notification: Notification) { traceOrientation("sensor.changed") }
    #endif
}

/// Keep mounted across controls opening/closing for one complete reader session.
struct ReaderDisplayAttachment: UIViewRepresentable {
    let owner: ReaderDisplaySessionOwner
    func makeUIView(context: Context) -> ReaderDisplayAttachmentView {
        let view = ReaderDisplayAttachmentView()
        view.owner = owner
        return view
    }
    func updateUIView(_ view: ReaderDisplayAttachmentView, context: Context) {
        view.owner = owner
        view.updateAttachment()
    }
    static func dismantleUIView(_ view: ReaderDisplayAttachmentView, coordinator: ()) { view.retire() }
}

final class ReaderDisplayAttachmentView: UIView {
    weak var owner: ReaderDisplaySessionOwner?
    private let attachmentID = UUID()
    private var retired = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        #if DEBUG
        if !retired { owner?.recordGeometry(window: window, event: "attachment.window") }
        #endif
        updateAttachment()
    }
    #if DEBUG
    override func layoutSubviews() {
        super.layoutSubviews()
        if !retired { owner?.recordGeometry(window: window, event: "attachment.layout", changedOnly: true) }
    }
    #endif
    func updateAttachment() {
        let observed = window?.windowScene
        DispatchQueue.main.async { [weak self, weak observed] in
            guard let self, !self.retired, self.window?.windowScene === observed else { return }
            if let observed { self.owner?.attach(scene: observed, attachmentID: self.attachmentID) }
            else { self.owner?.detach(attachmentID: self.attachmentID) }
        }
    }
    func retire() { retired = true; owner?.detach(attachmentID: attachmentID) }
}
