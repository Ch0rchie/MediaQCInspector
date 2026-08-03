import Foundation

struct DecodeValidationModule: QCModule {

    let name = "Decode Validation"
    private let scanner: FFmpegScanner

    init(scanner: FFmpegScanner = FFmpegScanner()) {
        self.scanner = scanner
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        context.statusHandler?("Checking Decoder")
        defer { context.progressHandler?(1) }

        let validation = await scanner.validateFile(
            fileURL,
            progress: { progress in
                context.progressHandler?(progress * 0.5)
            }
        )

        guard validation.errors.isEmpty else {
            var findings: [QCFinding] = []
            var reviewRange: ClosedRange<Double>?

            if let duration = validation.duration {
                context.statusHandler?("Finding Error Window")

                let windows = await scanner.scanForBadWindows(
                    file: fileURL,
                    durationSeconds: duration,
                    progress: { progress in
                        context.progressHandler?(0.5 + (progress * 0.5))
                    }
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
