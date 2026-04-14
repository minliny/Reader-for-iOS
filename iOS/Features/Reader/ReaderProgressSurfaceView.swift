import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct ReaderProgressSurfaceView: View {
    public let chapterIndex: Int
    public let chapterCount: Int
    public let progressPercentage: Double
    
    public init(chapterIndex: Int, chapterCount: Int, progressPercentage: Double) {
        self.chapterIndex = chapterIndex
        self.chapterCount = chapterCount
        self.progressPercentage = progressPercentage
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progressPercentage)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            HStack {
                Text("第 \(chapterIndex + 1) 章")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("共 \(chapterCount) 章 (\(String(format: "%.1f", progressPercentage * 100))%)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
#endif
