import os
import ReaderHost
import SwiftUI
import UIKit

/// UIKit supplies tiled drawing and pan deceleration. The Core coordinate
/// belongs to the image under the viewport, independently of the scroll size.
struct MangaPageCanvas: UIViewRepresentable {
    let image: MangaTileImage
    let direction: MangaDirection
    var anchor: CGPoint = .init(x: 0.5, y: 0)
    var anchorRequest = 0
    var accessibilityPage: String?
    var onPosition: (CGPoint) -> Void = { _ in }
    var onPageSwipe: (Int) -> Void = { _ in }

    func makeUIView(context: Context) -> MangaCanvasScrollView { MangaCanvasScrollView() }

    func updateUIView(_ view: MangaCanvasScrollView, context: Context) {
        view.apply(image: image, direction: direction, anchor: anchor, anchorRequest: anchorRequest,
                   onPosition: onPosition, onPageSwipe: onPageSwipe)
        view.accessibilityIdentifier = "m3-manga-page-art"
        view.accessibilityValue = accessibilityPage
    }
}

enum MangaDirection: String {
    case vertical, horizontal
}

final class MangaCanvasScrollView: UIScrollView, UIScrollViewDelegate {
    private let canvas = UIView()
    private let tiles = MangaCanvasLayer()
    private var image: MangaTileImage?
    private var direction = MangaDirection.vertical
    private var position: CGPoint = .init(x: 0.5, y: 0)
    private var request = -1
    private var dragStart: CGFloat = 0
    private var pageSwipes: [UISwipeGestureRecognizer] = []
    private var previousSize = CGSize.zero
    private var pendingLayout = true
    private var onPosition: (CGPoint) -> Void = { _ in }
    private var onPageSwipe: (Int) -> Void = { _ in }

    init() {
        super.init(frame: .zero)
        canvas.layer.addSublayer(tiles)
        addSubview(canvas)
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = false
        delegate = self
        for direction: UISwipeGestureRecognizer.Direction in [.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipePage(_:)))
            swipe.direction = direction
            addGestureRecognizer(swipe)
            swipe.isEnabled = false
            pageSwipes.append(swipe)
        }
    }

    required init?(coder: NSCoder) { nil }

    func apply(image: MangaTileImage, direction: MangaDirection, anchor: CGPoint, anchorRequest: Int,
               onPosition: @escaping (CGPoint) -> Void, onPageSwipe: @escaping (Int) -> Void) {
        self.onPosition = onPosition
        self.onPageSwipe = onPageSwipe
        guard self.image !== image || self.direction != direction || request != anchorRequest else { return }
        self.image = image
        self.direction = direction
        pageSwipes.forEach { $0.isEnabled = direction == .horizontal }
        request = anchorRequest
        position = anchor
        pendingLayout = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image, bounds.width > 0, bounds.height > 0,
              pendingLayout || previousSize != bounds.size else { return }
        pendingLayout = false
        previousSize = bounds.size
        // Portrait strips fill the width. Paged mode keeps one image on the
        // logical page, fitting short art while leaving long strips pannable.
        let fit = min(bounds.width, bounds.height * image.aspectRatio)
        let isLong = image.aspectRatio < 0.48
        let width = direction == .vertical || isLong ? bounds.width : fit
        let height = width / image.aspectRatio
        let art = CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: height)
        canvas.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(height, bounds.height))
        contentSize = canvas.bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tiles.frame = art
        tiles.install(image: image, targetSize: art.size)
        CATransaction.commit()
        let display = image.displayPoint(forOriginal: position)
        setContentOffset(CGPoint(x: 0, y: min(max(contentSize.height - bounds.height, 0), display.y * height)), animated: false)
        alwaysBounceVertical = direction == .vertical || height > bounds.height
        accessibilityLabel = "漫画图页"
        isAccessibilityElement = true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isTracking || isDragging || isDecelerating, let image, tiles.bounds.height > 0 else { return }
        position = image.originalPoint(forDisplay: CGPoint(x: 0.5, y: max(0, min(1, contentOffset.y / tiles.bounds.height))))
        onPosition(position)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { dragStart = contentOffset.y }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard direction == .vertical else { return }
        let amount = panGestureRecognizer.translation(in: self).y
        let bottom = max(contentSize.height - bounds.height, 0)
        if dragStart >= bottom - 1 && amount < -60 {
            onPageSwipe(1)
        } else if dragStart <= 1 && amount > 60 {
            onPageSwipe(-1)
        }
    }

    @objc private func swipePage(_ swipe: UISwipeGestureRecognizer) {
        guard direction == .horizontal else { return }
        onPageSwipe(swipe.direction == .left ? 1 : -1)
    }
}

private final class MangaCanvasLayer: CATiledLayer {
    private struct Painting: Sendable {
        let image: MangaTileImage
        let targetSize: CGSize
    }

    private let painting = OSAllocatedUnfairLock<Painting?>(initialState: nil)

    override init() {
        super.init()
        tileSize = CGSize(width: 512, height: 512)
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let previous = layer as? MangaCanvasLayer {
            let value = previous.painting.withLock { $0 }
            painting.withLock { $0 = value }
        }
    }

    required init?(coder: NSCoder) { nil }

    override class func fadeDuration() -> CFTimeInterval { 0 }

    func install(image: MangaTileImage, targetSize: CGSize) {
        painting.withLock { $0 = .init(image: image, targetSize: targetSize) }
        setNeedsDisplay()
    }

    override func draw(in context: CGContext) {
        guard let value = painting.withLock({ $0 }) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: 0, y: value.targetSize.height)
        context.scaleBy(x: 1, y: -1)
        value.image.draw(in: context, target: CGRect(origin: .zero, size: value.targetSize), clip: context.boundingBoxOfClipPath)
    }
}

private extension MangaTileImage {
    func displayPoint(forOriginal point: CGPoint) -> CGPoint {
        switch orientation {
        case 2: .init(x: 1 - point.x, y: point.y)
        case 3: .init(x: 1 - point.x, y: 1 - point.y)
        case 4: .init(x: point.x, y: 1 - point.y)
        case 5: .init(x: point.y, y: point.x)
        case 6: .init(x: 1 - point.y, y: point.x)
        case 7: .init(x: 1 - point.y, y: 1 - point.x)
        case 8: .init(x: point.y, y: 1 - point.x)
        default: point
        }
    }
}
