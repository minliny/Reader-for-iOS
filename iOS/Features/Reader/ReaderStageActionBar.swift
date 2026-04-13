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
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if let onReload = onReload {
                Button(action: onReload) {
                    Label("重新加载", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            
            Spacer()
            
            if let onNext = onNext {
                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
