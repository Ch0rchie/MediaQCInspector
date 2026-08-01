//
//  FreezeFrameModule.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//

import Foundation

struct FreezeFrameModule: QCModule {

    let name = "Freeze Frame Detection"
    private let scanner: FFmpegScanner
    private let warningThresholdSeconds: Double
    private let failureThresholdSeconds: Double
    private let mergeGapSeconds: Double

    init(
        scanner: FFmpegScanner = FFmpegScanner(),
        warningThresholdSeconds: Double = 1.0,
        failureThresholdSeconds: Double = 2.0,
        mergeGapSeconds: Double = 0.5
    ) {
        self.scanner = scanner
        self.warningThresholdSeconds = warningThresholdSeconds
        self.failureThresholdSeconds = failureThresholdSeconds
        self.mergeGapSeconds = mergeGapSeconds
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        _ = context

        let detectedWindows = await scanner.detectFreezeFrames(
            file: fileURL,
            progress: { _ in }
        )

        let groupedWindows = Self.groupWindows(
            detectedWindows,
            mergeGapSeconds: mergeGapSeconds
        ).filter { ($0.end - $0.start) > 0 }

        guard !groupedWindows.isEmpty else {
            return QCModuleResult(
                moduleName: name,
                outcome: .passed
            )
        }

        var findings: [QCFinding] = []

        if groupedWindows.count > 1 {
            let totalDuration = groupedWindows.reduce(0.0) { partialResult, window in
                partialResult + max(0, window.end - window.start)
            }
            let longestDuration = groupedWindows
                .map { max(0, $0.end - $0.start) }
                .max() ?? 0

            findings.append(
                QCFinding(
                    severity: .info,
                    title: "Freeze Detection Summary",
                    details: "Detected \(groupedWindows.count) freeze sections. Total freeze duration: \(String(format: "%.2f", totalDuration)) seconds. Longest section: \(String(format: "%.2f", longestDuration)) seconds.",
                    recommendation: nil
                )
            )
        }

        for window in groupedWindows {
            let freezeDuration = max(0, window.end - window.start)

            let severity: QCFindingSeverity
            if freezeDuration >= failureThresholdSeconds {
                severity = .failed
            } else if freezeDuration >= warningThresholdSeconds {
                severity = .warning
            } else {
                severity = .info
            }

            let startTime = scanner.formatTimecode(window.start)
            let endTime = scanner.formatTimecode(window.end)

            findings.append(
                QCFinding(
                    severity: severity,
                    title: "Freeze Section Detected",
                    details: "A frozen image section was detected from \(startTime) to \(endTime). Duration: \(String(format: "%.2f", freezeDuration)) seconds.",
                    recommendation: "Review the affected section and replace it from the source master if the freeze is not intentional.",
                    timeRange: window.start...window.end
                )
            )
        }

        let outcome: QCOutcome
        if findings.contains(where: { $0.severity == .failed }) {
            outcome = .failed
        } else if findings.contains(where: { $0.severity == .warning }) {
            outcome = .warning
        } else {
            outcome = .passed
        }

        return QCModuleResult(
            moduleName: name,
            outcome: outcome,
            findings: findings
        )
    }
}

private extension FreezeFrameModule {

    static func groupWindows(
        _ windows: [TimeWindow],
        mergeGapSeconds: Double
    ) -> [TimeWindow] {
        let sorted = windows
            .filter { $0.end >= $0.start }
            .sorted { $0.start < $1.start }

        guard var current = sorted.first else { return [] }

        var grouped: [TimeWindow] = []

        for window in sorted.dropFirst() {
            if window.start <= current.end + mergeGapSeconds {
                current.end = max(current.end, window.end)
            } else {
                grouped.append(current)
                current = window
            }
        }

        grouped.append(current)
        return grouped
    }
}
