import Foundation

struct DecodeValidationModule: QCModule {

    let name = "Decode Validation"

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        let scanner = FFmpegScanner()

        let validation = await scanner.validateFile(
            fileURL,
            progress: { _ in }
        )

        guard validation.errors.isEmpty else {

            var findings: [QCFinding] = []

            var reviewRange: ClosedRange<Double>?

            if let duration = validation.duration {

                let windows = await scanner.scanForBadWindows(
                    file: fileURL,
                    durationSeconds: duration,
                    progress: { _ in }
                )

                if let first = windows.first {

                    let reviewWindow = scanner.editorialReviewWindow(
                        for: first,
                        durationSeconds: duration
                    )

                    reviewRange = reviewWindow.start...reviewWindow.end
                }
            }

            findings.append(
                QCFinding(
                    severity: .failed,
                    title: "Decoder Errors Detected",
                    details: validation.errors.joined(separator: "\n"),
                    recommendation: "Review the affected media section and replace it from the source master.",
                    timeRange: reviewRange
                )
            )

            return QCModuleResult(
                moduleName: name,
                outcome: .failed,
                findings: findings
            )
        }

        return QCModuleResult(
            moduleName: name,
            outcome: .passed
        )
    }
}
