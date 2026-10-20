import SwiftUI

// Colors from docs/DESIGN.md. Each one is a color set in Assets.xcassets
// with a light and a dark version. Use these instead of raw colors.
extension Color {
    static let pfBackground = Color("background")
    static let pfSurface = Color("surface")
    static let pfSurfaceElevated = Color("surfaceElevated")
    static let pfBrandPrimary = Color("brandPrimary")
    static let pfBrandLight = Color("brandLight")
    static let pfBrandDeep = Color("brandDeep")
    static let pfTextPrimary = Color("textPrimary")
    static let pfTextSecondary = Color("textSecondary")
    static let pfBorder = Color("border")
    static let pfError = Color("error")
    static let pfSuccess = Color("success")
}

/// Spacing values so padding stays consistent.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Corner radius values.
enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
}

extension Font {
    static let pfTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let pfHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let pfBody = Font.body
    static let pfCaption = Font.caption
}
