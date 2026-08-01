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

struct QCEngine {

    let modules: [any QCModule]

    init(
        modules: [any QCModule] = [
            DecodeValidationModule(),
            MetadataValidationModule(),
            FreezeFrameModule()
        ]
    ) {
        self.modules = modules
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext = QCAnalysisContext()
    ) async throws -> QCEngineResult {

        var moduleResults: [QCModuleResult] = []
        moduleResults.reserveCapacity(modules.count)

        for module in modules {
            do {
                let result = try await module.analyze(
                    fileURL: fileURL,
                    context: context
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
        }

        return QCEngineResult(
            fileURL: fileURL,
            moduleResults: moduleResults
        )
    }

    func run(
        fileURL: URL,
        context: QCAnalysisContext = QCAnalysisContext()
    ) async throws -> QCEngineResult {
        try await analyze(fileURL: fileURL, context: context)
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
