//
//  DecodeValidationModule.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//


import Foundation

struct DecodeValidationModule: QCModule {

    let name = "Decode Validation"

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        let scanner = FFmpegScanner()

        // Existing scanner logic
        let report = try await scanner.scan(fileURL)

        var findings: [QCFinding] = []

        if report.result == .failed {

            findings.append(
                QCFinding(
                    severity: .failed,
                    title: "Decoder Errors Detected",
                    details: report.summary,
                    recommendation: report.recommendedAction
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