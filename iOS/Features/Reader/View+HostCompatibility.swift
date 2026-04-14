import Foundation
#if canImport(SwiftUI)
import SwiftUI

public extension View {
    @ViewBuilder
    public func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
#endif
