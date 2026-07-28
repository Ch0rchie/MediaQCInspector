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

        let output = runProcess(
            executable: ffmpegPath,
            arguments: [
                "-v", "error",
                "-err_detect", "explode",
                "-i", url.path,
                "-f", "null",
                "-"
            ]
        )

        let errors = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        let duration = await assetDurationSeconds(AVURLAsset(url: url))
        return (errors, duration)
    }

    func scanForBadWindows(file: URL, durationSeconds: Double) -> [TimeWindow] {
        withSecurityScopedAccess(to: file) {
            guard durationSeconds > 0 else { return [] }

            let minutes = Int(ceil(durationSeconds / 60.0))
            var minuteHits: [Int] = []

            for minute in 0..<minutes {
                let start = formatTimecode(Double(minute) * 60)
                let end = formatTimecode(min(Double(minute + 1) * 60, durationSeconds))
                if ffmpegErrorCount(file: file, start: start, end: end) > 0 {
                    minuteHits.append(minute)
                }
            }

            guard let first = minuteHits.first else { return [] }
            let last = minuteHits.last ?? first

            var windows: [TimeWindow] = []
            for minute in first...last {
                let base = Double(minute) * 60
                for step in stride(from: 0.0, to: 60.0, by: 5.0) {
                    let s = base + step
                    let e = min(base + step + 5.0, durationSeconds)
                    if ffmpegErrorCount(file: file, start: formatTimecode(s), end: formatTimecode(e)) > 0 {
                        windows.append(TimeWindow(start: s, end: e))
                    }
                }
            }

            return mergeWindows(windows)
        }
    }

    func formatTimecode(_ seconds: Double) -> String {
        let total = max(0, seconds)
        let h = Int(total / 3600)
        let m = Int((total.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = total.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%02d:%04.1f", h, m, s)
    }

    func formatWindow(_ window: TimeWindow) -> String {
        "\(formatTimecode(window.start))–\(formatTimecode(window.end))"
    }

    private func withSecurityScopedAccess<T>(to url: URL, _ work: () -> T) -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return work()
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

    private func ffmpegErrorCount(file: URL, start: String, end: String) -> Int {
        let output = runProcess(
            executable: ffmpegPath,
            arguments: [
                "-v", "error",
                "-err_detect", "explode",
                "-ss", start,
                "-to", end,
                "-i", file.path,
                "-f", "null",
                "-"
            ]
        )

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
            .split(separator: "\n")
            .filter { line in
                needles.contains(where: { line.contains($0) }) }
            .count
    }

    private func runProcess(executable: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to run process:", executable)
            print(error)
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            print("Process exited with status:", process.terminationStatus)
            print("Executable:", executable)
            print("Output:")
            print(output)
        }

        return output
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
