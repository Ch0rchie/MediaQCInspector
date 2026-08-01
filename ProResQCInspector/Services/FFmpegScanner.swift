import Foundation
import AVFoundation
import CoreMedia

struct TimeWindow: Hashable {
    var start: Double
    var end: Double
}

final class FFmpegScanner: @unchecked Sendable {
    private let ffmpegURL: URL?
    private let lock = NSLock()
    private var cancelRequested = false
    private var currentProcess: Process?

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter
    }()

    init() {
        self.ffmpegURL = try? ToolLocator.ffmpegURL()
    }

    func resetCancellation() {
        lock.lock()
        cancelRequested = false
        lock.unlock()
    }

    func cancelCurrentScan() {
        lock.lock()
        cancelRequested = true
        let process = currentProcess
        lock.unlock()

        process?.terminate()
    }

    private func isCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelRequested
    }

    func readMetadata(for url: URL) async -> MediaMetadata? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVURLAsset(url: url)

        do {
            let durationTime = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            let videoTrack = tracks.first { $0.mediaType == .video }

            let codec = try await displayCodec(for: videoTrack)
            let resolution = try await resolutionString(for: videoTrack)
            let frameRate = try await frameRateString(for: videoTrack)
            let duration = formatDuration(CMTimeGetSeconds(durationTime))
            let fileSize = byteFormatter.string(fromByteCount: fileSizeBytes(url))

            return MediaMetadata(
                codec: codec,
                resolution: resolution,
                frameRate: frameRate,
                duration: duration,
                fileSize: fileSize
            )
        } catch {
            print("Failed to load metadata:", error)
            return nil
        }
    }

    func validateFile(
        _ url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> (errors: [String], duration: Double?) {
        guard !isCancelled() else { return ([], nil) }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let duration = await assetDurationSeconds(AVURLAsset(url: url))
        guard duration > 0 else {
            progress(1)
            return ([], nil)
        }

        progress(0)

        // Smaller chunks = more frequent updates during the validation pass.
        let step = max(5.0, min(60.0, duration / 60.0))
        let windows = scanRangeWithSeek(
            file: url,
            durationSeconds: duration,
            step: step,
            progress: progress
        )

        if isCancelled() {
            return ([], duration)
        }

        progress(1)
        return windows.isEmpty ? ([], duration) : (["Decode errors detected"], duration)
    }

    func scanForBadWindows(
        file: URL,
        durationSeconds: Double,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [TimeWindow] {
        let didStartAccessing = file.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                file.stopAccessingSecurityScopedResource()
            }
        }

        guard durationSeconds > 0 else {
            progress(1)
            return []
        }

        progress(0)

        var windows = scanRangeWithSeek(
            file: file,
            durationSeconds: durationSeconds,
            step: 30.0,
            progress: { progress($0 * 0.25) }
        )

        guard !windows.isEmpty else {
            progress(1)
            return []
        }

        if isCancelled() {
            return []
        }

        windows = refineWindowsWithSeek(
            file: file,
            seedWindows: windows,
            step: 5.0,
            progress: { progress(0.25 + ($0 * 0.25)) }
        )

        if isCancelled() {
            return []
        }

        windows = refineWindowsWithSeek(
            file: file,
            seedWindows: windows,
            step: 1.0,
            progress: { progress(0.5 + ($0 * 0.25)) }
        )

        if isCancelled() {
            return []
        }

        windows = refineWindowsWithSeek(
            file: file,
            seedWindows: windows,
            step: 0.5,
            progress: { progress(0.75 + ($0 * 0.25)) }
        )

        let normalized = mergeWindows(windows).map { normalizePrimaryWindow($0) }
        progress(1)
        return mergeWindows(normalized)
    }

    func detectFreezeFrames(
        file: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [TimeWindow] {
        let didStartAccessing = file.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                file.stopAccessingSecurityScopedResource()
            }
        }

        guard !isCancelled() else { return [] }

        let duration = await assetDurationSeconds(AVURLAsset(url: file))
        guard duration > 0 else {
            progress(1)
            return []
        }

        progress(0)

        let output = runFFmpeg(arguments: [
            "-hide_banner",
            "-nostats",
            "-v", "info",
            "-i", file.path,
            "-vf", "freezedetect=n=-60dB:d=1.0",
            "-an",
            "-f", "null",
            "-"
        ])

        if isCancelled() {
            return []
        }

        let windows = parseFreezeDetectWindows(from: output, durationSeconds: duration)
        progress(1)
        return mergeWindows(windows)
    }

    func editorialReviewWindow(for primaryWindow: TimeWindow, durationSeconds: Double) -> TimeWindow {
        let start = max(0, primaryWindow.start - 1.0)
        let end = min(durationSeconds, primaryWindow.end + 0.5)
        return TimeWindow(start: start, end: end)
    }

    func formatTimecode(_ seconds: Double) -> String {
        let totalTenths = Int((seconds * 10).rounded())
        let hours = totalTenths / 36_000
        let minutes = (totalTenths % 36_000) / 600
        let remainingTenths = totalTenths % 600
        let wholeSeconds = remainingTenths / 10
        let tenths = remainingTenths % 10

        return String(format: "%02d:%02d:%02d.%d", hours, minutes, wholeSeconds, tenths)
    }

    func formatWindow(_ window: TimeWindow) -> String {
        "\(formatTimecode(window.start))–\(formatTimecode(window.end))"
    }

    private func scanRangeWithSeek(
        file: URL,
        durationSeconds: Double,
        step: Double,
        progress: @escaping @Sendable (Double) -> Void
    ) -> [TimeWindow] {
        var windows: [TimeWindow] = []
        var cursor = 0.0
        let totalSegments = max(1, Int(ceil(durationSeconds / step)))
        var completedSegments = 0

        while cursor < durationSeconds {
            if isCancelled() { break }

            let end = min(cursor + step, durationSeconds)
            if ffmpegErrorCount(file: file, start: formatTimecode(cursor), end: formatTimecode(end)) > 0 {
                windows.append(TimeWindow(start: cursor, end: end))
            }

            completedSegments += 1
            progress(Double(completedSegments) / Double(totalSegments))
            cursor = end
        }

        return mergeWindows(windows)
    }

    private func refineWindowsWithSeek(
        file: URL,
        seedWindows: [TimeWindow],
        step: Double,
        progress: @escaping @Sendable (Double) -> Void
    ) -> [TimeWindow] {
        guard !seedWindows.isEmpty else { return [] }

        var refined: [TimeWindow] = []
        let totalSegments = max(1, seedWindows.reduce(0) { $0 + max(1, Int(ceil(($1.end - $1.start) / step))) })
        var completedSegments = 0

        for window in seedWindows {
            if isCancelled() { break }

            var cursor = window.start
            while cursor < window.end {
                if isCancelled() { break }

                let end = min(cursor + step, window.end)
                if ffmpegErrorCount(file: file, start: formatTimecode(cursor), end: formatTimecode(end)) > 0 {
                    refined.append(TimeWindow(start: cursor, end: end))
                }

                completedSegments += 1
                progress(Double(completedSegments) / Double(totalSegments))
                cursor = end
            }
        }

        return mergeWindows(refined)
    }

    private func normalizePrimaryWindow(_ window: TimeWindow) -> TimeWindow {
        var start = ceil(window.start * 2.0 - 0.000001) / 2.0

        if abs(start.rounded() - start) < 0.0001 {
            start += 0.5
        }

        let end = floor(window.end * 2.0 + 0.000001) / 2.0

        let safeStart = max(0, start)
        let safeEnd = max(safeStart + 0.5, end)

        return TimeWindow(start: safeStart, end: safeEnd)
    }

    private func assetDurationSeconds(_ asset: AVURLAsset) async -> Double {
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite && seconds > 0 ? seconds : 0
        } catch {
            print("Failed to load duration:", error)
            return 0
        }
    }

    private func resolutionString(for track: AVAssetTrack?) async throws -> String {
        guard let track else { return "Unknown" }

        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let transformed = naturalSize.applying(preferredTransform)

        let width = Int(abs(transformed.width.rounded()))
        let height = Int(abs(transformed.height.rounded()))

        if width > 0 && height > 0 {
            return "\(width)×\(height)"
        } else {
            return "Unknown"
        }
    }

    private func frameRateString(for track: AVAssetTrack?) async throws -> String {
        guard let track else { return "Unknown" }

        let fps = try await track.load(.nominalFrameRate)
        guard fps > 0 else { return "Unknown" }
        return String(format: "%.2f", fps)
    }

    private func displayCodec(for track: AVAssetTrack?) async throws -> String {
        guard let track else { return "Unknown" }

        let formatDescriptions = try await track.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            return "Unknown"
        }

        let subtype = CMFormatDescriptionGetMediaSubType(formatDescription)

        switch subtype {
        case kCMVideoCodecType_AppleProRes422Proxy:
            return "ProRes Proxy"
        case kCMVideoCodecType_AppleProRes422LT:
            return "ProRes 422 LT"
        case kCMVideoCodecType_AppleProRes422:
            return "ProRes 422"
        case kCMVideoCodecType_AppleProRes422HQ:
            return "ProRes 422 HQ"
        case kCMVideoCodecType_AppleProRes4444:
            return "ProRes 4444"
        case kCMVideoCodecType_AppleProRes4444XQ:
            return "ProRes 4444 XQ"
        default:
            let fourCC = fourCCString(from: subtype)
            return fourCC.isEmpty ? "Unknown" : fourCC
        }
    }

    private func fourCCString(from code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]

        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private func fileSizeBytes(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func runFFmpeg(arguments: [String]) -> String {
        if isCancelled() { return "" }

        guard let ffmpegURL else {
            print("FFmpeg executable unavailable. Check bundled tools or development PATH.")
            return ""
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        lock.lock()
        currentProcess = process
        lock.unlock()

        defer {
            lock.lock()
            if currentProcess === process {
                currentProcess = nil
            }
            lock.unlock()
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to run ffmpeg:")
            print(error)
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func ffmpegErrorCount(file: URL, start: String, end: String) -> Int {
        if isCancelled() { return 0 }

        let output = runFFmpeg(arguments: [
            "-v", "error",
            "-err_detect", "explode",
            "-ss", start,
            "-to", end,
            "-i", file.path,
            "-f", "null",
            "-"
        ])

        let lower = output.lowercased()
        let needles = [
            "invalid frame header",
            "wrong picture",
            "wrong slice",
            "invalid plane",
            "error decoding",
            "error submitting packet",
            "corrupt",
            "damaged",
            "slice out of bounds",
            "invalid data",
            "wrong picture header size"
        ]

        return lower
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { line in
                needles.contains(where: { line.contains($0) })
            }
            .count
    }

    private func parseFreezeDetectWindows(from output: String, durationSeconds: Double) -> [TimeWindow] {
        var windows: [TimeWindow] = []
        var currentStart: Double?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)

            if let start = Self.freezeValue(in: line, key: "freeze_start") {
                currentStart = start
            }

            if let end = Self.freezeValue(in: line, key: "freeze_end") {
                if let start = currentStart {
                    windows.append(
                        normalizeFreezeWindow(
                            TimeWindow(start: start, end: end),
                            durationSeconds: durationSeconds
                        )
                    )
                }
                currentStart = nil
            }
        }

        if let start = currentStart {
            windows.append(
                normalizeFreezeWindow(
                    TimeWindow(start: start, end: durationSeconds),
                    durationSeconds: durationSeconds
                )
            )
        }

        return mergeWindows(windows)
    }

    private func normalizeFreezeWindow(_ window: TimeWindow, durationSeconds: Double) -> TimeWindow {
        let safeStart = max(0, min(window.start, durationSeconds))
        let safeEnd = max(safeStart, min(window.end, durationSeconds))
        return TimeWindow(start: safeStart, end: safeEnd)
    }

    private static func freezeValue(in line: String, key: String) -> Double? {
        let pattern = "\(key):\\s*([0-9]+(?:\\.[0-9]+)?)"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: line)
        else {
            return nil
        }

        return Double(line[range])
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "Unknown" }

        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    private func mergeWindows(_ windows: [TimeWindow]) -> [TimeWindow] {
        let sorted = windows.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }

        var merged: [TimeWindow] = []
        for window in sorted.dropFirst() {
            if window.start <= current.end + 0.01 {
                current.end = max(current.end, window.end)
            } else {
                merged.append(current)
                current = window
            }
        }

        merged.append(current)
        return merged
    }
}
