//
//  QCOutcome.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//

import Foundation

enum QCOutcome: String, Codable, CaseIterable, Sendable {
    case passed
    case warning
    case failed
}

enum QCFindingSeverity: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case failed
}

struct QCFinding: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let severity: QCFindingSeverity
    let title: String
    let details: String
    let recommendation: String?
    let timeRange: ClosedRange<Double>?

    init(
        id: UUID = UUID(),
        severity: QCFindingSeverity,
        title: String,
        details: String,
        recommendation: String? = nil,
        timeRange: ClosedRange<Double>? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.details = details
        self.recommendation = recommendation
        self.timeRange = timeRange
    }
}

struct QCAnalysisContext: Sendable {
    var deliveryProfileName: String? = nil
    var deliveryProfile: DeliveryProfile? = nil
    var progressHandler: (@Sendable (Double) -> Void)? = nil
    var statusHandler: (@Sendable (String) -> Void)? = nil

    init(
        deliveryProfileName: String? = nil,
        deliveryProfile: DeliveryProfile? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
        statusHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.deliveryProfileName = deliveryProfileName
        self.deliveryProfile = deliveryProfile
        self.progressHandler = progressHandler
        self.statusHandler = statusHandler
    }
}

struct QCModuleResult: Codable, Hashable, Sendable {
    let moduleName: String
    let outcome: QCOutcome
    let findings: [QCFinding]

    init(
        moduleName: String,
        outcome: QCOutcome,
        findings: [QCFinding] = []
    ) {
        self.moduleName = moduleName
        self.outcome = outcome
        self.findings = findings
    }

    var hasFindings: Bool {
        !findings.isEmpty
    }
}

protocol QCModule: Sendable {
    var name: String { get }
    func analyze(fileURL: URL, context: QCAnalysisContext) async throws -> QCModuleResult
}
