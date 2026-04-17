import Foundation
import ReaderShellValidation
@MainActor
public enum ShellAssembly {
    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
        ReaderShellValidation.ShellAssembly.makeDefaultReadingFlowCoordinator()
    }
}
