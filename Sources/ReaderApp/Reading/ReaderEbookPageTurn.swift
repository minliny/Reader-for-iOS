import UIKit
import WebKit
import OSLog

#if DEBUG
private let readerEbookPageTurnLogger = Logger(subsystem: "io.reader.minliny", category: "reader-ebook")
#endif

/// A transition owns at most two bounded viewport images, never another book
/// document/WebKit process. UIKit owns interpolation. Persistent simulation
/// uses ReaderEbookCurlPager so a running curl is never torn down per turn.
@MainActor
final class ReaderEbookPageTurn {
    static let maximumSnapshotPixels = 2_500_000
    private let overlay = UIView()
    private var animator: UIViewPropertyAnimator?
    private var completed = false
    private var wantsCommit = true
    private let duration: TimeInterval
    private let completion: (Bool) -> Void

    init?(in container: UIView, before: UIImage, after: UIImage, direction: Int,
          transition: ReaderPageTransition, paper: UIColor, interactive: Bool = false,
          completion: @escaping (Bool) -> Void) {
        guard Self.accepts(before), Self.accepts(after), container.bounds.width > 0,
              container.bounds.height > 0, transition != .none, transition != .simulation else { return nil }
        self.completion = completion
        duration = transition == .cover ? 0.30 : 0.26
        overlay.frame = container.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = paper
        overlay.clipsToBounds = true
        overlay.accessibilityElementsHidden = true
        container.addSubview(overlay)
        let outgoing = Self.imageView(before, in: overlay.bounds, paper: paper)
        let incoming = Self.imageView(after, in: overlay.bounds, paper: paper)
        let width = overlay.bounds.width
        let forward = direction >= 0
        switch transition {
        case .simulation:
            break // Rejected above; simulation has one persistent native pager.
        case .cover, .slide:
            if transition == .cover && forward {
                overlay.addSubview(incoming); overlay.addSubview(outgoing)
            } else {
                overlay.addSubview(outgoing); overlay.addSubview(incoming)
            }
            if transition == .slide || !forward {
                incoming.transform = CGAffineTransform(translationX: forward ? width : -width, y: 0)
            }
            if transition == .cover {
                let moving = forward ? outgoing : incoming
                moving.layer.shadowColor = UIColor.black.cgColor
                moving.layer.shadowOpacity = 0.23
                moving.layer.shadowRadius = 10
                moving.layer.shadowOffset = CGSize(width: forward ? 5 : -5, height: 0)
            }
            let animator = UIViewPropertyAnimator(duration: duration, timingParameters: Self.easeOut)
            animator.scrubsLinearly = true
            animator.addAnimations {
                if transition == .slide || forward {
                    outgoing.transform = CGAffineTransform(translationX: forward ? -width : width, y: 0)
                }
                incoming.transform = .identity
            }
            animator.addCompletion { [weak self] position in
                guard let self else { return }
                self.finish(self.wantsCommit && position == .end)
            }
            self.animator = animator
            if interactive {
                animator.startAnimation(); animator.pauseAnimation(); animator.fractionComplete = 0
            } else {
                DispatchQueue.main.async { [weak self, weak animator] in
                    guard let self, !self.completed else { return }
                    animator?.startAnimation()
                }
            }
        case .none: break
        }
    }

    static func accepts(_ image: UIImage) -> Bool {
        guard let pixels = image.cgImage, pixels.width > 0, pixels.height > 0 else { return false }
        return pixels.width <= maximumSnapshotPixels / pixels.height
            && pixels.bytesPerRow <= (10 * 1024 * 1024) / pixels.height
    }

    var fractionComplete: CGFloat { animator?.fractionComplete ?? 0 }
    var canRegrab: Bool { !completed && animator != nil }

    @discardableResult
    func pauseForInteraction() -> CGFloat {
        guard !completed, let animator else { return 0 }
        if animator.state == .inactive { animator.startAnimation() }
        if animator.isRunning { animator.pauseAnimation() }
        animator.isReversed = false
        return animator.fractionComplete
    }

    func updateProgress(_ fraction: CGFloat) {
        guard !completed, let animator else { return }
        _ = pauseForInteraction()
        animator.fractionComplete = max(0, min(1, fraction))
    }

    func release(commit: Bool, velocity: CGFloat = 0) {
        guard !completed, let animator else { if !commit { cancel() }; return }
        _ = pauseForInteraction()
        wantsCommit = commit
        animator.isReversed = !commit
        let distance = abs((commit ? 1 : 0) - animator.fractionComplete) * overlay.bounds.width
        let seconds = max(0.08, min(duration, Double(distance / max(overlay.bounds.width * 2.5, abs(velocity)))))
        animator.continueAnimation(withTimingParameters: Self.easeOut, durationFactor: seconds / duration)
    }

    private static var easeOut: UICubicTimingParameters {
        UICubicTimingParameters(controlPoint1: CGPoint(x: 1.0 / 3, y: 1), controlPoint2: CGPoint(x: 2.0 / 3, y: 1))
    }

    /// Cancelling removes UIKit's in-flight animation/child controller before
    /// the owner restores the one active WK viewport. A stale completion can
    /// never acknowledge or commit the cancelled page.
    func cancel() { finish(false) }

    private func finish(_ committed: Bool) {
        guard !completed else { return }
        completed = true
        if animator?.state == .active { animator?.stopAnimation(true) }
        animator = nil
        overlay.subviews.forEach { $0.removeFromSuperview() }
        overlay.removeFromSuperview()
        completion(committed)
    }

    private static func imageView(_ image: UIImage, in bounds: CGRect, paper: UIColor) -> UIImageView {
        let view = UIImageView(image: image)
        view.frame = bounds; view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentMode = .scaleToFill; view.backgroundColor = paper; view.isOpaque = true
        return view
    }

}

/// A persistent native curl container. UIKit owns its interactive pan and curl;
/// the current child contains the one live book WKWebView at rest. The owner
/// prepares at most two neighbours and settles the WK before admitting another
/// turn. This controller stays contained until a native turn has drained.
@MainActor
final class ReaderEbookCurlPager: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private enum Phase { case idle, ready, turning, settling, retiring, retired }
    let identity = UUID()
    private var phase: Phase = .idle
    private var pages: [Int: ReaderEbookCurlPage] = [:]
    private var current: ReaderEbookCurlPage
    private var pending: ReaderEbookCurlPage?
    private var turnIdentity: UUID?
    private var turnDirection = 0
    private var turnStartOffset: CGPoint?
    private var logicalCancellation = false
    private var nativeRunning = false
    private var programmatic = false
    private var observedPans: [UIPanGestureRecognizer] = []
    private weak var liveWebView: WKWebView?
    private weak var mount: UIView?
    private let paper: UIColor
    var began: ((UUID, Int) -> Void)?
    var ended: ((UUID, Int, Bool) -> Void)?
    var manualBegan: (() -> Void)?
    var memoryPressure: (() -> Void)?
    var retired: (() -> Void)?

    init(in mount: UIView, webView: WKWebView, paper: UIColor) {
        self.mount = mount; self.liveWebView = webView; self.paper = paper
        current = ReaderEbookCurlPage(paper: paper)
        super.init(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)])
        isDoubleSided = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    func attach() -> Bool {
        guard parent == nil, let mount, let host = Self.host(of: mount), let liveWebView else { return false }
        // Establish containment before asking UIKit to display its first child.
        host.addChild(self)
        view.frame = mount.bounds; view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = paper; view.isOpaque = true
        mount.addSubview(view); didMove(toParent: host)
        current.loadViewIfNeeded(); current.show(liveWebView)
        pages = [0: current]
        delegate = self
        setViewControllers([current], direction: .forward, animated: false)
        dataSource = self
        for gesture in gestureRecognizers {
            if let pan = gesture as? UIPanGestureRecognizer {
                pan.addTarget(self, action: #selector(nativePanned(_:))); observedPans.append(pan)
            } else if gesture is UITapGestureRecognizer {
                // The original document owns its edge/centre click routing.
                gesture.isEnabled = false
            }
        }
        enablePans(false)
        return true
    }

    var isTurning: Bool { nativeRunning || phase == .settling }
    var canPrepare: Bool { phase == .idle || phase == .ready }
    var isReady: Bool { phase == .ready }

    func coverCurrent(_ image: UIImage) {
        guard canPrepare, ReaderEbookPageTurn.accepts(image) else { return }
        phase = .idle; enablePans(false)
        pages.values.filter { $0 !== current }.forEach { $0.releaseImage() }
        pages = [0: current]
        current.cover(image)
        current.view.isUserInteractionEnabled = false
    }

    /// Both nil neighbours are valid at a one-page chapter. The three images
    /// share the same immutable document/layout generation in the owner.
    @discardableResult
    func prepared(current image: UIImage, previous: UIImage?, next: UIImage?) -> Bool {
        guard phase == .idle, ReaderEbookPageTurn.accepts(image),
              previous.map(ReaderEbookPageTurn.accepts) ?? true,
              next.map(ReaderEbookPageTurn.accepts) ?? true,
              let liveWebView else { return false }
        pages = [0: current]
        current.setImage(image)
        for (offset, image) in [(-1, previous), (1, next)] {
            if let image {
                let page = ReaderEbookCurlPage(paper: paper); page.setImage(image); pages[offset] = page
            }
        }
        current.show(liveWebView)
        current.view.isUserInteractionEnabled = true
        phase = .ready; enablePans(true)
        return true
    }

    func contains(_ direction: Int) -> Bool { pages[direction < 0 ? -1 : 1] != nil }

    @discardableResult
    func turn(_ direction: Int) -> Bool {
        guard phase == .ready, let target = pages[direction < 0 ? -1 : 1] else { return false }
        let token = begin(target, direction: direction < 0 ? -1 : 1, programmatic: true)
        // Retaining the pager through UIKit's completion is intentional. An
        // interrupted owner can retire its callbacks immediately; containment
        // is removed only after this exact native appearance transition ends.
        DispatchQueue.main.async { [self] in
            guard nativeRunning, turnIdentity == token else { return }
            if logicalCancellation { finishNative(token, completed: false); return }
            setViewControllers([target], direction: direction < 0 ? .reverse : .forward, animated: true) { [self] finished in
                finishNative(token, completed: finished && viewControllers?.first === target)
            }
        }
        return true
    }

    /// Native completion may detach the previous child from its window. Move
    /// the same live WK below the visible target's existing bitmap *before*
    /// the owner awaits WebKit frames. The target is still uncommitted and
    /// neither input nor accessibility can observe its provisional viewport.
    @discardableResult
    func stageSettlement(_ token: UUID) -> Bool {
        guard phase == .settling, turnIdentity == token, !logicalCancellation,
              let pending, viewControllers?.first === pending,
              let liveWebView, let window = view.window, pending.view.window === window else { return false }
        view.layoutIfNeeded(); pending.view.layoutIfNeeded()
        guard pending.stage(liveWebView, offset: turnStartOffset) else { return false }
        return liveWebView.window === window && liveWebView.bounds.width > 0 && liveWebView.bounds.height > 0
    }

    func settled(committed: Bool, token: UUID? = nil) {
        guard phase == .settling, token == nil || turnIdentity == token, let liveWebView else { return }
        if committed, let pending { current = pending }
        // A rejected native completion can have visually reached its target.
        // Reset only after the native callback, never inside a running curl.
        if viewControllers?.first !== current {
            setViewControllers([current], direction: .forward, animated: false)
        }
        current.show(liveWebView)
        if !committed, let turnStartOffset { liveWebView.scrollView.setContentOffset(turnStartOffset, animated: false) }
        current.view.isUserInteractionEnabled = true
        pages.values.filter { $0 !== current }.forEach { $0.releaseImage() }
        pages = [0: current]
        pending = nil; turnIdentity = nil; turnStartOffset = nil; phase = .idle
        enablePans(false)
    }

    func discardPrepared() {
        guard canPrepare, let liveWebView else { return }
        phase = .idle; enablePans(false)
        pages.values.forEach { $0.releaseImage() }
        pages = [0: current]; current.show(liveWebView); current.view.isUserInteractionEnabled = true
    }

    func cancel() {
        guard phase != .retired else { return }
        logicalCancellation = true
        enablePans(false) // Cancels a gesture through UIKit's own return path.
        if phase == .settling { settled(committed: false) }
        else if !nativeRunning { discardPrepared() }
    }

    func retire() {
        guard phase != .retiring, phase != .retired else { return }
        logicalCancellation = true
        phase = .retiring
        began = nil; ended = nil; manualBegan = nil; memoryPressure = nil
        view.isHidden = true
        pages.values.forEach { $0.releaseImage() }
        enablePans(false)
        if !nativeRunning { detach() }
    }

    func pageViewController(_ controller: UIPageViewController, viewControllerBefore page: UIViewController) -> UIViewController? {
        neighbour(of: page, offset: -1, controller: controller)
    }
    func pageViewController(_ controller: UIPageViewController, viewControllerAfter page: UIViewController) -> UIViewController? {
        neighbour(of: page, offset: 1, controller: controller)
    }
    private func neighbour(of page: UIViewController, offset: Int, controller: UIPageViewController) -> UIViewController? {
        guard controller === self, phase == .ready || phase == .turning,
              let index = pages.first(where: { $0.value === page })?.key else { return nil }
        return pages[index + offset]
    }
    func pageViewController(_ controller: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard controller === self, phase == .ready, let target = pendingViewControllers.first as? ReaderEbookCurlPage,
              let direction = pages.first(where: { $0.value === target })?.key, abs(direction) == 1 else { return }
        _ = begin(target, direction: direction, programmatic: false)
    }
    func pageViewController(_ controller: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard controller === self, !programmatic, let token = turnIdentity else { return }
        finishNative(token, completed: finished && completed && viewControllers?.first === pending)
    }

    private func begin(_ target: ReaderEbookCurlPage, direction: Int, programmatic: Bool) -> UUID {
        let token = UUID()
        turnIdentity = token; turnDirection = direction; pending = target
        turnStartOffset = liveWebView?.scrollView.contentOffset
        logicalCancellation = false; self.programmatic = programmatic
        nativeRunning = true; phase = .turning
        began?(token, direction)
        return token
    }
    private func finishNative(_ token: UUID, completed: Bool) {
        guard nativeRunning, turnIdentity == token else { return }
        nativeRunning = false
        if phase == .retiring { detach(); return }
        guard phase == .turning else { return }
        phase = .settling; enablePans(false)
        let accept = completed && !logicalCancellation && stageSettlement(token)
        #if DEBUG
        let geometry = "native-ended token=\(token) direction=\(turnDirection) completed=\(completed) cancelled=\(logicalCancellation) staged=\(accept) window=\(liveWebView?.window != nil) offset=\(String(describing: liveWebView?.scrollView.contentOffset)) start=\(String(describing: turnStartOffset)) bounds=\(String(describing: liveWebView?.bounds))"
        readerEbookPageTurnLogger.info("\(geometry, privacy: .public)")
        #endif
        ended?(token, turnDirection, accept)
    }
    private func enablePans(_ enabled: Bool) {
        observedPans.forEach { $0.isEnabled = enabled }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        memoryPressure?()
    }
    @objc private func nativePanned(_ pan: UIPanGestureRecognizer) {
        if pan.state == .began { manualBegan?() }
    }
    private func detach() {
        guard phase != .retired else { return }
        phase = .retired
        delegate = nil; dataSource = nil
        observedPans.forEach { $0.removeTarget(self, action: #selector(nativePanned(_:))) }; observedPans = []
        pages.values.forEach { $0.releaseImage(); $0.removeLiveWebView() }; pages = [:]
        pending?.removeLiveWebView(); pending = nil
        current.removeLiveWebView()
        turnIdentity = nil; turnStartOffset = nil
        willMove(toParent: nil); view.removeFromSuperview(); removeFromParent()
        let callback = retired; retired = nil; callback?()
    }
    private static func host(of view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder { if let host = current as? UIViewController { return host }; responder = current.next }
        return nil
    }
}

@MainActor
private final class ReaderEbookCurlPage: UIViewController {
    private let paper: UIColor
    private let imageView = UIImageView()
    private weak var webView: WKWebView?
    init(paper: UIColor) { self.paper = paper; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        let page = UIView(); page.backgroundColor = paper; page.isOpaque = true
        imageView.frame = page.bounds; imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleToFill; imageView.isOpaque = true; imageView.backgroundColor = paper
        imageView.accessibilityElementsHidden = true; page.addSubview(imageView); view = page
    }
    func setImage(_ image: UIImage) { loadViewIfNeeded(); imageView.image = image }
    func cover(_ image: UIImage) {
        setImage(image); imageView.isHidden = false; view.bringSubviewToFront(imageView)
    }
    func show(_ web: WKWebView) {
        loadViewIfNeeded()
        view.accessibilityElementsHidden = false; view.isUserInteractionEnabled = true
        if web.superview === view { view.bringSubviewToFront(web); imageView.isHidden = true; return }
        web.removeFromSuperview(); web.translatesAutoresizingMaskIntoConstraints = true
        web.frame = view.bounds; web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(web); webView = web; imageView.isHidden = true
        view.accessibilityElementsHidden = false
    }
    func stage(_ web: WKWebView, offset: CGPoint?) -> Bool {
        loadViewIfNeeded()
        guard imageView.image != nil else { return false }
        if web.superview !== view {
            web.removeFromSuperview(); web.translatesAutoresizingMaskIntoConstraints = true
            web.frame = view.bounds; web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(web, belowSubview: imageView)
            if let offset { web.scrollView.setContentOffset(offset, animated: false) }
        }
        webView = web; imageView.isHidden = false; view.bringSubviewToFront(imageView)
        view.accessibilityElementsHidden = true; view.isUserInteractionEnabled = false
        return true
    }
    func releaseImage() { imageView.image = nil }
    func removeLiveWebView() { if webView?.superview === view { webView?.removeFromSuperview() }; webView = nil }
}
