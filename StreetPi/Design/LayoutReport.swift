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

enum ClearanceSpace {
    /// Named space installed by the clearance tests. Frames in this space match the window.
    static let name = "streetpi-clearance"
}

private struct LayoutReport: ViewModifier {
    var name: String?
    @Environment(\.streetPiLayoutReport) private var report

    @ViewBuilder
    func body(content: Content) -> some View {
        if let report, let name {
            content.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(ClearanceSpace.name))
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
