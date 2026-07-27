import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MediaFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL

    var status: String = "Ready to Analyze"
    var result: String = "Not Yet Analyzed"
    var codec: String = "—"
    var resolution: String = "—"
    var frameRate: String = "—"
    var duration: String = "—"
    var fileSize: String = "—"
    var region: String = "—"
    var report: String = ""
}

@MainActor
final class QCModel: NSObject, ObservableObject {
    @Published var files: [MediaFile] = []
    @Published var selectedFileID: MediaFile.ID?
    @Published var isDropTarget = false
    @Published var isBusy = false
    @Published var progress: Double = 0
    @Published var statusText: String = "Ready to Analyze"

    private let scanner = FFmpegScanner()

    var canCopyReport: Bool {
        selectedFile()?.report.isEmpty == false || files.contains(where: { !$0.report.isEmpty })
    }

    var selectedReportTitle: String {
        selectedFile()?.url.lastPathComponent ?? "No File Selected"
    }

    var selectedReportText: String {
        guard let file = selectedFile() else {
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

    func analyze() {
        guard !files.isEmpty else { return }

        isBusy = true
        progress = 0
        statusText = "Checking Decoder..."

        for index in files.indices {
            files[index].status = "Checking Decoder"
            files[index].result = "In Progress"
            files[index].region = "—"
        }

        Task { [scanner] in
            for index in files.indices {
                let url = files[index].url

                await MainActor.run {
                    guard index < self.files.count else { return }
                    self.files[index].status = "Checking Decoder"
                    self.files[index].result = "In Progress"
                    self.statusText = "Checking Decoder..."
                }

                let validation = await scanner.validateFile(url)
                let errors = validation.errors
                let duration = validation.duration ?? 0

                var result = "Passed"
                var region = "—"

                if !errors.isEmpty {
                    await MainActor.run {
                        guard index < self.files.count else { return }
                        self.files[index].status = "Finding Error Window"
                        self.files[index].result = "In Progress"
                        self.statusText = "Finding Error Window..."
                    }

                    if duration > 0 {
                        let windows = scanner.scanForBadWindows(file: url, durationSeconds: duration)
                        if let first = windows.first, let last = windows.last {
                            region = "\(scanner.formatTimecode(first.start))–\(scanner.formatTimecode(last.end))"
                        }
                    }

                    result = "Errors Found"
                }

                await MainActor.run {
                    guard index < self.files.count else { return }

                    self.files[index].status = "Generating Report"
                    self.files[index].result = "In Progress"
                    self.statusText = "Generating Report..."
                }

                await MainActor.run {
                    guard index < self.files.count else { return }

                    self.files[index].status = "Complete"
                    self.files[index].result = result
                    self.files[index].region = region

                    let updated = self.files[index]
                    self.files[index].report = self.buildReport(for: updated)

                    self.progress = Double(index + 1) / Double(self.files.count)
                }
            }

            await MainActor.run {
                self.statusText = "Complete"
                self.isBusy = false
            }
        }
    }

    func copyReport() {
        let file = selectedFile() ?? files.first(where: { !$0.report.isEmpty })
        guard let file else {
            statusText = "No report available"
            return
        }

        let report = file.report.isEmpty ? buildReport(for: file) : file.report
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
        isBusy = false
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
                    self.files[index].status = "Ready to Analyze"
                    self.files[index].result = "Not Yet Analyzed"
                    self.files[index].report = ""
                } else {
                    self.files[index].status = "Error"
                    self.files[index].result = "Metadata Failed"
                    self.files[index].report = self.buildReport(for: self.files[index])
                }
            }
        }
    }

    private func selectedFile() -> MediaFile? {
        if let selectedFileID {
            return files.first(where: { $0.id == selectedFileID })
        }
        return nil
    }

    private func buildReport(for file: MediaFile) -> String {
        var lines: [String] = []

        lines.append("I performed a technical validation of the following master:")
        lines.append("File:")
        lines.append(file.url.lastPathComponent)
        lines.append("")
        lines.append("Summary")

        switch file.result {
        case "Passed":
            lines.append("The file did not produce FFmpeg-detected ProRes decode errors during validation.")
        case "Errors Found":
            lines.append("The file contains ProRes bitstream decode errors that are reproducible using FFmpeg's ProRes decoder. The errors are not limited to metadata and indicate malformed video frames within the ProRes stream.")
        case "Metadata Failed":
            lines.append("The file could not be fully validated because metadata extraction failed.")
        default:
            lines.append("The file is ready for analysis.")
        }

        lines.append("")
        lines.append("Test Results")

        switch file.result {
        case "Passed":
            lines.append("The test completed without FFmpeg-detected decode errors.")
        case "Errors Found":
            lines.append("The test reported repeated errors including:")
            lines.append("invalid frame header")
            lines.append("Error submitting packet to decoder: Invalid data found when processing input")
            lines.append("These errors indicate that portions of the ProRes video stream cannot be decoded correctly by a standards-compliant decoder.")
        case "Metadata Failed":
            lines.append("Metadata extraction failed, so the file could not be fully analyzed.")
        default:
            lines.append("The file has not been analyzed yet.")
        }

        lines.append("")
        lines.append("Affected Region")

        if file.result == "Errors Found" {
            lines.append("Primary error window: \(file.region)")
            lines.append("For editorial purposes, I recommend reviewing approximately:")
            lines.append(file.region)
            lines.append("to ensure the entire affected section is replaced or regenerated.")
        } else if file.result == "Passed" {
            lines.append("No discrete error region was identified.")
        } else {
            lines.append("No error region was identified.")
        }

        lines.append("")
        lines.append("Recommendation")

        switch file.result {
        case "Passed":
            lines.append("The file passed validation. No ProRes decode errors remain to be addressed.")
        case "Errors Found":
            lines.append("Please review the original timeline and regenerate this portion of the ProRes master, or provide a newly exported master from the source project. After replacement, I will analyze the revised file to confirm that no ProRes decode errors remain.")
        case "Metadata Failed":
            lines.append("Please verify the source file and try again. After replacement, I will analyze the revised file to confirm that no ProRes decode errors remain.")
        default:
            lines.append("Run Analyze to generate a validation report.")
        }

        return lines.joined(separator: "\n")
    }
}
