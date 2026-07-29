// QCModel.swift
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
    private var stopRequested = false
    private var removeCurrentFileRequested = false
    private var currentAnalysisFileID: MediaFile.ID?
    private var pendingRemovalFileID: MediaFile.ID?
    private var processedFileIDs: Set<MediaFile.ID> = []

    var selectedFile: MediaFile? {
        guard let selectedFileID else { return nil }
        return files.first { $0.id == selectedFileID }
    }

    var canCopyReport: Bool {
        selectedFile?.report.isEmpty == false || files.contains(where: { !$0.report.isEmpty })
    }

    var canRemoveSelectedFile: Bool {
        selectedFileID != nil
    }

    var shouldConfirmStopAndRemoveSelectedFile: Bool {
        isBusy && selectedFileID != nil && selectedFileID == currentAnalysisFileID
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
        guard let selectedFileID else { return }

        if isBusy, selectedFileID == currentAnalysisFileID {
            pendingRemovalFileID = selectedFileID
            removeCurrentFileRequested = true
            statusText = "Stopping..."
            scanner.cancelCurrentScan()
            return
        }

        removeFile(with: selectedFileID)
    }

    func analyze() {
        guard !files.isEmpty, !isBusy else { return }

        isBusy = true
        progress = 0
        statusText = "Analyzing..."
        elapsedText = "00:00"
        stopRequested = false
        removeCurrentFileRequested = false
        pendingRemovalFileID = nil
        currentAnalysisFileID = nil
        processedFileIDs.removeAll()
        scanner.resetCancellation()
        startElapsedTimer()

        Task { [weak self] in
            await self?.runAnalysis()
        }
    }

    func stopAnalysis() {
        guard isBusy else { return }

        stopRequested = true
        statusText = "Stopping..."
        scanner.cancelCurrentScan()
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
        guard !isBusy else { return }

        files.removeAll()
        selectedFileID = nil
        progress = 0
        statusText = "Ready to Analyze"
        elapsedText = "00:00"
        stopRequested = false
        removeCurrentFileRequested = false
        pendingRemovalFileID = nil
        currentAnalysisFileID = nil
        processedFileIDs.removeAll()
        stopElapsedTimer()
    }

    private func runAnalysis() async {
        var processedCount = 0

        while true {
            if stopRequested {
                break
            }

            guard let nextID = nextEligibleFileID() else {
                if hasAwaitingMetadataFiles() {
                    statusText = "Waiting for Metadata..."
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue
                } else {
                    break
                }
            }

            currentAnalysisFileID = nextID
            let completed = await processFile(with: nextID, processedCount: processedCount)
            currentAnalysisFileID = nil

            if completed {
                processedFileIDs.insert(nextID)
                processedCount += 1
                continue
            }

            if removeCurrentFileRequested, pendingRemovalFileID == nextID {
                removeFile(with: nextID)
                pendingRemovalFileID = nil
                removeCurrentFileRequested = false
                continue
            }

            if stopRequested {
                break
            }
        }

        await MainActor.run {
            self.isBusy = false
            self.currentAnalysisFileID = nil
            self.statusText = self.stopRequested ? "Stopped" : "Complete"
            if !self.stopRequested {
                self.progress = 1.0
            }
            self.stopElapsedTimer()
            self.stopRequested = false
            self.removeCurrentFileRequested = false
        }
    }

    private func processFile(with fileID: MediaFile.ID, processedCount: Int) async -> Bool {
        guard let fileIndex = files.firstIndex(where: { $0.id == fileID }) else {
            return true
        }

        let fileURL = files[fileIndex].url

        await MainActor.run {
            guard fileIndex < self.files.count else { return }
            self.files[fileIndex].status = MediaFile.AnalysisStatus.checkingDecoder.rawValue
            self.files[fileIndex].result = MediaFile.AnalysisResult.inProgress.rawValue
            self.files[fileIndex].region = "—"
            self.files[fileIndex].reviewWindow = "—"
            self.files[fileIndex].report = ""
            self.statusText = "Analyzing..."
        }

        let validationProgress = makeValidationProgressHandler(processedCount: processedCount)
        let validation = await Task.detached(priority: .userInitiated) { [scanner] in
            await scanner.validateFile(fileURL, progress: validationProgress)
        }.value

        if removeCurrentFileRequested, pendingRemovalFileID == fileID {
            return false
        }

        if stopRequested {
            restoreFileToPending(with: fileID)
            return false
        }

        let duration = validation.duration ?? 0

        if validation.errors.isEmpty {
            finalizeFile(
                with: fileID,
                processedCount: processedCount,
                fileFraction: 1.0,
                status: MediaFile.AnalysisStatus.complete.rawValue,
                result: MediaFile.AnalysisResult.passed.rawValue,
                region: "—",
                reviewWindow: "—"
            )
            return true
        }

        await MainActor.run {
            guard let index = self.files.firstIndex(where: { $0.id == fileID }) else { return }
            self.files[index].status = MediaFile.AnalysisStatus.findingErrorWindow.rawValue
            self.files[index].result = MediaFile.AnalysisResult.inProgress.rawValue
            self.statusText = "Refining Error Window..."
        }

        let localizationProgress = makeLocalizationProgressHandler(processedCount: processedCount)
        let windows = await Task.detached(priority: .userInitiated) { [scanner] in
            await scanner.scanForBadWindows(
                file: fileURL,
                durationSeconds: duration,
                progress: localizationProgress
            )
        }.value

        if removeCurrentFileRequested, pendingRemovalFileID == fileID {
            return false
        }

        if stopRequested {
            restoreFileToPending(with: fileID)
            return false
        }

        var primaryRegion = "—"
        var reviewWindow = "—"

        if let first = windows.first, let last = windows.last {
            let primaryWindow = TimeWindow(start: first.start, end: last.end)
            primaryRegion = scanner.formatWindow(primaryWindow)
            reviewWindow = reportFormatter.formatWindow(
                reportFormatter.editorialReviewWindow(for: primaryWindow, durationSeconds: duration)
            )
        }

        finalizeFile(
            with: fileID,
            processedCount: processedCount,
            fileFraction: 1.0,
            status: MediaFile.AnalysisStatus.complete.rawValue,
            result: MediaFile.AnalysisResult.errorsFound.rawValue,
            region: primaryRegion,
            reviewWindow: reviewWindow
        )
        return true
    }

    private func nextEligibleFileID() -> MediaFile.ID? {
        for file in files {
            if processedFileIDs.contains(file.id) {
                continue
            }

            if file.result == MediaFile.AnalysisResult.metadataFailed.rawValue {
                processedFileIDs.insert(file.id)
                continue
            }

            if !isMetadataReady(file) {
                continue
            }

            return file.id
        }

        return nil
    }

    private func hasAwaitingMetadataFiles() -> Bool {
        files.contains { file in
            !processedFileIDs.contains(file.id) &&
            !isMetadataReady(file) &&
            file.result != MediaFile.AnalysisResult.metadataFailed.rawValue
        }
    }

    private func isMetadataReady(_ file: MediaFile) -> Bool {
        let fields = [file.codec, file.resolution, file.frameRate, file.duration, file.fileSize]
        return fields.allSatisfy { !$0.isEmpty && $0 != "—" }
    }

    private func finalizeFile(
        with fileID: MediaFile.ID,
        processedCount: Int,
        fileFraction: Double,
        status: String,
        result: String,
        region: String,
        reviewWindow: String
    ) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }

        files[index].status = status
        files[index].result = result
        files[index].region = region
        files[index].reviewWindow = reviewWindow
        files[index].analyzedAt = Date()

        let updated = files[index]
        files[index].report = reportFormatter.report(for: updated)

        reportProgress(processedCount: processedCount, currentFileFraction: fileFraction)
    }

    private func restoreFileToPending(with fileID: MediaFile.ID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }

        files[index].status = MediaFile.AnalysisStatus.readyToAnalyze.rawValue
        files[index].result = MediaFile.AnalysisResult.notYetAnalyzed.rawValue
        files[index].region = "—"
        files[index].reviewWindow = "—"
        files[index].report = ""
        files[index].analyzedAt = nil
    }

    private func removeFile(with fileID: MediaFile.ID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }

        files.remove(at: index)
        processedFileIDs.remove(fileID)

        if currentAnalysisFileID == fileID {
            currentAnalysisFileID = nil
        }

        if selectedFileID == fileID {
            if files.isEmpty {
                selectedFileID = nil
            } else {
                let nextIndex = min(index, files.count - 1)
                selectedFileID = files[nextIndex].id
            }
        }
    }

    private func makeValidationProgressHandler(processedCount: Int) -> @Sendable (Double) -> Void {
        { [weak self] fraction in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reportProgress(
                    processedCount: processedCount,
                    currentFileFraction: max(0, min(1, fraction)) * 0.5
                )
            }
        }
    }

    private func makeLocalizationProgressHandler(processedCount: Int) -> @Sendable (Double) -> Void {
        { [weak self] fraction in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let clamped = max(0, min(1, fraction))
                self.reportProgress(
                    processedCount: processedCount,
                    currentFileFraction: 0.5 + (clamped * 0.5)
                )
            }
        }
    }

    private func reportProgress(processedCount: Int, currentFileFraction: Double) {
        let totalFiles = max(files.count, 1)
        let clampedFraction = max(0, min(1, currentFileFraction))
        let target = (Double(processedCount) + clampedFraction) / Double(totalFiles)
        progress = max(progress, min(1, target))
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
