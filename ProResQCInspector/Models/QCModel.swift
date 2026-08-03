//
//  QCModel.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//

import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers
import CoreText

@MainActor
final class QCModel: ObservableObject {

    @Published var files: [MediaFile] = []
    @Published var selectedFileID: MediaFile.ID?
    @Published var progress: Double = 0
    @Published var statusText: String = "Ready to Analyze"
    @Published var elapsedText: String = "00:00"
    @Published var remainingText: String = "--:--"
    @Published var isBusy: Bool = false
    @Published var isDropTarget: Bool = false

    private let scanner: FFmpegScanner
    private lazy var engine = QCEngine(scanner: scanner)
    private let reportFormatter: ReportFormatter

    private var analysisTask: Task<Void, Never>?
    private var elapsedTimerTask: Task<Void, Never>?
    private var analysisStartDate: Date?

    private enum PendingQueueAction {
        case removeSelectedFile
        case clearQueue
    }

    private var pendingQueueAction: PendingQueueAction?
    private var currentAnalysisFileID: MediaFile.ID?

    private static let analysisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(
        scanner: FFmpegScanner = FFmpegScanner(),
        reportFormatter: ReportFormatter = ReportFormatter()
    ) {
        self.scanner = scanner
        self.reportFormatter = reportFormatter
    }

    var selectedFile: MediaFile? {
        guard let selectedFileID else { return nil }
        return files.first { $0.id == selectedFileID }
    }

    var analysisStartedAt: Date? {
        analysisStartDate
    }

    var canCopyReport: Bool {
        !selectedReportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedAnalysisDate: String {
        guard let date = selectedFile?.analyzedAt else { return "—" }
        return Self.analysisDateFormatter.string(from: date)
    }

    var selectedReportText: String {
        selectedFile?.report ?? ""
    }

    var selectedReportTitle: String {
        selectedFile?.url.deletingPathExtension().lastPathComponent ?? "Report"
    }

    var selectedReportAttributedText: AttributedString {
        guard let file = selectedFile else { return AttributedString() }
        return AttributedString(reportFormatter.attributedReport(for: file))
    }

    var canRemoveSelectedFile: Bool {
        selectedFileID != nil
    }

    var selectedFileIsCurrentlyAnalyzing: Bool {
        guard let file = selectedFile else { return false }

        return file.result == MediaFile.AnalysisResult.inProgress.rawValue
            || ![
                MediaFile.AnalysisStatus.readyToAnalyze.rawValue,
                MediaFile.AnalysisStatus.complete.rawValue,
                MediaFile.AnalysisStatus.error.rawValue
            ].contains(file.status)
    }

    func addFiles(_ urls: [URL]) {
        let newFiles = urls.map { MediaFile(url: $0) }
        files.append(contentsOf: newFiles)

        if selectedFileID == nil {
            selectedFileID = files.first?.id
        }

        for url in urls {
            loadMetadata(for: url)
        }
    }

    func selectFile(_ file: MediaFile?) {
        selectedFileID = file?.id
    }

    func removeSelectedFile() {
        guard selectedFileID != nil else { return }

        if isBusy {
            pendingQueueAction = .removeSelectedFile
            stopAnalysis()
            return
        }

        removeSelectedFileImmediately()
    }

    func clear() {
        guard !files.isEmpty else { return }

        if isBusy {
            pendingQueueAction = .clearQueue
            stopAnalysis()
            return
        }

        clearImmediately()
    }

    func analyze() {
        guard !files.isEmpty, !isBusy else { return }

        let filesToAnalyze = files
            .filter { $0.result == MediaFile.AnalysisResult.notYetAnalyzed.rawValue }
            .map { ($0.id, $0.url) }

        guard !filesToAnalyze.isEmpty else {
            statusText = "Complete"
            return
        }

        pendingQueueAction = nil
        scanner.resetCancellation()

        isBusy = true
        progress = 0
        statusText = "Analyzing..."
        elapsedText = "00:00"
        remainingText = "--:--"
        analysisStartDate = Date()
        startElapsedTimer()
        refreshTiming()

        let totalFiles = max(filesToAnalyze.count, 1)
        let engine = self.engine

        for item in filesToAnalyze {
            if let index = fileIndex(for: item.0) {
                files[index].status = MediaFile.AnalysisStatus.checkingDecoder.rawValue
                files[index].result = MediaFile.AnalysisResult.inProgress.rawValue
                files[index].region = "—"
                files[index].reviewWindow = "—"
            }
        }

        analysisTask?.cancel()
        analysisTask = Task { [weak self, filesToAnalyze, totalFiles, engine] in
            guard let self else { return }

            do {
                for (filePosition, item) in filesToAnalyze.enumerated() {
                    try Task.checkCancellation()

                    let fileID = item.0
                    let url = item.1

                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.currentAnalysisFileID = fileID
                        self.updateStatus(
                            for: fileID,
                            status: MediaFile.AnalysisStatus.checkingDecoder.rawValue
                        )
                    }

                    let engineResult = try await engine.run(
                        fileURL: url,
                        context: QCAnalysisContext(),
                        progressHandler: { [weak self] moduleProgress in
                            Task { @MainActor in
                                self?.updateProgress(
                                    for: fileID,
                                    filePosition: filePosition,
                                    totalFiles: totalFiles,
                                    moduleProgress: moduleProgress
                                )
                            }
                        },
                        statusHandler: { [weak self] status in
                            Task { @MainActor in
                                self?.updateStatus(for: fileID, status: status)
                            }
                        }
                    )

                    try Task.checkCancellation()

                    var result = MediaFile.AnalysisResult.passed.rawValue
                    var primaryRegion = "—"
                    var reviewWindow = "—"

                    if engineResult.overallOutcome != .passed {
                        result = MediaFile.AnalysisResult.errorsFound.rawValue

                        if let finding = engineResult.findings.first,
                           let timeRange = finding.timeRange {
                            let expandedWindow = TimeWindow(
                                start: timeRange.lowerBound,
                                end: timeRange.upperBound
                            )

                            let primaryWindow = self.primaryWindow(fromReviewWindow: expandedWindow)
                            primaryRegion = self.scanner.formatWindow(primaryWindow)
                            reviewWindow = self.reportFormatter.formatWindow(expandedWindow)
                        }
                    }

                    await MainActor.run { [weak self] in
                        guard let self, let index = self.fileIndex(for: fileID) else { return }

                        self.files[index].status = MediaFile.AnalysisStatus.generatingReport.rawValue
                        self.statusText = "Generating Report..."

                        self.files[index].status = MediaFile.AnalysisStatus.complete.rawValue
                        self.files[index].result = result
                        self.files[index].region = primaryRegion
                        self.files[index].reviewWindow = reviewWindow
                        self.files[index].analyzedAt = Date()

                        let updated = self.files[index]
                        self.files[index].report = self.reportFormatter.report(for: updated)

                        self.progress = Double(filePosition + 1) / Double(totalFiles)
                        self.currentAnalysisFileID = nil
                    }
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.statusText = "Complete"
                    self.isBusy = false
                    self.stopElapsedTimer()
                    self.analysisTask = nil
                    self.performPendingQueueActionIfNeeded()
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self else { return }

                    if let currentAnalysisFileID = self.currentAnalysisFileID {
                        self.resetFileAfterCancellation(fileID: currentAnalysisFileID)
                    }

                    self.statusText = "Stopped"
                    self.isBusy = false
                    self.stopElapsedTimer()
                    self.analysisTask = nil
                    self.currentAnalysisFileID = nil
                    self.scanner.resetCancellation()
                    self.performPendingQueueActionIfNeeded()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }

                    self.statusText = "Analysis failed"
                    self.isBusy = false
                    self.stopElapsedTimer()
                    self.analysisTask = nil
                    self.currentAnalysisFileID = nil
                    self.scanner.resetCancellation()
                    self.performPendingQueueActionIfNeeded()
                }
            }
        }
    }

    func stopAnalysis() {
        guard isBusy else { return }
        statusText = "Stopping..."
        scanner.cancelCurrentScan()
        analysisTask?.cancel()
    }

    func copyReport() {
        let text = selectedReportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.allowedContentTypes = [
            .movie,
            .video,
            .audio,
            .mpeg4Movie,
            .quickTimeMovie
        ]

        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
                continue
            }

            accepted = true

            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { [weak self] item, _ in
                guard let self else { return }

                let url: URL?

                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let urlItem = item as? URL {
                    url = urlItem
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }

                guard let url else { return }

                Task { @MainActor in
                    self.addFiles([url])
                }
            }
        }

        return accepted
    }

    func exportReportPDF() {
        guard let file = selectedFile else { return }

        let reportText = selectedReportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reportText.isEmpty else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "QC REPORT - \(sanitizedFilename(from: selectedReportTitle)).pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try writeReportPDF(to: url, for: file)
        } catch {
            NSSound.beep()
            print("Failed to export report PDF:", error)
        }
    }

    private func loadMetadata(for url: URL) {
        let scanner = self.scanner

        Task {
            let metadata = await scanner.readMetadata(for: url)

            await MainActor.run { [weak self] in
                guard let self,
                      let index = self.files.firstIndex(where: { $0.url == url }) else {
                    return
                }

                guard let metadata else {
                    if self.files[index].result == MediaFile.AnalysisResult.notYetAnalyzed.rawValue {
                        self.files[index].status = MediaFile.AnalysisStatus.error.rawValue
                        self.files[index].result = MediaFile.AnalysisResult.metadataFailed.rawValue
                        self.files[index].region = "—"
                        self.files[index].reviewWindow = "—"
                        self.files[index].analyzedAt = Date()
                        self.files[index].report = self.reportFormatter.report(for: self.files[index])
                    }
                    return
                }

                self.files[index].codec = metadata.codec
                self.files[index].resolution = metadata.resolution
                self.files[index].frameRate = metadata.frameRate
                self.files[index].duration = metadata.duration
                self.files[index].fileSize = metadata.fileSize

                if self.files[index].result != MediaFile.AnalysisResult.notYetAnalyzed.rawValue {
                    return
                }

                self.files[index].status = MediaFile.AnalysisStatus.readyToAnalyze.rawValue
                self.files[index].result = MediaFile.AnalysisResult.notYetAnalyzed.rawValue
                self.files[index].region = "—"
                self.files[index].reviewWindow = "—"
                self.files[index].report = ""
            }
        }
    }

    private func removeSelectedFileImmediately() {
        guard let selectedFileID else { return }
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

    private func clearImmediately() {
        files.removeAll()
        selectedFileID = nil
        progress = 0
        statusText = "Ready to Analyze"
        elapsedText = "00:00"
        remainingText = "--:--"
        isBusy = false
        stopElapsedTimer()
    }

    private func performPendingQueueActionIfNeeded() {
        switch pendingQueueAction {
        case .removeSelectedFile:
            removeSelectedFileImmediately()
        case .clearQueue:
            clearImmediately()
        case .none:
            break
        }
        pendingQueueAction = nil
    }

    private func fileIndex(for id: MediaFile.ID) -> Int? {
        files.firstIndex(where: { $0.id == id })
    }

    private func updateProgress(for fileID: MediaFile.ID, filePosition: Int, totalFiles: Int, moduleProgress: Double) {
        guard fileIndex(for: fileID) != nil else { return }

        let clamped = max(0, min(1, moduleProgress))
        progress = (Double(filePosition) + clamped) / Double(totalFiles)

        refreshTiming()
    }

    private func updateStatus(for fileID: MediaFile.ID, status: String) {
        guard let index = fileIndex(for: fileID) else { return }
        files[index].status = status
        statusText = status
    }

    private func resetFileAfterCancellation(fileID: MediaFile.ID) {
        guard let index = fileIndex(for: fileID) else { return }
        files[index].status = MediaFile.AnalysisStatus.readyToAnalyze.rawValue
        files[index].result = MediaFile.AnalysisResult.notYetAnalyzed.rawValue
    }

    private func startElapsedTimer() {
        elapsedTimerTask?.cancel()

        elapsedTimerTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }

                if Task.isCancelled {
                    break
                }

                await MainActor.run { [weak self] in
                    self?.refreshTiming()
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = nil
        analysisStartDate = nil
    }

    private func refreshTiming() {
        guard let start = analysisStartDate else {
            elapsedText = "00:00"
            remainingText = "--:--"
            return
        }

        let elapsed = Date().timeIntervalSince(start)
        elapsedText = Self.formatDuration(elapsed)

        if progress > 0.01 {
            let estimatedTotal = elapsed / progress
            let remaining = max(0, estimatedTotal - elapsed)
            remainingText = Self.formatDuration(remaining)
        } else {
            remainingText = "--:--"
        }
    }

    private func primaryWindow(fromReviewWindow window: TimeWindow) -> TimeWindow {
        let start = max(0, window.start + 0.5)
        let end = max(start, window.end - 0.5)
        return TimeWindow(start: start, end: end)
    }

    private func writeReportPDF(to url: URL, for file: MediaFile) throws {
        let attributedReport = reportFormatter.attributedReport(for: file)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedReport as CFAttributedString)

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 42
        var mediaBox = pageRect

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let textRect = pageRect.insetBy(dx: margin, dy: margin)
        let path = CGPath(rect: textRect, transform: nil)

        var currentLocation = 0
        while currentLocation < attributedReport.length {
            context.beginPDFPage(nil)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1.0, y: -1.0)

            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: currentLocation, length: 0),
                path,
                nil
            )

            CTFrameDraw(frame, context)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentLocation += visibleRange.length

            context.restoreGState()
            context.endPDFPage()

            if visibleRange.length == 0 {
                break
            }
        }

        context.closePDF()
    }

    private func sanitizedFilename(from string: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_"))

        let filtered = string.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }

        return String(filtered)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "__", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remaining = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }
}
