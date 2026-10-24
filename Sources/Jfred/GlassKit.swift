import SwiftUI

/// Glass surface helpers. On macOS 26+ these use the system Liquid Glass
/// effect; older systems fall back to the previous flat look.
extension View {
    @ViewBuilder
    func jfredGlass(cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: shape
            )
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.45), lineWidth: 0.8))
        }
    }
}

extension View {
    /// Tinted glass column for the two-level sidebars.
    @ViewBuilder
    func jfredSidebar(tint: Color) -> some View {
        if #available(macOS 26.0, *) {
            self.background {
                Rectangle()
                    .fill(tint.opacity(0.34))
                    .glassEffect(.regular.tint(tint.opacity(0.72)), in: Rectangle())
            }
        } else {
            self.background(tint)
        }
    }
}

/// Applies the system glass button style where available.
struct GlassButtons: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content
        }
    }
}

/// A soft, low-contrast aurora used behind the preferences content so the
/// glass surfaces have something to refract. Deliberately subtle.
struct AuroraBackdrop: View {
    var body: some View {
        ZStack {
            JfredColor.canvas
            RadialGradient(
                colors: [Color(hex: 0x8E2BB8).opacity(0.13), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 760
            )
            RadialGradient(
                colors: [Color(hex: 0x2E6BFF).opacity(0.11), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 820
            )
            RadialGradient(
                colors: [Color(hex: 0x00B8A9).opacity(0.09), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 620
            )
        }
        .allowsHitTesting(false)
    }
}
