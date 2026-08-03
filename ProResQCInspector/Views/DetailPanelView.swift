import SwiftUI

struct DetailPanelView: View {

    @ObservedObject var model: QCModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let file = model.selectedFile {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analysis Details")
                            .font(.headline)
                    }

                    Spacer(minLength: 12)

                    Button("Copy Report") {
                        model.copyReport()
                    }
                    .disabled(!model.canCopyReport)

                    Button("Export PDF") {
                        model.exportReportPDF()
                    }
                    .disabled(!model.canCopyReport)
                }

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text("Status")
                                .foregroundStyle(.secondary)
                            Text(file.status)
                        }

                        GridRow {
                            Text("Result")
                                .foregroundStyle(.secondary)
                            Text(file.result)
                        }

                        GridRow {
                            Text("Region")
                                .foregroundStyle(.secondary)
                            Text(file.region)
                        }

                        GridRow {
                            Text("Review Window")
                                .foregroundStyle(.secondary)
                            Text(file.reviewWindow)
                        }

                        GridRow {
                            Text("Analyzed")
                                .foregroundStyle(.secondary)
                            Text(model.selectedAnalysisDate)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Report") {
                    ScrollView {
                        if model.selectedReportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("No report available.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(model.selectedReportAttributedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .lineSpacing(4)
                        }
                    }
                    .frame(minHeight: 220)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Analysis Details")
                        .font(.headline)

                    Spacer(minLength: 12)

                    Button("Copy Report") { }
                        .disabled(true)

                    Button("Export PDF") { }
                        .disabled(true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("No File Selected")
                        .font(.title3.weight(.semibold))
                    Text("Select a file in the table to view analysis details and the generated report.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background)
        )
    }
}
