import Foundation
import SwiftUI
import ReaderUIContract

struct ReaderContract25ComponentProps: ComponentProps {
    let title: String
    let message: String
    let routeId: String

    init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title"),
              let message = props?.string("message"),
              let routeId = props?.string("routeId") else {
            return nil
        }
        self.title = title
        self.message = message
        self.routeId = routeId
    }
}

private struct ReaderContract25ComponentView: View {
    let props: ReaderContract25ComponentProps

    var body: some View {
        ReaderStateCard(
            icon: props.routeId.contains("error") || props.routeId.contains("offline") ? .warning : .info,
            title: props.title,
            subtitle: props.message
        )
        .padding(ReaderDesignTokens.cardPadding)
        .accessibilityIdentifier("reader-contract25-component-\(props.routeId)")
    }
}

extension ComponentRegistry {
    static func registerReaderContract25Components() {
        register(.globalStatePage) { component in
            guard let props = ReaderContract25ComponentProps(props: component.props) else {
                return AnyView(
                    ReaderStateCard(
                        icon: .warning,
                        title: "状态组件数据无效",
                        subtitle: "Reader UI 2.5 状态缺少 title、message 或 routeId。"
                    )
                    .padding(ReaderDesignTokens.cardPadding)
                )
            }
            return AnyView(ReaderContract25ComponentView(props: props))
        }
    }
}

extension ViewStateComponentFactory {
    static func readerContract25Components(
        for page: ReaderContract25RoutePage
    ) -> [ReaderUIContract.ViewStateComponent] {
        let component: [String: Any] = [
            "type": "GlobalStatePage",
            "id": "contract25-\(page.routeId.rawValue)",
            "props": [
                "title": page.title,
                "message": page.message,
                "routeId": page.routeId.rawValue,
                "renderer": page.renderer.rawValue
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: [component]),
              let decoded = try? JSONDecoder().decode(
                [ReaderUIContract.ViewStateComponent].self,
                from: data
              ) else {
            return []
        }
        return decoded
    }
}
