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

    func formatWindow(_ range: ClosedRange<Double>) -> String {
        formatWindow(TimeWindow(start: range.lowerBound, end: range.upperBound))
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
        report(for: file, engineResult: nil)
    }

    func report(for file: MediaFile, engineResult: QCEngineResult? = nil) -> String {
        if let engineResult {
            return modularReport(for: file, engineResult: engineResult)
        }

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
        attributedReport(for: file, engineResult: nil)
    }

    func attributedReport(for file: MediaFile, engineResult: QCEngineResult? = nil) -> NSAttributedString {
        let text = report(for: file, engineResult: engineResult)
        return styledAttributedReport(from: text)
    }

    // MARK: - Modular report

    private func modularReport(for file: MediaFile, engineResult: QCEngineResult) -> String {
        let problemModules = engineResult.moduleResults.filter { $0.outcome != .passed }

        var lines = reportHeader(for: file)
        lines += [
            "SUMMARY",
            "Result: \(outcomeLabel(for: engineResult.overallOutcome))",
            summarySentence(for: engineResult.overallOutcome)
        ]

        lines += [
            "",
            String(repeating: "─", count: 42),
            "VALIDATION RESULTS"
        ]

        for moduleResult in engineResult.moduleResults {
            lines.append("- \(moduleResult.moduleName) (\(outcomeLabel(for: moduleResult.outcome)))")
        }

        lines += [
            "",
            String(repeating: "─", count: 42),
            "QC FINDINGS"
        ]

        if problemModules.isEmpty {
            lines.append("None")
            return lines.joined(separator: "\n")
        }

        for moduleResult in problemModules {
            lines.append("- \(moduleResult.moduleName) (\(outcomeLabel(for: moduleResult.outcome)))")
        }

        for moduleResult in problemModules {
            lines += [
                "",
                moduleResult.moduleName,
                "Result: \(outcomeLabel(for: moduleResult.outcome))",
                moduleSummarySentence(for: moduleResult.moduleName, outcome: moduleResult.outcome)
            ]

            if moduleResult.findings.isEmpty {
                lines.append("No findings were reported.")
                continue
            }

            lines.append("Findings:")

            for finding in moduleResult.findings {
                lines.append("- \(finding.title)")

                let trimmedDetails = finding.details.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedDetails.isEmpty {
                    lines.append("  Details: \(trimmedDetails)")
                }

                if let timeRange = finding.timeRange {
                    lines.append("  Affected Region: \(formatWindow(timeRange))")
                }

                let recommendation = finding.recommendation ?? defaultRecommendation(for: moduleResult.moduleName)
                if let recommendation {
                    lines.append("  Recommended Action: \(recommendation)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func summarySentence(for outcome: QCOutcome) -> String {
        switch outcome {
        case .passed:
            return "Technical validation completed successfully."
        case .warning:
            return "Technical validation completed with warnings."
        case .failed:
            return "Technical validation completed with one or more QC findings requiring review."
        }
    }

    private func moduleSummarySentence(for moduleName: String, outcome: QCOutcome) -> String {
        let lower = moduleName.lowercased()

        switch outcome {
        case .passed:
            return "No findings were reported."
        case .warning:
            return "\(moduleName) identified a potential issue."
        case .failed:
            if lower.contains("decode") {
                return "Technical validation identified one or more video decode errors."
            } else if lower.contains("freeze") {
                return "Freeze frame detection identified one or more freeze frames."
            } else if lower.contains("black") {
                return "Black frame detection identified one or more black frames."
            } else if lower.contains("metadata") {
                return "Metadata validation identified one or more metadata issues."
            } else {
                return "\(moduleName) identified one or more issues."
            }
        }
    }

    private func outcomeLabel(for outcome: QCOutcome) -> String {
        switch outcome {
        case .passed:
            return "PASS"
        case .warning:
            return "WARNING"
        case .failed:
            return "FAIL"
        }
    }

    private func defaultRecommendation(for moduleName: String) -> String? {
        let lower = moduleName.lowercased()

        if lower.contains("decode") {
            return "Please review the original timeline and regenerate this portion of the ProRes master, or provide a newly exported master from the source project. After replacement, the file should be analyzed again to confirm that no ProRes decode errors remain."
        } else if lower.contains("freeze") {
            return "Review the affected section to determine whether the freeze is intentional. If unintended, regenerate the affected portion from the source timeline before delivery."
        } else if lower.contains("black") {
            return "Review the affected section to determine whether the black segment is intentional. If not, regenerate or replace the affected portion before delivery."
        } else if lower.contains("metadata") {
            return "Verify the source media metadata, correct the source export if needed, and analyze the file again."
        } else {
            return "Review the affected section and regenerate or replace it before analyzing again."
        }
    }

    // MARK: - Legacy report path

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
            "SUMMARY",
            "Result: PASS",
            "Technical validation completed successfully.",
            "No video decode errors were detected."
        ]
        return lines.joined(separator: "\n")
    }

    private func failedReport(for file: MediaFile) -> String {
        let primaryRegion = file.region == "—" ? "Unavailable" : file.region
        let reviewWindow = file.reviewWindow == "—" ? primaryRegion : file.reviewWindow

        var lines = reportHeader(for: file)
        lines += [
            "SUMMARY",
            "Result: FAIL",
            "Technical validation identified one or more video decode errors.",
            "",
            "QC FINDINGS",
            "",
            "Decode Validation",
            "Result: FAIL",
            "Technical validation identified one or more video decode errors.",
            "Findings:",
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
            "SUMMARY",
            "Result: METADATA FAILED",
            "Metadata extraction failed.",
            "The file could not be fully analyzed."
        ]
        return lines.joined(separator: "\n")
    }

    private func pendingReport(for file: MediaFile) -> String {
        var lines = reportHeader(for: file)
        lines += [
            "SUMMARY",
            "The file has not been analyzed yet."
        ]
        return lines.joined(separator: "\n")
    }

    // MARK: - Dates / Timecodes

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

    // MARK: - Attributed formatting

    private func styledAttributedReport(from text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: .newlines)

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextLine = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines) : nil

            if line.isEmpty {
                result.append(NSAttributedString(string: "\n"))
                continue
            }

            let isTitle = line == "Technical Validation Report"
            let isKnownSectionHeader = [
                "SUMMARY",
                "VALIDATION RESULTS",
                "QC FINDINGS",
                "Findings:",
                "Affected Region",
                "Recommended Action"
            ].contains(line)

            let isModuleHeader = !line.contains(":")
                && !line.hasPrefix("-")
                && !line.hasPrefix("•")
                && nextLine?.hasPrefix("Result:") == true

            let isResultLine = line.hasPrefix("Result:")
            let isLabelLine = line.hasPrefix("File:")
                || line.hasPrefix("Analysis Date:")
                || line.hasPrefix("Analysis Time:")
                || line.hasPrefix("Primary error region:")
                || line.hasPrefix("Editorial review window:")
                || line.hasPrefix("Details:")
                || line.hasPrefix("Affected Region:")
                || line.hasPrefix("Recommended Action:")
                || line.hasPrefix("Modules Requiring Attention:")
                || line.hasPrefix("Modules Evaluated:")

            let isBullet = line.hasPrefix("- ") || line.hasPrefix("• ")

            let font: NSFont
            let color: NSColor

            if isTitle {
                font = .boldSystemFont(ofSize: 18)
                color = .labelColor
            } else if isKnownSectionHeader || isModuleHeader {
                font = .boldSystemFont(ofSize: 13)
                color = .labelColor
            } else if isResultLine {
                font = .boldSystemFont(ofSize: 12)
                if line.contains("PASS") {
                    color = .systemGreen
                } else if line.contains("FAIL") {
                    color = .systemRed
                } else if line.contains("WARNING") {
                    color = .systemOrange
                } else {
                    color = .labelColor
                }
            } else if isLabelLine {
                font = .boldSystemFont(ofSize: 12)
                color = .secondaryLabelColor
            } else if isBullet {
                font = .systemFont(ofSize: 12)
                color = .labelColor
            } else {
                font = .systemFont(ofSize: 12)
                color = .labelColor
            }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = isTitle ? 6 : 4
            paragraphStyle.lineSpacing = 1
            paragraphStyle.alignment = .left

            let attributedLine = NSAttributedString(
                string: line,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle
                ]
            )

            result.append(attributedLine)
            result.append(NSAttributedString(string: "\n"))
        }

        return result
    }
}
