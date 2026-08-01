//
//  QCMediaMetadata.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//


import Foundation

struct QCMediaMetadata: Codable, Hashable, Sendable {
    // Container / format
    let formatName: String?
    let formatLongName: String?
    let fileSizeBytes: Int64?
    let bitRate: Int64?
    let duration: Double?

    // Video
    let videoCodec: String?
    let videoCodecLongName: String?
    let width: Int?
    let height: Int?
    let frameRate: Double?
    let averageFrameRate: Double?
    let videoBitRate: Int64?
    let pixelFormat: String?
    let colorSpace: String?
    let colorRange: String?
    let fieldOrder: String?
    let timecode: String?

    // Audio
    let audioCodec: String?
    let audioCodecLongName: String?
    let audioChannels: Int?
    let audioSampleRate: Int?
    let audioBitRate: Int64?

    // Stream counts
    let videoStreamCount: Int
    let audioStreamCount: Int
    let subtitleStreamCount: Int

    init(
        formatName: String? = nil,
        formatLongName: String? = nil,
        fileSizeBytes: Int64? = nil,
        bitRate: Int64? = nil,
        duration: Double? = nil,
        videoCodec: String? = nil,
        videoCodecLongName: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        frameRate: Double? = nil,
        averageFrameRate: Double? = nil,
        videoBitRate: Int64? = nil,
        pixelFormat: String? = nil,
        colorSpace: String? = nil,
        colorRange: String? = nil,
        fieldOrder: String? = nil,
        timecode: String? = nil,
        audioCodec: String? = nil,
        audioCodecLongName: String? = nil,
        audioChannels: Int? = nil,
        audioSampleRate: Int? = nil,
        audioBitRate: Int64? = nil,
        videoStreamCount: Int = 0,
        audioStreamCount: Int = 0,
        subtitleStreamCount: Int = 0
    ) {
        self.formatName = formatName
        self.formatLongName = formatLongName
        self.fileSizeBytes = fileSizeBytes
        self.bitRate = bitRate
        self.duration = duration
        self.videoCodec = videoCodec
        self.videoCodecLongName = videoCodecLongName
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.averageFrameRate = averageFrameRate
        self.videoBitRate = videoBitRate
        self.pixelFormat = pixelFormat
        self.colorSpace = colorSpace
        self.colorRange = colorRange
        self.fieldOrder = fieldOrder
        self.timecode = timecode
        self.audioCodec = audioCodec
        self.audioCodecLongName = audioCodecLongName
        self.audioChannels = audioChannels
        self.audioSampleRate = audioSampleRate
        self.audioBitRate = audioBitRate
        self.videoStreamCount = videoStreamCount
        self.audioStreamCount = audioStreamCount
        self.subtitleStreamCount = subtitleStreamCount
    }

    var hasVideo: Bool {
        videoStreamCount > 0
    }

    var hasAudio: Bool {
        audioStreamCount > 0
    }

    var hasSubtitles: Bool {
        subtitleStreamCount > 0
    }

    var resolutionString: String? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return "\(width)x\(height)"
    }

    var frameRateString: String? {
        guard let frameRate, frameRate > 0 else { return nil }
        return String(format: "%.3f", frameRate)
    }

    var displayDuration: String? {
        guard let duration, duration > 0 else { return nil }
        return Self.formatDuration(duration)
    }

    var summaryText: String {
        var parts: [String] = []

        if let formatLongName, !formatLongName.isEmpty {
            parts.append(formatLongName)
        } else if let formatName, !formatName.isEmpty {
            parts.append(formatName)
        }

        if let resolutionString {
            parts.append(resolutionString)
        }

        if let frameRateString {
            parts.append("\(frameRateString) fps")
        }

        if let displayDuration {
            parts.append(displayDuration)
        }

        return parts.joined(separator: " • ")
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let total = max(0, seconds)
        let hours = Int(total / 3600)
        let minutes = Int((total.truncatingRemainder(dividingBy: 3600)) / 60)
        let remaining = total.truncatingRemainder(dividingBy: 60)

        if hours > 0 {
            return String(format: "%02d:%02d:%05.2f", hours, minutes, remaining)
        } else {
            return String(format: "%02d:%05.2f", minutes, remaining)
        }
    }
}