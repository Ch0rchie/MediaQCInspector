// MediaFile.swift
import Foundation

struct MediaFile: Identifiable, Hashable {
    enum AnalysisStatus: String {
        case readyToAnalyze = "Ready to Analyze"
        case checkingDecoder = "Checking Decoder"
        case findingErrorWindow = "Finding Error Window"
        case generatingReport = "Generating Report"
        case complete = "Complete"
        case error = "Error"
    }

    enum AnalysisResult: String {
        case notYetAnalyzed = "Not Yet Analyzed"
        case inProgress = "In Progress"
        case passed = "Passed"
        case errorsFound = "Errors Found"
        case metadataFailed = "Metadata Failed"
    }

    let id = UUID()
    let url: URL

    var status: String = AnalysisStatus.readyToAnalyze.rawValue
    var result: String = AnalysisResult.notYetAnalyzed.rawValue
    var codec: String = "—"
    var resolution: String = "—"
    var frameRate: String = "—"
    var duration: String = "—"
    var fileSize: String = "—"
    var region: String = "—"
    var reviewWindow: String = "—"
    var analyzedAt: Date? = nil
    var report: String = ""
}
