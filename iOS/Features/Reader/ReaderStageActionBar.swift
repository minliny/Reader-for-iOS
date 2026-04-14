import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct ReaderStageActionBar: View {
    public let onPrevious: (() -> Void)?
    public let onNext: (() -> Void)?
    public let onReload: (() -> Void)?
    
    public init(
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onReload: (() -> Void)? = nil
    ) {
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onReload = onReload
    }
    
    public var body: some View {
        HStack {
            if let onPrevious = onPrevious {
                Button(action: onPrevious) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一章")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            } else {
                // Placeholder to keep spacing
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一章")
                    }
                }
                .buttonStyle(.bordered)
                .opacity(0)
                .allowsHitTesting(false)
            }
            
            Spacer()
            
            if let onReload = onReload {
                Button(action: onReload) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .tint(.secondary)
            }
            
            Spacer()
            
            if let onNext = onNext {
                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            } else {
                // Placeholder to keep spacing
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.bordered)
                .opacity(0)
                .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
#endif
