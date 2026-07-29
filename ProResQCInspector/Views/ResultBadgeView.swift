import SwiftUI

struct ResultBadgeView: View {
    enum Style {
        case large
        case compact
    }

    let result: String
    var style: Style = .large

    private var badgeContent: BadgeContent {
        switch result {
        case "Passed":
            return BadgeContent(
                title: "PASS",
                subtitle: "Technical validation completed successfully.",
                symbol: "checkmark.circle.fill",
                color: .green
            )

        case "Errors Found":
            return BadgeContent(
                title: "FAIL",
                subtitle: "Technical validation identified one or more video decode errors.",
                symbol: "xmark.circle.fill",
                color: .red
            )

        case "Metadata Failed":
            return BadgeContent(
                title: "METADATA FAILED",
                subtitle: "Metadata extraction failed.",
                symbol: "exclamationmark.triangle.fill",
                color: .orange
            )

        case "In Progress":
            return BadgeContent(
                title: "ANALYZING",
                subtitle: "Technical validation is in progress.",
                symbol: "arrow.triangle.2.circlepath",
                color: .blue
            )

        case "Not Yet Analyzed":
            return BadgeContent(
                title: "READY",
                subtitle: "Select a file and begin analysis.",
                symbol: "circle.fill",
                color: .secondary
            )

        default:
            return BadgeContent(
                title: "UNKNOWN",
                subtitle: "Result unavailable.",
                symbol: "questionmark.circle.fill",
                color: .secondary
            )
        }
    }

    var body: some View {
        switch style {
        case .large:
            largeBadge
        case .compact:
            compactBadge
        }
    }

    private var largeBadge: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: badgeContent.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(badgeContent.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(badgeContent.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(badgeContent.color)

                Text(badgeContent.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(badgeContent.color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(badgeContent.color.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var compactBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: badgeContent.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(badgeContent.color)

            Text(badgeContent.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(badgeContent.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeContent.color.opacity(0.10))
        .overlay(
            Capsule(style: .continuous)
                .stroke(badgeContent.color.opacity(0.30), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
    }
}

private struct BadgeContent {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
}
