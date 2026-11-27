import CoreText
import SwiftUI

@MainActor
private final class ReaderDesignBundleAnchor {}

enum ReaderDesignResources {
    @MainActor static var bundle: Bundle { Bundle(for: ReaderDesignBundleAnchor.self) }
}

@MainActor
public enum ReaderTypography {
    private static let registered: Void = {
        for filename in ["NotoSansSC-VF.otf", "NotoSerifSC-Regular.ttf"] {
            guard let url = ReaderDesignResources.bundle.url(forResource: filename, withExtension: nil,
                                                            subdirectory: "Fonts") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    public static func nativeFont(_ metric: ReaderTypographyMetric, size: CGFloat? = nil) -> UIFont {
        _ = registered
        let size = size ?? CGFloat(metric.fontSize)
        let weight: UIFont.Weight
        let name: String
        switch metric.family {
        case .literary:
            weight = .regular
            name = "NotoSerifSC-Regular"
        case .ui:
            switch metric.weight {
            case 700...: weight = .bold; name = "NotoSansSC-Bold"
            case 500...: weight = .medium; name = "NotoSansSC-Medium"
            default: weight = .regular; name = "NotoSansSC-Regular"
            }
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

public extension View {
    func readerTypography(_ metric: ReaderTypographyMetric, relativeTo role: Font.TextStyle = .body) -> some View {
        modifier(ReaderTypographyStyle(metric, relativeTo: role))
    }
}

private struct ReaderTypographyStyle: ViewModifier {
    private let metric: ReaderTypographyMetric
    @ScaledMetric private var size: CGFloat
    @ScaledMetric private var lineHeight: CGFloat

    init(_ metric: ReaderTypographyMetric, relativeTo role: Font.TextStyle) {
        self.metric = metric
        _size = ScaledMetric(wrappedValue: CGFloat(metric.fontSize), relativeTo: role)
        _lineHeight = ScaledMetric(wrappedValue: CGFloat(metric.lineHeight), relativeTo: role)
    }

    func body(content: Content) -> some View {
        let font = ReaderTypography.nativeFont(metric, size: size)
        let leading = max(0, lineHeight - font.lineHeight)
        content
            .font(Font(font))
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
    }
}
