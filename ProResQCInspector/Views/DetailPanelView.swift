import SwiftUI

struct DetailPanelView: View {
    @ObservedObject var model: QCModel

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Analysis Details")
                    .font(.headline)
                    .padding(.leading, 2)

                Spacer()

                Button("Copy Report") {
                    model.copyReport()
                }
                .disabled(!model.canCopyReport)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let file = model.selectedFile {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(file.url.lastPathComponent)
                            .font(.headline)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(height: 24)

                    ResultBadgeView(result: file.result)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        detailField("Analysis Date", model.selectedAnalysisDate)
                        detailField("Analysis Time", model.selectedAnalysisTime)
                        detailField("Status", file.status, color: statusColor(for: file.status))
                        detailField("Primary Error Region", file.region)
                        detailField("Editorial Review Window", file.reviewWindow)
                    }

                    Divider()

                    Text("Report")
                        .font(.headline)

                    ScrollView {
                        Text(model.selectedReportText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .font(.system(size: 13))
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No File Selected")
                            .font(.headline)

                        Text("Select a file in the table to view analysis details and the generated report.")
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func detailField(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .foregroundStyle(color)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Complete":
            return .secondary
        case "Checking Decoder", "Finding Error Window", "Generating Report":
            return .blue
        case "Error":
            return .orange
        default:
            return .secondary
        }
    }
}
