//
//  BlackFrameModule.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 8/3/26.
//


import Foundation

struct BlackFrameModule: QCModule {

    let name = "Black Frame Detection"
    private let scanner: FFmpegScanner

    init(scanner: FFmpegScanner = FFmpegScanner()) {
        self.scanner = scanner
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        context.statusHandler?("Scanning for Black Frames")
        defer { context.progressHandler?(1) }

        let windows = await scanner.detectBlackFrames(
            file: fileURL,
            progress: { progress in
                context.progressHandler?(progress)
            }
        )

        guard let first = windows.first else {
            return QCModuleResult(
                moduleName: name,
                outcome: .passed
            )
        }

        let durationSeconds = max(0, first.end - first.start)
        let details = String(
            format: "A black image section was detected from %@ to %@. Duration: %.2f seconds.",
            scanner.formatTimecode(first.start),
            scanner.formatTimecode(first.end),
            durationSeconds
        )

        let finding = QCFinding(
            severity: .failed,
            title: "Black Section Detected",
            details: details,
            recommendation: "Review the affected section and replace it from the source master if the black section is not intentional.",
            timeRange: first.start...first.end
        )

        return QCModuleResult(
            moduleName: name,
            outcome: .failed,
            findings: [finding]
        )
    }
}