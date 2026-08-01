import Foundation

struct DeliveryProfile: Codable, Hashable, Sendable {

    let name: String

    let expectedVideoCodec: String?
    let expectedWidth: Int?
    let expectedHeight: Int?
    let expectedFrameRate: Double?

    let expectedAudioCodec: String?
    let expectedAudioChannels: Int?

    let requireVideo: Bool
    let requireAudio: Bool
    let requireTimecode: Bool

    init(
        name: String,
        expectedVideoCodec: String? = nil,
        expectedWidth: Int? = nil,
        expectedHeight: Int? = nil,
        expectedFrameRate: Double? = nil,
        expectedAudioCodec: String? = nil,
        expectedAudioChannels: Int? = nil,
        requireVideo: Bool = true,
        requireAudio: Bool = false,
        requireTimecode: Bool = false
    ) {
        self.name = name
        self.expectedVideoCodec = expectedVideoCodec
        self.expectedWidth = expectedWidth
        self.expectedHeight = expectedHeight
        self.expectedFrameRate = expectedFrameRate
        self.expectedAudioCodec = expectedAudioCodec
        self.expectedAudioChannels = expectedAudioChannels
        self.requireVideo = requireVideo
        self.requireAudio = requireAudio
        self.requireTimecode = requireTimecode
    }
}
