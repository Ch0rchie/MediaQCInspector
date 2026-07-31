//
//  QCModel.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/29/26.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

@MainActor
final class QCModel: NSObject, ObservableObject {
    @Published var files: [MediaFile] = []
    @Published var selectedFileID: MediaFile.ID?
    @Published var isDropTarget = false
    @Published var isBusy = false
    @Published var progress: Double = 0
    @Published var statusText: String = "Ready to Analyze"
    @Published var elapsedText: String = "00:00"

    private let scanner = FFmpegScanner()
    private let reportFormatter = ReportFormatter()
    private var elapsedTask: Task<Void, Never>?
    private var analysisStartedAt: Date?

    var selectedFile: MediaFile? {
        guard let selectedFileID else { return nil }
        return files.first { $0.id == selectedFileID }
    }

    var canCopyReport: Bool {
        selectedFile?.report.isEmpty == false || files.contains(where: { !$0.report.isEmpty })
    }

    var canRemoveSelectedFile: Bool {
        selectedFileID != nil && !isBusy
    }

    var selectedReportTitle: String {
        selectedFile?.url.lastPathComponent ?? "No File Selected"
    }

    var selectedAnalysisDate: String {
        reportFormatter.analysisDateString(for: selectedFile?.analyzedAt)
    }

    var selectedAnalysisTime: String {
        reportFormatter.analysisTimeString(for: selectedFile?.analyzedAt)
    }

    var selectedReportText: String {
        guard let file = selectedFile else {
            return "Select a file to preview its report."
        }

        if !file.report.isEmpty {
            return file.report
        }

        return "The report will appear here after analysis."
    }

    func addFiles(_ urls: [URL]) {
        let movs = urls.filter { $0.pathExtension.lowercased() == "mov" }
        guard !movs.isEmpty else { return }

        for url in movs where !files.contains(where: { $0.url == url }) {
            files.append(MediaFile(url: url))
            loadMetadata(for: url)
        }

        if selectedFileID == nil {
            selectedFileID = files.first?.id
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie]

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.addFiles(panel.urls)
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let self else { return }

                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }

                guard let url else { return }
                DispatchQueue.main.async {
                    self.addFiles([url])
                }
            }

            accepted = true
        }

        return accepted
    }

    func removeSelectedFile() {
        guard !isBusy, let selectedFileID else { return }
        guard let index = files.firstIndex(where: { $0.id == selectedFileID }) else { return }

        files.remove(at: index)

        if files.isEmpty {
            self.selectedFileID = nil
        } else {
            let nextIndex = min(index, files.count - 1)
            self.selectedFileID = files[nextIndex].id
        }

        statusText = "File removed"
    }

    func analyze() {
        guard !files.isEmpty else { return }

        isBusy = true
        progress = 0
        statusText = "Analyzing..."
        startElapsedTimer()

        let totalFiles = files.count

        for index in files.indices {
            files[index].status = MediaFile.AnalysisStatus.checkingDecoder.rawValue
            files[index].result = MediaFile.AnalysisResult.inProgress.rawValue
            files[index].region = "—"
            files[index].reviewWindow = "—"
        }

        Task { [scanner] in
            let engine = QCEngine(modules: [DecodeValidationModule()])

            for index in files.indices {
                let url = files[index].url

                await MainActor.run {
                    guard index < self.files.count else { return }
                    self.files[index].status = MediaFile.AnalysisStatus.checkingDecoder.rawValue
                    self.files[index].result = MediaFile.AnalysisResult.inProgress.rawValue
                    self.statusText = "Analyzing..."
                }

                do {
                    let engineResult = try await engine.run(fileURL: url)

                    var result = MediaFile.AnalysisResult.passed.rawValue
                    var primaryRegion = "—"
                    var reviewWindow = "—"

                    if engineResult.overallOutcome != .passed {
                        result = MediaFile.AnalysisResult.errorsFound.rawValue

                        if let finding = engineResult.findings.first,
                           let timeRange = finding.timeRange {
                            // DecodeValidationModule currently stores the expanded editorial review
                            // window in `timeRange`, so we reverse it here to preserve the existing
                            // region/review window formatting.
                            let expandedWindow = TimeWindow(
                                start: timeRange.lowerBound,
                                end: timeRange.upperBound
                            )
                            let primaryWindow = primaryWindow(fromReviewWindow: expandedWindow)
                            primaryRegion = scanner.formatWindow(primaryWindow)
                            reviewWindow = reportFormatter.formatWindow(expandedWindow)
                        }
                    }

                    await MainActor.run {
                        guard index < self.files.count else { return }

                        self.files[index].status = MediaFile.AnalysisStatus.generatingReport.rawValue
                        self.files[index].result = MediaFile.AnalysisResult.inProgress.rawValue
                        self.statusText = "Generating Report..."

                        self.files[index].status = MediaFile.AnalysisStatus.complete.rawValue
                        self.files[index].result = result
                        self.files[index].region = primaryRegion
                        self.files[index].reviewWindow = reviewWindow
                        self.files[index].analyzedAt = Date()

                        let updated = self.files[index]
                        self.files[index].report = self.reportFormatter.report(for: updated)

                        self.progress = Double(index + 1) / Double(totalFiles)
                    }
                } catch {
                    await MainActor.run {
                        guard index < self.files.count else { return }

                        self.files[index].status = MediaFile.AnalysisStatus.error.rawValue
                        self.files[index].result = MediaFile.AnalysisResult.errorsFound.rawValue
                        self.files[index].region = "—"
                        self.files[index].reviewWindow = "—"
                        self.files[index].analyzedAt = Date()

                        let updated = self.files[index]
                        self.files[index].report = self.reportFormatter.report(for: updated)

                        self.progress = Double(index + 1) / Double(totalFiles)
                    }
                }
            }

            await MainActor.run {
                self.statusText = "Complete"
                self.isBusy = false
                self.stopElapsedTimer()
            }
        }
    }

    func copyReport() {
        let file = selectedFile ?? files.first(where: { !$0.report.isEmpty })
        guard let file else {
            statusText = "No report available"
            return
        }

        let report = file.report.isEmpty ? reportFormatter.report(for: file) : file.report
        guard !report.isEmpty else {
            statusText = "No report available"
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        statusText = "Report copied"
    }

    func clear() {
        files.removeAll()
        selectedFileID = nil
        progress = 0
        statusText = "Ready to Analyze"
        elapsedText = "00:00"
        isBusy = false
        stopElapsedTimer()
    }

    private func loadMetadata(for url: URL) {
        Task { [scanner] in
            let metadata = await scanner.readMetadata(for: url)

            await MainActor.run {
                guard let index = self.files.firstIndex(where: { $0.url == url }) else { return }

                if let metadata {
                    self.files[index].codec = metadata.codec
                    self.files[index].resolution = metadata.resolution
                    self.files[index].frameRate = metadata.frameRate
                    self.files[index].duration = metadata.duration
                    self.files[index].fileSize = metadata.fileSize
                    self.files[index].status = MediaFile.AnalysisStatus.readyToAnalyze.rawValue
                    self.files[index].result = MediaFile.AnalysisResult.notYetAnalyzed.rawValue
                    self.files[index].region = "—"
                    self.files[index].reviewWindow = "—"
                    self.files[index].report = ""
                } else {
                    self.files[index].status = MediaFile.AnalysisStatus.error.rawValue
                    self.files[index].result = MediaFile.AnalysisResult.metadataFailed.rawValue
                    self.files[index].region = "—"
                    self.files[index].reviewWindow = "—"
                    self.files[index].analyzedAt = Date()
                    self.files[index].report = self.reportFormatter.report(for: self.files[index])
                }
            }
        }
    }

    private func primaryWindow(fromReviewWindow reviewWindow: TimeWindow) -> TimeWindow {
        let start = max(0, reviewWindow.start + 1.0)
        let end = max(start + 0.5, reviewWindow.end - 0.5)
        return TimeWindow(start: start, end: end)
    }

    private func startElapsedTimer() {
        analysisStartedAt = Date()
        elapsedText = "00:00"

        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                guard !Task.isCancelled else { break }

                await MainActor.run {
                    guard let self, let startedAt = self.analysisStartedAt else { return }
                    let seconds = Int(Date().timeIntervalSince(startedAt))
                    let minutes = seconds / 60
                    let remainder = seconds % 60
                    self.elapsedText = String(format: "%02d:%02d", minutes, remainder)
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTask?.cancel()
        elapsedTask = nil
        analysisStartedAt = nil
    }
}
