import CoreGraphics

struct GestureArbiter {
    enum Intent: Equatable { case next, previous, systemBack, none }

    func drag(start: CGPoint, translation: CGSize, width: CGFloat, mode: ReadingMode) -> Intent {
        let edge: CGFloat = 26
        if start.x <= edge && translation.width > 0 { return .systemBack }
        guard mode == .pages, width >= edge * 2, start.x > edge,
              abs(translation.width) > 42, abs(translation.width) > abs(translation.height) * 1.4 else { return .none }
        return translation.width < 0 ? .next : .previous
    }
}
