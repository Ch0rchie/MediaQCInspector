import Foundation
import AppKit

struct ReportFormatter {
    private let startPadding: Double = 1.0
    private let endPadding: Double = 0.5

    func editorialReviewWindow(for primaryWindow: TimeWindow, durationSeconds: Double) -> TimeWindow {
        let start = max(0, primaryWindow.start - startPadding)
        let end = min(durationSeconds, primaryWindow.end + endPadding)
        return TimeWindow(start: start, end: end)
    }

    func formatWindow(_ window: TimeWindow) -> String {
        "\(formatTimecode(window.start))–\(formatTimecode(window.end))"
    }

    func analysisDateString(for analyzedAt: Date?) -> String {
        guard let analyzedAt else { return "—" }
        return analysisDateFormatter.string(from: analyzedAt)
    }

    func analysisTimeString(for analyzedAt: Date?) -> String {
        guard let analyzedAt else { return "—" }
        return analysisTimeFormatter.string(from: analyzedAt)
    }

    func report(for file: MediaFile) -> String {
        switch file.result {
        case "Passed":
            return passedReport(for: file)
        case "Errors Found":
            return failedReport(for: file)
        case "Metadata Failed":
            return metadataFailedReport(for: file)
        default:
            return pendingReport(for: file)
        }
    }

    func attributedReport(for file: MediaFile) -> NSAttributedString {
        let result = NSMutableAttributedString()

        appendTitle("Technical Validation Report", to: result)
        appendDivider(to: result)

        appendLabelValue("File:", file.url.lastPathComponent, valueColor: .labelColor, to: result)

        if file.analyzedAt != nil {
            appendLabelValue("Analysis Date:", analysisDateString(for: file.analyzedAt), valueColor: .labelColor, to: result)
            appendLabelValue("Analysis Time:", analysisTimeString(for: file.analyzedAt), valueColor: .labelColor, to: result)
        }

        appendDivider(to: result)

        switch file.result {
        case "Passed":
            appendSectionHeader("Summary", to: result)
            appendParagraph("Technical validation completed successfully.", to: result)
            appendLabelValue("Result:", "PASS", valueFont: .boldSystemFont(ofSize: 12), valueColor: .systemGreen, to: result)
            appendParagraph("No video decode errors were detected.", to: result)

        case "Errors Found":
            let primaryRegion = file.region == "—" ? "Unavailable" : file.region
            let reviewWindow = file.reviewWindow == "—" ? primaryRegion : file.reviewWindow

            appendSectionHeader("Summary", to: result)
            appendParagraph("Technical validation identified one or more video decode errors.", to: result)
            appendLabelValue("Result:", "FAIL", valueFont: .boldSystemFont(ofSize: 12), valueColor: .systemRed, to: result)
            appendParagraph("Video decode errors were detected.", to: result)

            appendDivider(to: result)

            appendSectionHeader("Findings", to: result)
            appendParagraph("Reported decoder errors:", to: result)
            appendBullets(
                [
                    "invalid frame header",
                    "Error submitting packet to decoder: Invalid data found when processing input"
                ],
                to: result
            )

            appendDivider(to: result)

            appendSectionHeader("Affected Region", to: result)
            appendLabelValue("Primary error region:", primaryRegion, valueColor: .labelColor, to: result)
            appendParagraph("For editorial purposes, review approximately:", to: result)
            appendParagraph(reviewWindow, emphasis: true, to: result)
            appendParagraph("to ensure the entire affected section is replaced or regenerated.", to: result)

            appendDivider(to: result)

            appendSectionHeader("Recommended Action", to: result)
            appendParagraph(
                "Please review the original timeline and regenerate this portion of the ProRes master, or provide a newly exported master from the source project. After replacement, the file should be analyzed again to confirm that no ProRes decode errors remain.",
                to: result
            )

        case "Metadata Failed":
            appendSectionHeader("Summary", to: result)
            appendParagraph("Metadata extraction failed.", to: result)
            appendLabelValue("Result:", "METADATA FAILED", valueFont: .boldSystemFont(ofSize: 12), valueColor: .systemOrange, to: result)
            appendParagraph("The file could not be fully analyzed.", to: result)

        default:
            appendSectionHeader("Summary", to: result)
            appendParagraph("The file has not been analyzed yet.", to: result)
        }

        return result
    }

    private func reportHeader(for file: MediaFile) -> [String] {
        var lines: [String] = [
            "Technical Validation Report",
            "",
            "File: \(file.url.lastPathComponent)"
        ]

        if file.analyzedAt != nil {
            lines += [
                "Analysis Date: \(analysisDateString(for: file.analyzedAt))",
                "Analysis Time: \(analysisTimeString(for: file.analyzedAt))"
            ]
        }

        lines += [""]
        return lines
    }

    private func passedReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "Technical validation completed successfully.",
            "Result: PASS",
            "No video decode errors were detected."
        ]
        return lines.joined(separator: "\n")
    }

    private func failedReport(for file: MediaFile) -> String {
        let primaryRegion = file.region == "—" ? "Unavailable" : file.region
        let reviewWindow = file.reviewWindow == "—" ? primaryRegion : file.reviewWindow

        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "Technical validation identified one or more video decode errors.",
            "Result: FAIL",
            "",
            "Findings",
            "Reported decoder errors:",
            "- invalid frame header",
            "- Error submitting packet to decoder: Invalid data found when processing input",
            "",
            "Affected Region",
            "Primary error region: \(primaryRegion)",
            "Editorial review window: \(reviewWindow)",
            "Review the entire affected section to ensure it is replaced or regenerated.",
            "",
            "Recommended Action",
            "Please review the original timeline and regenerate this portion of the ProRes master, or provide a newly exported master from the source project. After replacement, the file should be analyzed again to confirm that no ProRes decode errors remain."
        ]
        return lines.joined(separator: "\n")
    }

    private func metadataFailedReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "Metadata extraction failed.",
            "Result: METADATA FAILED",
            "The file could not be fully analyzed."
        ]
        return lines.joined(separator: "\n")
    }

    private func pendingReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "The file has not been analyzed yet."
        ]
        return lines.joined(separator: "\n")
    }

    private let analysisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let analysisTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatTimecode(_ seconds: Double) -> String {
        let totalTenths = Int((seconds * 10).rounded())
        let hours = totalTenths / 36_000
        let minutes = (totalTenths % 36_000) / 600
        let remainingTenths = totalTenths % 600
        let wholeSeconds = remainingTenths / 10
        let tenths = remainingTenths % 10

        return String(format: "%02d:%02d:%02d.%d", hours, minutes, wholeSeconds, tenths)
    }

    // MARK: - Rich Text helpers

    private func appendTitle(_ text: String, to result: NSMutableAttributedString) {
        appendStyledLine(
            text,
            font: .boldSystemFont(ofSize: 18),
            color: .labelColor,
            spacingAfter: 6,
            to: result
        )
    }

    private func appendSectionHeader(_ text: String, to result: NSMutableAttributedString) {
        appendStyledLine(
            text,
            font: .boldSystemFont(ofSize: 13),
            color: .labelColor,
            spacingAfter: 4,
            to: result
        )
    }

    private func appendParagraph(_ text: String, emphasis: Bool = false, to result: NSMutableAttributedString) {
        appendStyledLine(
            text,
            font: emphasis ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 12),
            color: .labelColor,
            spacingAfter: 4,
            to: result
        )
    }

    private func appendLabelValue(
        _ label: String,
        _ value: String,
        valueFont: NSFont = .systemFont(ofSize: 12),
        valueColor: NSColor = .labelColor,
        to result: NSMutableAttributedString
    ) {
        let line = NSMutableAttributedString(
            string: label,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        line.append(NSAttributedString(string: " ", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]))

        line.append(NSAttributedString(string: value, attributes: [
            .font: valueFont,
            .foregroundColor: valueColor
        ]))

        appendAttributedLine(line, spacingAfter: 4, to: result)
    }

    private func appendBullets(_ items: [String], to result: NSMutableAttributedString) {
        for item in items {
            appendStyledLine(
                "• \(item)",
                font: .systemFont(ofSize: 12),
                color: .labelColor,
                spacingAfter: 2,
                to: result
            )
        }
    }

    private func appendDivider(to result: NSMutableAttributedString) {
        appendStyledLine(
            String(repeating: "─", count: 42),
            font: .systemFont(ofSize: 10),
            color: .separatorColor,
            spacingAfter: 6,
            to: result
        )
    }

    private func appendStyledLine(
        _ text: String,
        font: NSFont,
        color: NSColor,
        spacingAfter: CGFloat,
        to result: NSMutableAttributedString
    ) {
        let line = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])
        appendAttributedLine(line, spacingAfter: spacingAfter, to: result)
    }

    private func appendAttributedLine(
        _ line: NSMutableAttributedString,
        spacingAfter: CGFloat,
        to result: NSMutableAttributedString
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = spacingAfter
        paragraphStyle.lineSpacing = 1
        paragraphStyle.alignment = .left

        line.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: line.length))
        line.append(NSAttributedString(string: "\n"))
        result.append(line)
    }
}
