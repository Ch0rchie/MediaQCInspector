import SwiftUI

struct QueueView: View {
    @ObservedObject var model: QCModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Files")
                    .font(.headline)

                Spacer()

                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.files.isEmpty {
                Text("No files queued yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                Table(model.files, selection: $model.selectedFileID) {
                    TableColumn("Status") { file in
                        statusCell(for: file)
                    }

                    TableColumn("File") { file in
                        Text(file.url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    TableColumn("Codec") { file in
                        Text(file.codec)
                            .lineLimit(1)
                    }

                    TableColumn("Resolution") { file in
                        Text(file.resolution)
                    }

                    TableColumn("FPS") { file in
                        Text(file.frameRate)
                    }

                    TableColumn("Duration") { file in
                        Text(file.duration)
                    }

                    TableColumn("Size") { file in
                        Text(file.fileSize)
                    }

                    TableColumn("Result") { file in
                        resultCell(for: file)
                    }

                    TableColumn("Error Window") { file in
                        Text(file.region)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 240)
            }

            if model.isBusy {
                ProgressView(value: model.progress)
            }
        }
        .padding(.top, 4)
    }

    private func statusCell(for file: MediaFile) -> some View {
        let (symbol, color): (String, Color) = {
            switch file.status {
            case "Ready to Analyze":
                return ("circle.fill", .secondary)
            case "Checking Decoder":
                return ("arrow.triangle.2.circlepath", .blue)
            case "Finding Error Window":
                return ("magnifyingglass.circle.fill", .blue)
            case "Generating Report":
                return ("doc.text.magnifyingglass", .blue)
            case "Complete":
                if file.result == "Passed" {
                    return ("checkmark.circle.fill", .green)
                } else if file.result == "Errors Found" {
                    return ("xmark.circle.fill", .red)
                } else {
                    return ("checkmark.circle.fill", .green)
                }
            case "Error":
                return ("exclamationmark.triangle.fill", .orange)
            default:
                return ("circle.fill", .secondary)
            }
        }()

        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(file.status)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private func resultCell(for file: MediaFile) -> some View {
        let (symbol, color): (String, Color) = {
            switch file.result {
            case "Not Yet Analyzed":
                return ("circle.fill", .secondary)
            case "In Progress":
                return ("arrow.triangle.2.circlepath", .blue)
            case "Passed":
                return ("checkmark.circle.fill", .green)
            case "Errors Found":
                return ("xmark.circle.fill", .red)
            case "Metadata Failed":
                return ("exclamationmark.triangle.fill", .orange)
            default:
                return ("circle.fill", .secondary)
            }
        }()

        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)

            Text(file.result)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}
