import SwiftUI

enum AppTypography {
    static func hero(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Bold", size: size)
    }

    static func title(_ size: CGFloat) -> Font {
        .custom("AvenirNext-DemiBold", size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Regular", size: size)
    }

    static func caption(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Medium", size: size)
    }
}
