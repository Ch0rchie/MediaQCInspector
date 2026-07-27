import SwiftUI

struct ReportPreviewView: View {
    @ObservedObject var model: QCModel

    var body: some View {
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
    }
}
