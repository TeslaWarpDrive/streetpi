import SwiftUI

private struct LayoutReportKey: EnvironmentKey {
    static let defaultValue: (@MainActor (String, CGRect) -> Void)? = nil
}

extension EnvironmentValues {
    /// A test observer of rendered geometry. Ordinary app sessions do not install one.
    var streetPiLayoutReport: (@MainActor (String, CGRect) -> Void)? {
        get { self[LayoutReportKey.self] }
        set { self[LayoutReportKey.self] = newValue }
    }
}

private struct LayoutReport: ViewModifier {
    var name: String?
    @Environment(\.streetPiLayoutReport) private var report

    @ViewBuilder
    func body(content: Content) -> some View {
        if let report, let name {
            content.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                report(name, frame)
            }
        } else {
            content
        }
    }
}

extension View {
    func reportsLayout(_ name: String?) -> some View {
        modifier(LayoutReport(name: name))
    }
}
