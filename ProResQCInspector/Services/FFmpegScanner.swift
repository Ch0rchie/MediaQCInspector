import Foundation
import AVFoundation
import CoreMedia

struct TimeWindow: Hashable {
    var start: Double
    var end: Double
}

final class FFmpegScanner: @unchecked Sendable {
    private let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter
    }()

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

    func validateFile(_ url: URL) async -> (errors: [String], duration: Double?) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let output = runFFmpeg(arguments: [
            "-v", "error",
            "-err_detect", "explode",
            "-i", url.path,
            "-f", "null",
            "-"
        ])

        print("FFMPEG RAW OUTPUT:")
        print(output)
        print("OUTPUT LENGTH:", output.count)

        let errors = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        let duration = await assetDurationSeconds(AVURLAsset(url: url))
        return (errors, duration)
    }

    func scanForBadWindows(file: URL, durationSeconds: Double) -> [TimeWindow] {
        let didStartAccessing = file.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                file.stopAccessingSecurityScopedResource()
            }
        }

        guard durationSeconds > 0 else { return [] }

        var windows = scanRange(file: file, durationSeconds: durationSeconds, step: 60.0)
        guard !windows.isEmpty else { return [] }

        windows = refineWindows(file: file, seedWindows: windows, step: 5.0)
        windows = refineWindows(file: file, seedWindows: windows, step: 1.0)
        windows = refineWindows(file: file, seedWindows: windows, step: 0.5)

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

    private func scanRange(file: URL, durationSeconds: Double, step: Double) -> [TimeWindow] {
        var windows: [TimeWindow] = []
        var cursor = 0.0

        while cursor < durationSeconds {
            let end = min(cursor + step, durationSeconds)
            if ffmpegErrorCount(file: file, start: formatTimecode(cursor), end: formatTimecode(end)) > 0 {
                windows.append(TimeWindow(start: cursor, end: end))
            }
            cursor = end
        }

        return mergeWindows(windows)
    }

    private func refineWindows(file: URL, seedWindows: [TimeWindow], step: Double) -> [TimeWindow] {
        guard !seedWindows.isEmpty else { return [] }

        var refined: [TimeWindow] = []

        for window in seedWindows {
            var cursor = window.start

            while cursor < window.end {
                let end = min(cursor + step, window.end)
                if ffmpegErrorCount(file: file, start: formatTimecode(cursor), end: formatTimecode(end)) > 0 {
                    refined.append(TimeWindow(start: cursor, end: end))
                }
                cursor = end
            }
        }

        return mergeWindows(refined)
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
        let bytes: [CChar] = [
            CChar((code >> 24) & 0xFF),
            CChar((code >> 16) & 0xFF),
            CChar((code >> 8) & 0xFF),
            CChar(code & 0xFF),
            0
        ]
        return String(cString: bytes)
    }

    private func fileSizeBytes(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func runFFmpeg(arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to run ffmpeg:")
            print(error)
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            print("FFmpeg exited with status:", process.terminationStatus)
            print("Output:")
            print(output)
        }

        return output
    }

    private func ffmpegErrorCount(file: URL, start: String, end: String) -> Int {
        let output = runFFmpeg(arguments: [
            "-v", "error",
            "-err_detect", "explode",
            "-ss", start,
            "-to", end,
            "-i", file.path,
            "-f", "null",
            "-"
        ])

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

        return output
            .lowercased()
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { line in
                needles.contains(where: { line.contains($0) })
            }
            .count
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
