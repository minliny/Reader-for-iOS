import Foundation
import Combine

/// Shared trigger for external page-turn events (e.g. volume key presses).
///
/// `ReaderView` holds an instance and passes it to `PaginatedReaderView`.
/// When `VolumeKeyPageTurner` fires, `ReaderView` sets `trigger` to `.next`
/// or `.previous`; `PaginatedReaderView` observes the change and advances.
final class PageTurnTrigger: ObservableObject {
    enum Direction: Equatable {
        case next
        case previous
    }

    @Published var trigger: Direction?
}
