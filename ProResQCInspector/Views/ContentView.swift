import SwiftUI

struct ContentView: View {
    @StateObject private var model = QCModel()

    var body: some View {
        VStack(spacing: 12) {
            HeaderView()
                .padding(.bottom, 18)

            DropZoneView(model: model)

            HSplitView {
                QueueView(model: model)
                    .frame(minWidth: 480, idealWidth: 620, maxWidth: .infinity, maxHeight: .infinity)

                DetailPanelView(model: model)
                    .frame(minWidth: 520, idealWidth: 760, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FooterView(model: model)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(minWidth: 1500, minHeight: 940)
    }
}

#Preview {
    ContentView()
}
