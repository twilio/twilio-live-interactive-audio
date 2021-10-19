//
//  Copyright (C) 2021 Twilio, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Datadog
import TwilioLivePlayer

class PlayerTelemetryLogger: NSObject {
    var isEnabled = false {
        didSet {
            guard logger != nil, isEnabled != oldValue else { return }
            
            if isEnabled {
                Player.telemetry.subscribe(self)
            } else {
                Player.telemetry.unsubscribe(self)
                cache.removeAll()
            }
        }
    }
    private let logger = DatadogManager.shared.logger
    private let authStore = AuthStore.shared
    private var cache: [String] = []
    private var lastHighLatencyReductionStrategy: String?
}

extension PlayerTelemetryLogger: TelemetrySubscriber {
    func didReceiveTelemetryData(_ data: TelemetryData) {
        if let data = data as? TelemetryDataPlaybackQualitySummary {
            if data.playerLiveLatency.seconds > 3 {
                logger?.error(
                    "High latency detected",
                    error: nil,
                    attributes: [
                        "player_sdk_version": Player.sdkVersion(),
                        "user_identity": authStore.userIdentity,
                        "telemetry_timestamp": "\(data.timestamp)",
                        "player_position": data.playerPosition.seconds,
                        "player_streamer_sid": data.playerStreamerSid,
                        "player_volume": data.playerVolume,
                        "player_live_latency": data.playerLiveLatency.seconds,
                        "video_bitrate": data.playerStats.videoBitrate,
                        "video_frames_decoded": data.playerStats.videoFramesDecoded,
                        "video_frames_dropped": data.playerStats.videoFramesDropped,
                        "telemetry_summary": cache
                    ]
                )
                
                cache.removeAll()
                return
            }
        } else if let data = data as? TelemetryDataPlaybackQualityHighLatencyReductionApplied {
            logger?.notice(
                "High latency reduction applied",
                error: nil,
                attributes: [
                    "player_sdk_version": Player.sdkVersion(),
                    "user_identity": authStore.userIdentity,
                    "telemetry_timestamp": "\(data.timestamp)",
                    "player_position": data.playerPosition.seconds,
                    "player_streamer_sid": data.playerStreamerSid,
                    "player_live_latency": data.playerLiveLatency.seconds,
                    "high_latency_reduction_strategy": data.name
                ]
            )
            
            lastHighLatencyReductionStrategy = data.name
        } else if let data = data as? TelemetryDataPlaybackQualityHighLatencyReductionReverted {
            logger?.notice(
                "High latency reduction reverted",
                error: nil,
                attributes: [
                    "player_sdk_version": Player.sdkVersion(),
                    "user_identity": authStore.userIdentity,
                    "telemetry_timestamp": "\(data.timestamp)",
                    "player_position": data.playerPosition.seconds,
                    "player_streamer_sid": data.playerStreamerSid,
                    "player_live_latency": data.playerLiveLatency.seconds,
                    "last_high_latency_reduction_strategy": lastHighLatencyReductionStrategy
                ]
            )
        }

        // Timed metadata is frequent and not essential so exclude from cache to reduce noise
        if !(data is TelemetryDataTimedMetadataReceived) {
            if cache.count == 100 {
                cache.removeFirst()
            }
            
            // Temporarily prepend timestamp until SDK includes it in description
            cache.append("\(data.timestamp) \(data.description)")
        }
    }
}
