import SwiftUI

struct AboutWindowView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("ProRes QC Inspector")
                .font(.title.bold())

            Text("Version \(appVersion) (Build \(buildNumber))")
                .foregroundStyle(.secondary)

            Text("Professional Apple ProRes validation\nand technical reporting for production workflows.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 6) {
                Text("Created by")
                    .foregroundStyle(.secondary)
                Text("David Gelb")
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
