//
//  MetadataReader.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//

import Foundation

struct MetadataReader: Sendable {

    func readMetadata(for fileURL: URL) async throws -> QCMediaMetadata {
        guard fileURL.isFileURL else {
            throw MetadataReaderError.invalidFileURL(fileURL)
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw MetadataReaderError.fileNotFound(fileURL)
        }

        let ffprobeURL = try resolveExecutable(named: "ffprobe")

        let result = try await runProcess(
            executableURL: ffprobeURL,
            arguments: [
                "-v", "error",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                fileURL.path
            ]
        )

        guard result.status == 0 else {
            let message = Self.nonEmptyString(from: result.stderr)
                ?? Self.nonEmptyString(from: result.stdout)
                ?? "ffprobe failed."
            throw MetadataReaderError.processFailed(status: result.status, message: message)
        }

        guard !result.stdout.isEmpty else {
            throw MetadataReaderError.invalidOutput("ffprobe returned no output.")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let document = try decoder.decode(FFProbeDocument.self, from: result.stdout)
        return Self.makeMetadata(from: document)
    }
}

// MARK: - Process execution

private extension MetadataReader {

    struct ProcessOutput: Sendable {
        let status: Int32
        let stdout: Data
        let stderr: Data
    }

    func runProcess(
        executableURL: URL,
        arguments: [String]
    ) async throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                continuation.resume(
                    returning: ProcessOutput(
                        status: process.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func resolveExecutable(named name: String) throws -> URL {
        let fm = FileManager.default

        let commonPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/local/bin/\(name)"
        ]

        for path in commonPaths where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for component in path.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(component))
                    .appendingPathComponent(name)
                    .path

                if fm.isExecutableFile(atPath: candidate) {
                    return URL(fileURLWithPath: candidate)
                }
            }
        }

        throw MetadataReaderError.executableNotFound(name)
    }
}

// MARK: - Parsing

private extension MetadataReader {

    struct FFProbeDocument: Decodable {
        let format: FFProbeFormat?
        let streams: [FFProbeStream]?
    }

    struct FFProbeFormat: Decodable {
        let formatName: String?
        let formatLongName: String?
        let duration: String?
        let size: String?
        let bitRate: String?
        let tags: [String: String]?
    }

    struct FFProbeStream: Decodable {
        let codecName: String?
        let codecLongName: String?
        let codecType: String?
        let width: Int?
        let height: Int?
        let pixFmt: String?
        let rFrameRate: String?
        let avgFrameRate: String?
        let duration: String?
        let bitRate: String?
        let channels: Int?
        let sampleRate: String?
        let colorSpace: String?
        let colorRange: String?
        let fieldOrder: String?
        let tags: [String: String]?
    }

    static func makeMetadata(from document: FFProbeDocument) -> QCMediaMetadata {
        let streams = document.streams ?? []

        let videoStreams = streams.filter { $0.codecType == "video" }
        let audioStreams = streams.filter { $0.codecType == "audio" }
        let subtitleStreams = streams.filter { $0.codecType == "subtitle" }

        let video = videoStreams.first
        let audio = audioStreams.first
        let format = document.format

        let duration =
            parseDouble(format?.duration)
            ?? parseDouble(video?.duration)
            ?? parseDouble(audio?.duration)

        let fileSizeBytes = parseInt64(format?.size)
        let bitRate = parseInt64(format?.bitRate)

        let frameRate =
            parseFraction(video?.avgFrameRate)
            ?? parseFraction(video?.rFrameRate)

        let timecode =
            firstTagValue("timecode", in: video?.tags)
            ?? firstTagValue("timecode", in: format?.tags)

        return QCMediaMetadata(
            formatName: normalizedString(format?.formatName),
            formatLongName: normalizedString(format?.formatLongName),
            fileSizeBytes: fileSizeBytes,
            bitRate: bitRate,
            duration: duration,
            videoCodec: normalizedString(video?.codecName),
            videoCodecLongName: normalizedString(video?.codecLongName),
            width: video?.width,
            height: video?.height,
            frameRate: frameRate,
            averageFrameRate: parseFraction(video?.avgFrameRate),
            videoBitRate: parseInt64(video?.bitRate),
            pixelFormat: normalizedString(video?.pixFmt),
            colorSpace: normalizedString(video?.colorSpace),
            colorRange: normalizedString(video?.colorRange),
            fieldOrder: normalizedString(video?.fieldOrder),
            timecode: normalizedString(timecode),
            audioCodec: normalizedString(audio?.codecName),
            audioCodecLongName: normalizedString(audio?.codecLongName),
            audioChannels: audio?.channels,
            audioSampleRate: parseInt(audio?.sampleRate),
            audioBitRate: parseInt64(audio?.bitRate),
            videoStreamCount: videoStreams.count,
            audioStreamCount: audioStreams.count,
            subtitleStreamCount: subtitleStreams.count
        )
    }

    static func parseDouble(_ value: String?) -> Double? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A" else { return nil }
        return Double(trimmed)
    }

    static func parseInt(_ value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A" else { return nil }
        return Int(trimmed)
    }

    static func parseInt64(_ value: String?) -> Int64? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A" else { return nil }
        return Int64(trimmed)
    }

    static func parseFraction(_ value: String?) -> Double? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A" else { return nil }
        guard trimmed != "0/0" else { return nil }

        let parts = trimmed.split(separator: "/")
        guard parts.count == 2 else {
            return Double(trimmed)
        }

        guard
            let numerator = Double(parts[0]),
            let denominator = Double(parts[1]),
            denominator != 0
        else {
            return nil
        }

        return numerator / denominator
    }

    static func firstTagValue(_ key: String, in tags: [String: String]?) -> String? {
        guard let tags else { return nil }
        return tags.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value
    }

    static func normalizedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A" else { return nil }
        return trimmed
    }

    static func nonEmptyString(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let string = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? nil : string
    }
}

// MARK: - Errors

private enum MetadataReaderError: LocalizedError, Sendable {
    case invalidFileURL(URL)
    case fileNotFound(URL)
    case executableNotFound(String)
    case processFailed(status: Int32, message: String)
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .invalidFileURL(let url):
            return "The provided URL is not a file URL: \(url.absoluteString)"
        case .fileNotFound(let url):
            return "The file could not be found: \(url.path)"
        case .executableNotFound(let name):
            return "Could not locate \(name). Make sure it is installed and available in PATH."
        case .processFailed(let status, let message):
            return "ffprobe exited with status \(status): \(message)"
        case .invalidOutput(let message):
            return message
        }
    }
}
