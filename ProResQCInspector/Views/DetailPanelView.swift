import SwiftUI
import AppKit

struct DetailPanelView: View {
    @ObservedObject var model: QCModel

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow()

            VStack(alignment: .leading, spacing: 12) {
                if let file = model.selectedFile {
                    fileDetails(for: file)
                } else {
                    noFileSelectedView
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

    @ViewBuilder
    private func headerRow() -> some View {
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
    }

    @ViewBuilder
    private func fileDetails(for file: MediaFile) -> some View {
        fileNameSection(file: file)
        metadataGrid(for: file)
        Divider()
        reportSection
    }

    @ViewBuilder
    private func fileNameSection(file: MediaFile) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(file.url.lastPathComponent)
                .font(.headline)
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private func metadataGrid(for file: MediaFile) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            detailField("Analysis Date", model.selectedAnalysisDate)
            detailField("Analysis Time", model.selectedAnalysisTime)
            detailField("Status", file.status, color: statusColor(for: file.status))
            detailField("Result", file.result, color: resultColor(for: file.result))
            detailField("Primary Error Region", file.region)
            detailField("Editorial Review Window", file.reviewWindow)
        }
    }

    @ViewBuilder
    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        }
    }

    @ViewBuilder
    private var noFileSelectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No File Selected")
                .font(.headline)

            Text("Select a file in the table to view analysis details and the generated report.")
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
