import SwiftUI

/// The gallery's full stack. Snapshots measure this at each device width.
struct ComponentBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.block) {
            BriefingSample()
            VitalsSample()
            RoomsSample()
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                KickerLabel(text: "Tabs")
                GalleryTabBar()
            }
            .padding(.bottom, AfterglowShape.line)
        }
        .padding(AfterglowShape.page)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
