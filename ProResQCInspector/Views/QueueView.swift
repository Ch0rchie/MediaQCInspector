import SwiftUI

struct QueueView: View {
    @ObservedObject var model: QCModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Files")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal, 2)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Group {
                        if model.files.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No files queued yet.")
                                    .foregroundStyle(.secondary)

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                        } else {
                            ScrollView(.vertical) {
                                LazyVStack(spacing: 8) {
                                    ForEach(model.files) { file in
                                        fileCard(for: file)
                                    }
                                }
                                .padding(10)
                            }
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .frame(height: 185)
        }
    }

    private func fileCard(for file: MediaFile) -> some View {
        let isSelected = model.selectedFileID == file.id

        return Button {
            model.selectedFileID = file.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: statusSymbol(for: file))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(statusColor(for: file))
                        .frame(width: 16)

                    Text(file.url.lastPathComponent)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(file.url.lastPathComponent)

                    Spacer(minLength: 0)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 6)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    metricCard("Codec", file.codec)
                    metricCard("Res", file.resolution)
                    metricCard("FPS", file.frameRate)
                    metricCard("Duration", file.duration)
                    metricCard("Size", file.fileSize)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(file.url.lastPathComponent)
    }

    private func metricCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func statusSymbol(for file: MediaFile) -> String {
        switch file.status {
        case "Ready to Analyze":
            return "circle.fill"
        case "Checking Decoder":
            return "arrow.triangle.2.circlepath"
        case "Finding Error Window":
            return "magnifyingglass.circle.fill"
        case "Generating Report":
            return "doc.text.magnifyingglass"
        case "Complete":
            if file.result == "Passed" {
                return "checkmark.circle.fill"
            } else if file.result == "Errors Found" {
                return "xmark.circle.fill"
            } else {
                return "checkmark.circle.fill"
            }
        case "Error":
            return "exclamationmark.triangle.fill"
        default:
            return "circle.fill"
        }
    }

    private func statusColor(for file: MediaFile) -> Color {
        switch file.status {
        case "Ready to Analyze":
            return .secondary
        case "Checking Decoder", "Finding Error Window", "Generating Report":
            return .blue
        case "Complete":
            if file.result == "Passed" {
                return .green
            } else if file.result == "Errors Found" {
                return .red
            } else {
                return .green
            }
        case "Error":
            return .orange
        default:
            return .secondary
        }
    }
}
