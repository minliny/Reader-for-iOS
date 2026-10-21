import SwiftUI

private struct ReaderAutoPageScrollOffset: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Host33f7 ReaderControlAutoPageContent + ReaderControlPlaybackGeometry
/// (retained 1938:6245). All shared actors consume the common expansion sample.
struct ReaderAutoPagePanel: View {
    @ObservedObject var owner: ReaderAutoPageOwner
    @ObservedObject var preferences: ReaderPreferences
    let progress: CGFloat
    let available: Bool
    let previousEnabled: Bool
    let nextEnabled: Bool
    let previous: () -> Void
    let next: () -> Void
    let start: () -> Void
    @State private var fullScrollOffset: CGFloat = 0
    @Environment(\.colorScheme) private var scheme
    private var palette: ReaderPalette { ReaderPalette(scheme) }
    private var p: CGFloat { min(1, max(0, progress)) }
    private var running: Bool { owner.nativePagingEnabled }
    private var status: String { running ? "运行中" : owner.phase == .paused ? "已暂停" : "未开始" }
    private func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * p }
    var body: some View {
        GeometryReader { viewport in
            let delta = viewport.size.width - mix(286, 338)
            let width = max(0, mix(264, 314) + delta)
            let contentY = mix(40, 12)
            ScrollView {
                ZStack(alignment: .topLeading) {
                    HStack {
                        Text("自动翻页").font(ReaderTextStyle(.inter, 11, 700).font); Spacer()
                        Text(status).font(ReaderTextStyle(.inter, 10, 400).font).foregroundStyle(palette.muted)
                    }.frame(width: width, height: 24).offset(x: 12, y: mix(12, 26)).opacity(1 - p)
                    ZStack(alignment: .topLeading) {
                        playback(width: width, delta: delta)
                        timer(width: width).offset(y: mix(126.391, 104.391)).opacity(p).allowsHitTesting(p == 1)
                        details(width: width).offset(y: 285.782)
                    }.frame(width: width, height: 435.173, alignment: .topLeading).offset(x: 12, y: contentY)
                }.frame(width: viewport.size.width, height: max(190, contentY + 435.173 + 12), alignment: .topLeading)
                    .offset(y: fullScrollOffset * (1 - p))
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: ReaderAutoPageScrollOffset.self, value: -geometry.frame(in: .named("auto-page-scroll")).minY)
                    })
                    .padding(.bottom, fullScrollOffset * (1 - p))
            }.coordinateSpace(name: "auto-page-scroll").scrollIndicators(.hidden).scrollDisabled(p < 1)
                .onPreferenceChange(ReaderAutoPageScrollOffset.self) { value in
                    if p == 1, value.isFinite, abs(fullScrollOffset - max(0, value)) > 0.5 { fullScrollOffset = max(0, value) }
                }
        }.buttonStyle(ReaderPressFeedback()).foregroundStyle(palette.readInk)
    }
    private func playback(width: CGFloat, delta: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HStack {
                Text("自动翻页控制").font(ReaderTextStyle(.inter, 12, 700).font); Spacer()
                Text(status).font(ReaderTextStyle(.inter, 10, 400).font).foregroundStyle(palette.muted)
            }.frame(width: max(0, width - 8), height: 14.3906)
                .offset(x: 4, y: mix(24, 10)).opacity(p)
            ZStack(alignment: .topLeading) {
                chapter(isPrevious: true).frame(width: mix(62, 72), height: 52)
                    .offset(x: mix(3.3, 9.75), y: mix(-4.841, 5))
                chapter(isPrevious: false).frame(width: mix(62, 72), height: 52)
                    .offset(x: mix(187.85, 224.25) + delta, y: mix(-4.841, 5))
                Button { if running { owner.pause() } else { start() } } label: {
                    ZStack(alignment: .topLeading) {
                        ReaderIcon(running ? .pause : .play, size: 20).frame(width: 32, height: 32)
                            .background(palette.readPrimary, in: Circle())
                            .offset(x: mix(0.0001875, 31.4921875), y: mix(0, 2.5))
                        Text("自动翻页").font(ReaderTextStyle(.inter, 9, 800, lineHeight: 9).font)
                            .frame(width: 36, height: 9).offset(x: 29.4921875, y: 39)
                    }.frame(width: mix(32, 95), height: mix(32, 52), alignment: .topLeading).clipped()
                }.disabled(!available).accessibilityLabel(running ? "暂停自动翻页" : owner.phase == .paused ? "继续自动翻页" : "开始自动翻页")
                    .accessibilityIdentifier("auto-page-toggle")
                    .offset(x: mix(110.5501875, 105.4921875) + delta / 2, y: mix(-2.341, 5))
                Button { owner.stop() } label: {
                    ReaderIcon(.stop, size: 17).frame(width: 24, height: 24)
                        .background(palette.readElevated, in: Circle()).overlay(Circle().stroke(palette.border, lineWidth: 1))
                }.disabled(owner.phase == .stopped).accessibilityLabel("停止自动翻页").accessibilityIdentifier("auto-page-stop")
                    .offset(x: mix(155.55025, 188.65625) + delta / 2, y: mix(5.659, 15.5))
                Text("停止").font(ReaderTextStyle(.inter, 9, 700, lineHeight: 9).font).foregroundStyle(palette.app("app.control.paint.8C3D36"))
                    .frame(width: 18, height: 9).offset(x: mix(158.55025, 191.65625) + delta / 2, y: mix(34.159, 44)).allowsHitTesting(false)
            }.frame(width: max(0, width - 8), height: 62, alignment: .topLeading).offset(x: 4, y: 32.3906)
        }.frame(width: width, height: 104.391, alignment: .topLeading).background(palette.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border, lineWidth: 1))
    }
    private func chapter(isPrevious: Bool) -> some View {
        Button(action: isPrevious ? previous : next) {
            ZStack(alignment: .topLeading) {
                ZStack {
                    ReaderIcon(isPrevious ? .chevronLeft : .chevronRight, size: 16).offset(x: -2.5)
                    ReaderIcon(isPrevious ? .chevronLeft : .chevronRight, size: 16).offset(x: 2.5)
                }.frame(width: 27, height: 27).background(palette.readElevated, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border, lineWidth: 1)).offset(x: 22.5, y: 5)
                Text(isPrevious ? "上一章" : "下一章").font(ReaderTextStyle(.inter, 9, 700, lineHeight: 9).font)
                    .frame(width: 27, height: 9).offset(x: 22.5, y: 39)
            }.frame(width: mix(62, 72), height: 52, alignment: .topLeading).contentShape(Rectangle())
        }.disabled(!(isPrevious ? previousEnabled : nextEnabled))
    }
    private func timer(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("定时"); Spacer(); Text(String(format: "%02d:%02d", preferences.autoPageTimerMinutes, preferences.autoPageTimerSeconds)).font(ReaderTextStyle(.inter, 10, 500, lineHeight: 12).font).foregroundStyle(palette.muted) }
                .font(ReaderTextStyle(.inter, 12, 700, lineHeight: 14.4).font).frame(height: 14.4)
            HStack(spacing: 8) {
                HStack(spacing: 8) { ReaderIcon(.clock, size: 18); Text("自动停止").font(ReaderTextStyle(.inter, 11, 700, lineHeight: 11).font) }.frame(width: min(84, max(0, width / 3)))
                Picker("分钟", selection: $preferences.autoPageTimerMinutes) {
                    ForEach(0...180, id: \.self) { Text(String(format: "%02d 分", $0)).tag($0) }
                }
                Text(":").font(ReaderTextStyle(.inter, 18, 800, lineHeight: 22).font)
                Picker("秒", selection: $preferences.autoPageTimerSeconds) {
                    ForEach(0...59, id: \.self) { Text(String(format: "%02d 秒", $0)).tag($0) }
                }
            }.pickerStyle(.wheel).frame(height: 118).clipped().disabled(owner.phase != .stopped)
            Text("00:00 不设定时").font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
        }.padding(.horizontal, 4).padding(.top, 11).frame(width: width, height: 181.391, alignment: .topLeading)
            .background(palette.field, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border, lineWidth: 1))
    }
    private func details(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HStack { Text("详细配置").font(ReaderTextStyle(.inter, 12, 700).font); Spacer(); Text("即时生效").font(ReaderTextStyle(.inter, 10, 400).font).foregroundStyle(palette.muted) }.frame(width: max(0, width - 8), height: 14.3906)
                .offset(x: 4, y: mix(29, 11)).opacity(p)
            speed(width: max(0, mix(264, 306) + (width - mix(264, 314))))
                .offset(x: mix(-1.45, 4), y: mix(-175.2324, 33.3906))
            Toggle("跟随高亮", isOn: $preferences.autoPageFollowHighlight).font(ReaderTextStyle(.inter, 10, 700, lineHeight: 13).font).tint(palette.readPrimary)
                .padding(.horizontal, 9).frame(width: max(0, width - 8), height: 36)
                .background(palette.readElevated, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border, lineWidth: 1))
                .offset(x: 4, y: mix(121.3906, 103.3906)).opacity(p)
                .disabled(p != 1 || owner.phase != .stopped)
        }.frame(width: width, height: 149.391, alignment: .topLeading)
    }
    private func speed(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Text("翻页速度").font(ReaderTextStyle(.inter, mix(11, 10), 700, lineHeight: 13).font).frame(width: mix(min(140, max(0, width - 108)), 80.56), height: mix(30, 14), alignment: .leading)
                .offset(x: mix(6, 11), y: mix(0, 25))
            Text("\(Int(preferences.autoPageSeconds)) 秒").font(ReaderTextStyle(.inter, mix(11, 10), mix(900, 400), lineHeight: 13).font).foregroundStyle(palette.readPrimary)
                .frame(width: mix(30, 25), height: mix(13, 14)).offset(x: mix(width - 66, 99.56), y: mix(9.5, 25))
            Button("−") { preferences.autoPageSeconds = min(20, preferences.autoPageSeconds + 1) }
                .font(ReaderTextStyle(.inter, 18, 400, lineHeight: 18).font).frame(width: 24, height: 24).offset(x: width - 94, y: mix(3, 20)).opacity(1 - p).disabled(p != 0).accessibilityLabel("减慢自动翻页")
            Button("+") { preferences.autoPageSeconds = max(2, preferences.autoPageSeconds - 1) }
                .font(ReaderTextStyle(.inter, 18, 400, lineHeight: 18).font).frame(width: 24, height: 24).offset(x: width - 32, y: mix(3, 20)).opacity(1 - p).disabled(p != 0).accessibilityLabel("加快自动翻页")
            HStack(spacing: 8) {
                Text("2 秒").font(ReaderTypography.font(.caption))
                Slider(value: $preferences.autoPageSeconds, in: 2...20, step: 1).tint(palette.readPrimary).accessibilityLabel("自动翻页速度")
                Text("20 秒").font(ReaderTypography.font(.caption))
            }.frame(width: max(0, width - 139), height: 44).offset(x: 128, y: 10).opacity(p).disabled(p != 1)
        }.frame(width: width, height: mix(32, 64), alignment: .topLeading)
            .background(palette.readElevated, in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border, lineWidth: 1))
    }
}
