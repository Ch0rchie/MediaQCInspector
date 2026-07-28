import SwiftUI

struct DetailPanelView: View {
    @ObservedObject var model: QCModel

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Analysis Details")
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
                    VStack(alignment: .leading, spacing: 12) {
                        if let file = model.selectedFile {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(file.url.lastPathComponent)
                                    .font(.headline)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 26)

                            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                detailField("Status", file.status, color: statusColor(for: file.status))
                                detailField("Result", file.result, color: resultColor(for: file.result))
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
                        }
                    }
                    .padding(10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .frame(minHeight: 330)
        }
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
            return .green
        case "Checking Decoder", "Finding Error Window", "Generating Report":
            return .blue
        case "Error":
            return .orange
        default:
            return .secondary
        }
    }

    private func resultColor(for result: String) -> Color {
        switch result {
        case "Passed":
            return .green
        case "Errors Found":
            return .red
        case "Metadata Failed":
            return .orange
        case "In Progress":
            return .blue
        default:
            return .secondary
        }
    }
}
