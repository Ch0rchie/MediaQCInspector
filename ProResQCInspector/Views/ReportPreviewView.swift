import SwiftUI

struct ReportPreviewView: View {
    @ObservedObject var model: QCModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Report Preview")
                    .font(.headline)

                Spacer()

                Button("Copy Report") {
                    model.copyReport()
                }
                .disabled(!model.canCopyReport)
            }
            .padding(.horizontal, 2)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.selectedReportTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        ScrollView {
                            Text(model.selectedReportText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .font(.system(size: 13))
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .frame(height: 165)
        }
    }
}
