import Foundation

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

    private func reportHeader(for file: MediaFile) -> [String] {
        var lines: [String] = [
            "Technical Validation Report",
            "",
            "File:",
            file.url.lastPathComponent,
            ""
        ]

        if file.analyzedAt != nil {
            lines += analysisTimestampSection(for: file)
        }

        return lines
    }

    private func analysisTimestampSection(for file: MediaFile) -> [String] {
        [
            "Analysis Date:",
            analysisDateString(for: file.analyzedAt),
            "",
            "Analysis Time:",
            analysisTimeString(for: file.analyzedAt),
            ""
        ]
    }

    private func passedReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "",
            "Technical validation completed successfully.",
            "",
            "Result: PASS",
            "",
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
            "",
            "Technical validation identified one or more video decode errors.",
            "",
            "Result: FAIL",
            "",
            "Video decode errors were detected.",
            "",
            "Findings",
            "",
            "Reported decoder errors:",
            "invalid frame header",
            "Error submitting packet to decoder: Invalid data found when processing input",
            "",
            "Affected Region",
            "",
            "Primary error region: \(primaryRegion)",
            "For editorial purposes, review approximately:",
            reviewWindow,
            "to ensure the entire affected section is replaced or regenerated.",
            "",
            "Recommended Action",
            "",
            "Please review the original timeline and regenerate this portion of the ProRes master, or provide a newly exported master from the source project. After replacement, the file should be analyzed again to confirm that no ProRes decode errors remain."
        ]
        return lines.joined(separator: "\n")
    }

    private func metadataFailedReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "",
            "Metadata extraction failed.",
            "",
            "Result: METADATA FAILED",
            "",
            "The file could not be fully analyzed."
        ]
        return lines.joined(separator: "\n")
    }

    private func pendingReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "Summary",
            "",
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
}
