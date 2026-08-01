//
//  DeliveryProfiles.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/31/26.
//


import Foundation

enum DeliveryProfiles {

    static let genericMaster = DeliveryProfile(
        name: "Generic Master",
        requireVideo: true,
        requireAudio: false,
        requireTimecode: false
    )

    static let broadcastDelivery = DeliveryProfile(
        name: "Broadcast Delivery",
        expectedAudioChannels: 2,
        requireVideo: true,
        requireAudio: true,
        requireTimecode: true
    )

    static let all: [DeliveryProfile] = [
        genericMaster,
        broadcastDelivery
    ]

    static func profile(named name: String) -> DeliveryProfile? {

        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        return all.first {
            $0.name.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }
}
