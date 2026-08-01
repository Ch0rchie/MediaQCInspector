//
//  MetadataValidationModule.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//

import Foundation

struct MetadataValidationModule: QCModule {

    let name = "Metadata Validation"
    private let reader: MetadataReader

    init(reader: MetadataReader = MetadataReader()) {
        self.reader = reader
    }

    func analyze(
        fileURL: URL,
        context: QCAnalysisContext
    ) async throws -> QCModuleResult {

        do {
            let metadata = try await reader.readMetadata(for: fileURL)
            let findings = validate(metadata: metadata, context: context)
            let outcome = Self.outcome(for: findings)

            return QCModuleResult(
                moduleName: name,
                outcome: outcome,
                findings: findings
            )
        } catch {
            return QCModuleResult(
                moduleName: name,
                outcome: .failed,
                findings: [
                    QCFinding(
                        severity: .failed,
                        title: "Metadata Read Failed",
                        details: error.localizedDescription,
                        recommendation: "Verify the file is accessible and that ffprobe is installed and working correctly."
                    )
                ]
            )
        }
    }
}

private extension MetadataValidationModule {

    func validate(metadata: QCMediaMetadata, context: QCAnalysisContext) -> [QCFinding] {
        var findings: [QCFinding] = []

        if metadata.formatName == nil {
            appendFailure(
                &findings,
                title: "Container Metadata Missing",
                details: "The container format name could not be read from the file.",
                recommendation: "Re-export the source master or verify that the file is not damaged."
            )
        }

        if metadata.duration == nil || (metadata.duration ?? 0) <= 0 {
            appendFailure(
                &findings,
                title: "Duration Missing",
                details: "The file duration could not be read or is not valid.",
                recommendation: "Verify the source file and re-export if the duration metadata is incomplete."
            )
        }

        if metadata.hasVideo && metadata.audioStreamCount == 0 {
            appendWarning(
                &findings,
                title: "No Audio Stream Detected",
                details: "The file contains video, but ffprobe did not report any audio streams.",
                recommendation: "Confirm that the file is intended to be silent. Otherwise re-export the source with the expected audio tracks."
            )
        }

        if metadata.videoStreamCount > 1 {
            appendWarning(
                &findings,
                title: "Multiple Video Streams Detected",
                details: "ffprobe reported more than one video stream.",
                recommendation: "Verify that the extra video streams are intentional and do not affect delivery requirements."
            )
        }

        if metadata.audioStreamCount > 1 {
            appendWarning(
                &findings,
                title: "Multiple Audio Streams Detected",
                details: "ffprobe reported more than one audio stream.",
                recommendation: "Verify that the extra audio streams are intentional and do not affect delivery requirements."
            )
        }

        if metadata.subtitleStreamCount > 0 {
            appendWarning(
                &findings,
                title: "Subtitle Streams Present",
                details: "ffprobe reported one or more subtitle streams.",
                recommendation: "Confirm subtitle streams are expected for this delivery."
            )
        }

        if metadata.hasVideo {
            validateVideoMetadata(metadata, findings: &findings)
        }

        if metadata.hasAudio {
            validateAudioMetadata(metadata, findings: &findings)
        }

        if let profile = activeProfile(for: context) {
            validate(metadata: metadata, against: profile, findings: &findings)
        }

        return findings
    }

    func validateVideoMetadata(_ metadata: QCMediaMetadata, findings: inout [QCFinding]) {
        if metadata.videoCodec == nil {
            appendFailure(
                &findings,
                title: "Video Codec Missing",
                details: "A video stream is present, but no video codec name could be read.",
                recommendation: "Verify the file exports correctly from the source master and includes valid video stream metadata."
            )
        }

        if metadata.width == nil || metadata.height == nil {
            appendFailure(
                &findings,
                title: "Resolution Missing",
                details: "A video stream is present, but the width and height could not be read.",
                recommendation: "Re-export the file or confirm the source file is not damaged."
            )
        } else if (metadata.width ?? 0) <= 0 || (metadata.height ?? 0) <= 0 {
            appendFailure(
                &findings,
                title: "Resolution Invalid",
                details: "The reported video resolution is not valid.",
                recommendation: "Verify the source export and confirm the file contains a valid picture stream."
            )
        }

        if metadata.frameRate == nil || (metadata.frameRate ?? 0) <= 0 {
            appendFailure(
                &findings,
                title: "Frame Rate Missing",
                details: "A video stream is present, but no valid frame rate could be read.",
                recommendation: "Verify the file export and re-export if the frame rate metadata is incomplete."
            )
        }

        if metadata.pixelFormat == nil {
            appendWarning(
                &findings,
                title: "Pixel Format Missing",
                details: "A video stream is present, but no pixel format could be read.",
                recommendation: "Verify the export settings and confirm the file contains the expected pixel format."
            )
        }

        if metadata.colorSpace == nil {
            appendWarning(
                &findings,
                title: "Color Space Missing",
                details: "A video stream is present, but no color space metadata could be read.",
                recommendation: "Confirm that the source export includes the expected color space metadata."
            )
        }

        if metadata.colorRange == nil {
            appendWarning(
                &findings,
                title: "Color Range Missing",
                details: "A video stream is present, but no color range metadata could be read.",
                recommendation: "Confirm that the source export includes the expected color range metadata."
            )
        }

        if metadata.fieldOrder == nil {
            appendWarning(
                &findings,
                title: "Field Order Missing",
                details: "A video stream is present, but no field order metadata could be read.",
                recommendation: "Confirm that the file is progressive or interlaced as expected and that the export preserved field order metadata."
            )
        }

        if metadata.timecode == nil {
            appendWarning(
                &findings,
                title: "Timecode Missing",
                details: "A video stream is present, but no timecode could be read.",
                recommendation: "Verify whether timecode is required for this delivery and re-export if it should be present."
            )
        }
    }

    func validateAudioMetadata(_ metadata: QCMediaMetadata, findings: inout [QCFinding]) {
        if metadata.audioCodec == nil {
            appendFailure(
                &findings,
                title: "Audio Codec Missing",
                details: "An audio stream is present, but no audio codec name could be read.",
                recommendation: "Verify the source master and re-export the file if the audio metadata is incomplete."
            )
        }

        if metadata.audioChannels == nil || (metadata.audioChannels ?? 0) <= 0 {
            appendFailure(
                &findings,
                title: "Audio Channel Count Missing",
                details: "An audio stream is present, but the channel count could not be read.",
                recommendation: "Verify the source export and confirm the audio stream metadata is complete."
            )
        }

        if metadata.audioSampleRate == nil || (metadata.audioSampleRate ?? 0) <= 0 {
            appendFailure(
                &findings,
                title: "Audio Sample Rate Missing",
                details: "An audio stream is present, but the sample rate could not be read.",
                recommendation: "Verify the source export and confirm the audio stream metadata is complete."
            )
        }

        if metadata.audioBitRate == nil {
            appendWarning(
                &findings,
                title: "Audio Bitrate Missing",
                details: "An audio stream is present, but no audio bitrate metadata could be read.",
                recommendation: "Confirm whether bitrate metadata is required for this delivery."
            )
        }
    }

    func validate(
        metadata: QCMediaMetadata,
        against profile: DeliveryProfile,
        findings: inout [QCFinding]
    ) {
        if profile.requireVideo && !metadata.hasVideo {
            appendFailure(
                &findings,
                title: "Profile Requires Video",
                details: "The active delivery profile expects a video stream, but none was found.",
                recommendation: "Re-export the file with the required video stream."
            )
        }

        if profile.requireAudio && !metadata.hasAudio {
            appendFailure(
                &findings,
                title: "Profile Requires Audio",
                details: "The active delivery profile expects an audio stream, but none was found.",
                recommendation: "Re-export the file with the required audio stream."
            )
        }

        if profile.requireTimecode && metadata.timecode == nil {
            appendFailure(
                &findings,
                title: "Profile Requires Timecode",
                details: "The active delivery profile expects embedded timecode, but none was found.",
                recommendation: "Re-export the file with the required timecode metadata."
            )
        }

        if let expectedCodec = profile.expectedVideoCodec {
            validateStringExpectation(
                actual: metadata.videoCodec,
                expected: expectedCodec,
                findingTitle: "Video Codec Does Not Match Profile",
                missingTitle: "Video Codec Missing For Profile",
                findings: &findings,
                recommendation: "Re-export the file using the expected video codec."
            )
        }

        if let expectedWidth = profile.expectedWidth,
           let expectedHeight = profile.expectedHeight {
            if metadata.width != expectedWidth || metadata.height != expectedHeight {
                appendFailure(
                    &findings,
                    title: "Resolution Does Not Match Profile",
                    details: "Expected \(expectedWidth)x\(expectedHeight), found \(metadata.width.map(String.init) ?? "unknown")x\(metadata.height.map(String.init) ?? "unknown").",
                    recommendation: "Re-export the file using the expected resolution."
                )
            }
        }

        if let expectedFrameRate = profile.expectedFrameRate {
            guard let actualFrameRate = metadata.frameRate else {
                appendFailure(
                    &findings,
                    title: "Frame Rate Missing For Profile",
                    details: "The active delivery profile expects a frame rate, but none was found.",
                    recommendation: "Re-export the file with the required frame rate metadata."
                )
                return
            }

            if abs(actualFrameRate - expectedFrameRate) > 0.01 {
                appendFailure(
                    &findings,
                    title: "Frame Rate Does Not Match Profile",
                    details: "Expected \(String(format: "%.3f", expectedFrameRate)) fps, found \(String(format: "%.3f", actualFrameRate)) fps.",
                    recommendation: "Re-export the file using the expected frame rate."
                )
            }
        }

        if let expectedAudioCodec = profile.expectedAudioCodec {
            validateStringExpectation(
                actual: metadata.audioCodec,
                expected: expectedAudioCodec,
                findingTitle: "Audio Codec Does Not Match Profile",
                missingTitle: "Audio Codec Missing For Profile",
                findings: &findings,
                recommendation: "Re-export the file using the expected audio codec."
            )
        }

        if let expectedAudioChannels = profile.expectedAudioChannels,
           metadata.audioChannels != nil,
           metadata.audioChannels != expectedAudioChannels {
            appendFailure(
                &findings,
                title: "Audio Channel Count Does Not Match Profile",
                details: "Expected \(expectedAudioChannels) channels, found \(metadata.audioChannels ?? 0).",
                recommendation: "Re-export the file using the expected audio channel count."
            )
        }
    }

    func activeProfile(for context: QCAnalysisContext) -> DeliveryProfile? {
        if let profile = context.deliveryProfile {
            return profile
        }

        guard let name = context.deliveryProfileName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        return DeliveryProfiles.profile(named: name)
    }

    func validateStringExpectation(
        actual: String?,
        expected: String,
        findingTitle: String,
        missingTitle: String,
        findings: inout [QCFinding],
        recommendation: String
    ) {
        guard let actual, !actual.isEmpty else {
            appendFailure(
                &findings,
                title: missingTitle,
                details: "The active delivery profile expects \(expected), but no matching metadata was found.",
                recommendation: recommendation
            )
            return
        }

        if actual.caseInsensitiveCompare(expected) != .orderedSame {
            appendFailure(
                &findings,
                title: findingTitle,
                details: "Expected \(expected), found \(actual).",
                recommendation: recommendation
            )
        }
    }

    func appendFailure(
        _ findings: inout [QCFinding],
        title: String,
        details: String,
        recommendation: String
    ) {
        findings.append(
            QCFinding(
                severity: .failed,
                title: title,
                details: details,
                recommendation: recommendation
            )
        )
    }

    func appendWarning(
        _ findings: inout [QCFinding],
        title: String,
        details: String,
        recommendation: String
    ) {
        findings.append(
            QCFinding(
                severity: .warning,
                title: title,
                details: details,
                recommendation: recommendation
            )
        )
    }

    static func outcome(for findings: [QCFinding]) -> QCOutcome {
        if findings.contains(where: { $0.severity == .failed }) {
            return .failed
        }

        if findings.contains(where: { $0.severity == .warning }) {
            return .warning
        }

        return .passed
    }
}
