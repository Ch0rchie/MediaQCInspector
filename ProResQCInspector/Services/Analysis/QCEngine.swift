//
//  QCEngine.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//

import Foundation

struct QCEngineResult: Codable, Hashable, Sendable {
    let fileURL: URL
    let moduleResults: [QCModuleResult]
    let findings: [QCFinding]
    let overallOutcome: QCOutcome

    var moduleCount: Int {
        moduleResults.count
    }

    var findingCount: Int {
        findings.count
    }

    var passedModuleCount: Int {
        moduleResults.filter { $0.outcome == .passed }.count
    }

    var warningModuleCount: Int {
        moduleResults.filter { $0.outcome == .warning }.count
    }

    var failedModuleCount: Int {
        moduleResults.filter { $0.outcome == .failed }.count
    }

    init(fileURL: URL, moduleResults: [QCModuleResult]) {
        self.fileURL = fileURL
        self.moduleResults = moduleResults
        self.findings = moduleResults.flatMap { $0.findings }
        self.overallOutcome = Self.calculateOverallOutcome(from: moduleResults)
    }

    private static func calculateOverallOutcome(from moduleResults: [QCModuleResult]) -> QCOutcome {
        if moduleResults.contains(where: { $0.outcome == .failed }) {
            return .failed
        }

        if moduleResults.contains(where: { $0.outcome == .warning }) {
            return .warning
        }

        return .passed
    }
}

struct QCEngine: Sendable {
    let scanner: FFmpegScanner
    let modules: [any QCModule]

    init(
        scanner: FFmpegScanner = FFmpegScanner(),
        modules: [any QCModule]? = nil
    ) {
        self.scanner = scanner
        self.modules = modules ?? [
            DecodeValidationModule(scanner: scanner),
            MetadataValidationModule(),
            FreezeFrameModule(scanner: scanner),
            BlackFrameModule(scanner: scanner)
        ]
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext = QCAnalysisContext(),
        progressHandler: @escaping @Sendable (Double) -> Void = { _ in },
        statusHandler: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> QCEngineResult {

        let totalModules = max(modules.count, 1)
        var moduleResults: [QCModuleResult] = []
        moduleResults.reserveCapacity(modules.count)

        progressHandler(0)

        for (index, module) in modules.enumerated() {
            try Task.checkCancellation()

            let moduleStart = Double(index) / Double(totalModules)
            let moduleSpan = 1.0 / Double(totalModules)

            let moduleContext = QCAnalysisContext(
                deliveryProfileName: context.deliveryProfileName,
                deliveryProfile: context.deliveryProfile,
                progressHandler: { moduleProgress in
                    let clamped = max(0, min(1, moduleProgress))
                    progressHandler(min(1, moduleStart + (clamped * moduleSpan)))
                },
                statusHandler: { status in
                    statusHandler(status)
                }
            )

            statusHandler(module.name)

            do {
                let result = try await module.analyze(
                    fileURL: fileURL,
                    context: moduleContext
                )
                moduleResults.append(result)
            } catch {
                moduleResults.append(
                    Self.failedResult(
                        moduleName: module.name,
                        error: error
                    )
                )
            }

            progressHandler(min(1, moduleStart + moduleSpan))
        }

        progressHandler(1)

        return QCEngineResult(
            fileURL: fileURL,
            moduleResults: moduleResults
        )
    }

    func run(
        fileURL: URL,
        context: QCAnalysisContext = QCAnalysisContext(),
        progressHandler: @escaping @Sendable (Double) -> Void = { _ in },
        statusHandler: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> QCEngineResult {
        try await analyze(
            fileURL: fileURL,
            context: context,
            progressHandler: progressHandler,
            statusHandler: statusHandler
        )
    }
}

private extension QCEngine {
    static func failedResult(
        moduleName: String,
        error: Error
    ) -> QCModuleResult {
        QCModuleResult(
            moduleName: moduleName,
            outcome: .failed,
            findings: [
                QCFinding(
                    severity: .failed,
                    title: "Module Execution Failed",
                    details: error.localizedDescription,
                    recommendation: "Inspect the module implementation and retry the analysis."
                )
            ]
        )
    }
}
