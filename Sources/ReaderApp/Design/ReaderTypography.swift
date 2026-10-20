import SwiftUI
import UIKit
import CoreText

enum ReaderTypeface: String, CaseIterable {
    case serif = "NotoSerifSC-Regular.ttf"
    case serifBold = "NotoSerifSC-Bold.ttf"
    case ui = "NotoSansSC-UIRegular.otf"
    case uiBold = "NotoSansSC-UIBold.otf"
    case inter = "InterVariable.ttf"
}

/// Register physical faces before constructing text or measuring pagination.
enum ReaderFonts {
    private static let names: [ReaderTypeface: String] = {
        var result: [ReaderTypeface: String] = [:]
        for face in ReaderTypeface.allCases {
            let file = face.rawValue as NSString
            let url = Bundle.main.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension)
            guard let url,
                  let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                  let descriptor = descriptors.first,
                  let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
                preconditionFailure("Missing bundled Reader font: \(face.rawValue)")
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // An already registered face is valid; other failures must not silently change typography.
                guard UIFont(name: name, size: 18) != nil else {
                    preconditionFailure("Reader font could not be registered: \(face.rawValue)")
                }
            }
            result[face] = name
        }
        return result
    }()
    static func registerBundledFonts() { _ = names }
    static func postScriptName(_ face: ReaderTypeface) -> String {
        guard let name = names[face] else { preconditionFailure("Unregistered Reader face") }
        return name
    }
    static func uiFont(_ face: ReaderTypeface, size: CGFloat, weight: CGFloat? = nil) -> UIFont {
        guard let font = UIFont(name: postScriptName(face), size: size) else {
            preconditionFailure("Registered Reader font is unavailable")
        }
        guard face == .inter, let weight else { return font }
        // The actual Inter variable weight axis is used instead of a synthetic bold face.
        let settings: [NSNumber: NSNumber] = [NSNumber(value: 0x77676874): NSNumber(value: Double(weight))]
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        return UIFont(descriptor: font.fontDescriptor.addingAttributes([variation: settings]), size: size)
    }
}

struct ReaderTextStyle {
    let face: ReaderTypeface
    let size: CGFloat
    let weight: CGFloat
    let lineHeight: CGFloat?
    let tracking: CGFloat
    let scalesWithSystem: Bool
    init(_ face: ReaderTypeface, _ size: CGFloat, _ weight: CGFloat = 400,
         lineHeight: CGFloat? = nil, tracking: CGFloat = 0, scalesWithSystem: Bool = true) {
        self.face = face; self.size = size; self.weight = weight
        self.lineHeight = lineHeight; self.tracking = tracking
        self.scalesWithSystem = scalesWithSystem
    }
    var uiFont: UIFont { ReaderFonts.uiFont(face, size: size, weight: weight) }
    var font: Font {
        guard scalesWithSystem else { return Font(uiFont as CTFont) }
        let value = Font.custom(ReaderFonts.postScriptName(face), size: size, relativeTo: .body)
        // Static CJK faces already select exact outlines. Inter uses its variable weight axis.
        guard face == .inter else { return value }
        let swiftWeight: Font.Weight = weight >= 850 ? .black : weight >= 750 ? .heavy :
            weight >= 650 ? .bold : weight >= 550 ? .semibold : weight >= 450 ? .medium : .regular
        return value.weight(swiftWeight)
    }
}

/// Host@33f7c7b:ReaderTypography.ets. A nil lineHeight retains native AUTO semantics.
enum ReaderTypography {
    enum Role {
        case appTitle, pageTitle, shelfTitle, shelfAuthor, shelfStatus, continueLabel, continueTitle, continueAuthor
        case action, chapterTitle, readerChapterTitle, controlHeader, controlCollapse, body, readerBody, caption
        case sectionLabel, mainTab, stateTitle, metadataTag
    }
    static func style(_ role: Role) -> ReaderTextStyle {
        switch role {
        case .appTitle: return ReaderTextStyle(.uiBold, 19, 700)
        case .pageTitle: return ReaderTextStyle(.serifBold, 24, 700, lineHeight: 33)
        case .shelfTitle: return ReaderTextStyle(.serifBold, 15, 700, lineHeight: 18)
        case .shelfAuthor, .shelfStatus: return ReaderTextStyle(.ui, 11, lineHeight: 14)
        case .continueLabel: return ReaderTextStyle(.inter, 11, 500, lineHeight: 18)
        case .continueTitle: return ReaderTextStyle(.serifBold, 16, 700, lineHeight: 23)
        case .continueAuthor: return ReaderTextStyle(.inter, 11, 400, lineHeight: 15)
        case .action: return ReaderTextStyle(.inter, 12, 700, lineHeight: 16)
        case .chapterTitle, .readerChapterTitle: return ReaderTextStyle(.serifBold, 23, 700, lineHeight: 28.75)
        case .controlHeader: return ReaderTextStyle(.uiBold, 14, 700, lineHeight: 20)
        case .controlCollapse: return ReaderTextStyle(.uiBold, 10, 700, lineHeight: 14)
        case .body: return ReaderTextStyle(.inter, 13, lineHeight: 19.5)
        case .readerBody: return ReaderTextStyle(.serif, 18, lineHeight: 35.28, scalesWithSystem: false)
        case .caption: return ReaderTextStyle(.ui, 11, lineHeight: 14)
        case .sectionLabel: return ReaderTextStyle(.inter, 15, 700, lineHeight: 18)
        case .mainTab: return ReaderTextStyle(.uiBold, 11, 700, lineHeight: 18)
        case .stateTitle: return ReaderTextStyle(.inter, 17, 700, lineHeight: 25.5)
        case .metadataTag: return ReaderTextStyle(.ui, 9, lineHeight: 16)
        }
    }
    static func font(_ role: Role) -> Font { style(role).font }
    static func font(role: Role) -> Font { font(role) }
    static func lineHeight(_ role: Role, systemScale: CGFloat = 1) -> CGFloat? {
        let text = style(role)
        return text.lineHeight.map { $0 * (text.scalesWithSystem ? systemScale : 1) }
    }
    static func readingFont(size: CGFloat = 18, serif: Bool = true) -> UIFont {
        ReaderFonts.uiFont(serif ? .serif : .ui, size: size)
    }
    static func readerBody(size: CGFloat = 18, serif: Bool = true) -> UIFont {
        readingFont(size: size, serif: serif)
    }
    static let defaultFontSize: CGFloat = 18
    static let defaultLineHeightMultiplier: CGFloat = 1.96
    static let defaultParagraphSpacing: CGFloat = 16
    static let defaultLetterSpacing: CGFloat = 0
    static let fontSizeRange: ClosedRange<CGFloat> = 12...40
}
