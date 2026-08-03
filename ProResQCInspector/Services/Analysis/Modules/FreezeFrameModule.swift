import Foundation

struct FreezeFrameModule: QCModule {

    let name = "Freeze Frame Detection"
    private let scanner: FFmpegScanner

    init(scanner: FFmpegScanner = FFmpegScanner()) {
        self.scanner = scanner
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        context.statusHandler?("Scanning for Freeze Frames")

        // Run freeze detection first.
        let freezeWindows = await scanner.detectFreezeFrames(
            file: fileURL,
            progress: { progress in
                context.progressHandler?(progress * 0.6)
            }
        )

        // Run black detection so we can suppress false freeze hits caused by black sections.
        context.statusHandler?("Checking for Black Frames")

        let blackWindows = await scanner.detectBlackFrames(
            file: fileURL,
            progress: { progress in
                context.progressHandler?(0.6 + (progress * 0.4))
            }
        )

        // Remove any freeze windows that overlap a black window.
        let nonBlackFreezeWindows = freezeWindows.filter { freezeWindow in
            !blackWindows.contains(where: { blackWindow in
                overlaps(freezeWindow, blackWindow)
            })
        }

        defer { context.progressHandler?(1) }

        guard let first = nonBlackFreezeWindows.first else {
            return QCModuleResult(
                moduleName: name,
                outcome: .passed
            )
        }

        let durationSeconds = max(0, first.end - first.start)
        let details = String(
            format: "A frozen image section was detected from %@ to %@. Duration: %.2f seconds.",
            scanner.formatTimecode(first.start),
            scanner.formatTimecode(first.end),
            durationSeconds
        )

        let finding = QCFinding(
            severity: .failed,
            title: "Freeze Section Detected",
            details: details,
            recommendation: "Review the affected section and replace it from the source master if the freeze is not intentional.",
            timeRange: first.start...first.end
        )

        return QCModuleResult(
            moduleName: name,
            outcome: .failed,
            findings: [finding]
        )
    }

    private func overlaps(_ lhs: TimeWindow, _ rhs: TimeWindow) -> Bool {
        lhs.start < rhs.end && rhs.start < lhs.end
    }
}
