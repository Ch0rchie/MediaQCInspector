import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.98),
                                Color.blue.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 74, height: 74)
                    .shadow(color: Color.blue.opacity(0.22), radius: 8, x: 0, y: 3)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            }

            Text("ProRes QC Inspector")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Professional ProRes Validation & QC Analysis")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Created by David Gelb")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 0)
    }
}

#Preview {
    HeaderView()
}
