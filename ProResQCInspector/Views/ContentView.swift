import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var model = QCModel()

    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
                .padding(.bottom, 4)

            ScrollView(.vertical) {
                VStack(spacing: 18) {
                    DropZoneView(model: model)
                        .padding(.top, 8)

                    HStack(alignment: .top, spacing: 14) {
                        QueueView(model: model)
                            .frame(width: 610)

                        DetailPanelView(model: model)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 8)
            }

            FooterView(model: model)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(minWidth: 1500, idealWidth: 1580, minHeight: 760, idealHeight: 800)
    }
}

#Preview {
    ContentView()
}
