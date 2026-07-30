import SwiftUI

struct AboutWindowView: View {
    private let subtitle = "Professional media validation and technical reporting for production workflows."

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var ffmpegVersion: String {
        ToolLocator.ffmpegVersion
    }

    private var ffprobeVersion: String {
        ToolLocator.ffprobeVersion
    }

    private var isBundled: Bool {
        ToolLocator.isUsingBundledTools
    }

    private var statusText: String {
        isBundled ? "✓ Ready" : "Not Ready"
    }

    private var statusColor: Color {
        isBundled ? .green : .red
    }

    var body: some View {
        VStack(spacing: 18) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Text("Media QC Inspector")
                .font(.title.bold())

            Text("Version \(appVersion) (Build \(buildNumber))")
                .foregroundStyle(.secondary)

            Text(subtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            sectionTitle("Application")

            VStack(spacing: 8) {
                infoRow(label: "Version", value: appVersion)
                infoRow(label: "Build", value: buildNumber)
            }

            Divider()

            sectionTitle("Analysis Engine")

            VStack(spacing: 8) {
                infoRow(label: "FFmpeg", value: ffmpegVersion)
                infoRow(label: "FFprobe", value: ffprobeVersion)

                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 12)

                    Text(statusText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            VStack(spacing: 6) {
                Text("Created by")
                    .foregroundStyle(.secondary)

                Text("David L. Gelb")
                    .font(.title3.bold())
            }

            Text("© 2026")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 380)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }
}
