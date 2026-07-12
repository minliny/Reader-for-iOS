import Foundation
import ReaderUIContract

/// Native motion transactions use the generated Reader UI identifier directly.
///
/// Keeping a second Swift enum here previously meant every contract refresh had to be mirrored
/// by hand. Reader UI 2.5 expanded the contract to 96 identifiers and exposed that drift. The
/// typealias keeps existing native transaction APIs stable while making the generated enum, its
/// raw wire name, and `MotionSpecRegistry` the single authority.
public typealias MotionId = ReaderUIContract.MotionId

public extension ReaderUIContract.MotionId {
    /// Coarse native logging family derived from generated motion metadata.
    ///
    /// `orientationReshape` is the viewport family. Reader-owned container roles are the reader
    /// family. The remaining generated specs belong to app/component feedback. Raw-name prefix
    /// checks are only a compatibility fallback for a malformed or temporarily absent spec.
    var family: MotionFamily {
        guard let spec = ReaderUIContract.MotionSpecRegistry.spec(for: self) else {
            if rawValue.hasPrefix("viewport.") { return .viewport }
            if rawValue.hasPrefix("reader.") || rawValue.hasPrefix("motion.interrupt.") {
                return .reader
            }
            return .app
        }

        if spec.implementationKind == .orientationReshape {
            return .viewport
        }

        switch spec.containerRole {
        case .readerShell, .readerSurface, .sessionCapsule:
            return .reader
        default:
            return .app
        }
    }
}

/// Coarse native logging/diagnostic family. Identity remains the generated `MotionId`.
public enum MotionFamily: String, Sendable {
    case app
    case reader
    case viewport
}
