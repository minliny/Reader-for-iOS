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
        VStack(spacing: 8) {
            ProgressView(value: progressPercentage)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            
            HStack {
                Text("第 \(chapterIndex + 1) 章")
                Spacer()
                Text("共 \(chapterCount) 章 (\(String(format: "%.1f", progressPercentage * 100))%)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
