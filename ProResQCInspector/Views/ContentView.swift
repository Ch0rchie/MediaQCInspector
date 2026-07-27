import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var model = QCModel()

    var body: some View {
        VStack(spacing: 16) {
            HeaderView()
            DropZoneView(model: model)
            QueueView(model: model)

            GroupBox("Report Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(model.selectedReportTitle)
                            .font(.headline)

                        Spacer()

                        Button("Copy Report") {
                            model.copyReport()
                        }
                        .disabled(!model.canCopyReport)
                    }

                    ScrollView {
                        Text(model.selectedReportText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .font(.system(size: 13))
                    }
                    .frame(minHeight: 180)
                }
                .padding(.top, 4)
            }

            FooterView(model: model)
        }
        .padding(24)
        .frame(minWidth: 1500, minHeight: 860)
    }
}

#Preview {
    ContentView()
}
