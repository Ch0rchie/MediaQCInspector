//
//  QCEngineResult.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//


import Foundation

struct QCEngineResult {
    let moduleResults: [QCModuleResult]

    var overallOutcome: QCOutcome {
        if moduleResults.contains(where: { $0.outcome == .failed }) {
            return .failed
        }

        if moduleResults.contains(where: { $0.outcome == .warning }) {
            return .warning
        }

        return .passed
    }

    var findings: [QCFinding] {
        moduleResults.flatMap(\.findings)
    }

    var hasFindings: Bool {
        moduleResults.contains(where: { $0.hasFindings })
    }
}

final class QCEngine {
    private let modules: [any QCModule]

    init(modules: [any QCModule]) {
        self.modules = modules
    }

    func run(
        fileURL: URL,
        context: QCAnalysisContext = QCAnalysisContext(),
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> QCEngineResult {
        guard !modules.isEmpty else {
            progress(1)
            return QCEngineResult(moduleResults: [])
        }

        var results: [QCModuleResult] = []
        results.reserveCapacity(modules.count)

        for (index, module) in modules.enumerated() {
            try Task.checkCancellation()

            let result = try await module.analyze(fileURL: fileURL, context: context)
            results.append(result)

            progress(Double(index + 1) / Double(modules.count))
        }

        return QCEngineResult(moduleResults: results)
    }
}
