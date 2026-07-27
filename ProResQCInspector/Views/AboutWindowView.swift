import SwiftUI

struct AboutWindowView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("ProRes QC Inspector")
                .font(.title.bold())

            Text("Version 1.0")
                .foregroundStyle(.secondary)

            Text("Professional ProRes Validation and QC Analysis")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 6) {
                Text("Created by")
                    .foregroundStyle(.secondary)
                Text("David Gelb")
                    .font(.title3.bold())
            }

            VStack(spacing: 6) {
                Text("Powered by")
                    .foregroundStyle(.secondary)
                Text("FFmpeg")
                    .font(.title3.bold())
            }

            Text("© 2026 David Gelb")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 360)
    }
}
