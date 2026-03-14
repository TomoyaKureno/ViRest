import SwiftUI
import UIKit

enum SheetSizing {
    static func fittedHeight(
        from contentHeight: CGFloat,
        minHeight: CGFloat = 260,
        maxFraction: CGFloat = 0.9,
        extra: CGFloat = 20
    ) -> CGFloat {
        let maxHeight = UIScreen.main.bounds.height * maxFraction
        return Swift.min(maxHeight, Swift.max(minHeight, contentHeight + extra))
    }
}

private struct IntrinsicHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func onIntrinsicHeightChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: IntrinsicHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(IntrinsicHeightPreferenceKey.self, perform: action)
    }
}
