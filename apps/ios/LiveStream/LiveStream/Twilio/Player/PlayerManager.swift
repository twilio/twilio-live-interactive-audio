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

import AVFoundation
import TwilioPlayer

class PlayerManager: NSObject, LiveStreamSpeakerSource {
    weak var delegate: LiveStreamSpeakerSourceDelegate?
    var speakers: [LiveStreamSpeaker] { participants }
    private let audioSession = AVAudioSession.sharedInstance()
    private let telemetryLogger = PlayerTelemetryLogger()
    private let jsonDecoder = JSONDecoder()
    private var accessToken: String!
    private var userIdentity: String!
    private var player: Player?
    private var participants: [PlayerParticipant] = []
    private var lastMetadataSequenceID: Int = .min

    override init() {
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func configure(accessToken: String, userIdentity: String) {
        self.accessToken = accessToken
        self.userIdentity = userIdentity
    }
    
    func connect() {
        telemetryLogger.isEnabled = true
        participants.removeAll()

        if player != nil {
            play()
        } else {
            player = Player.connect(accessToken: accessToken, delegate: self)
        }
    }
    
    func pause() {
        player?.pause()
    }
    
    func disconnect() {
        player?.pause()
        player = nil
        lastMetadataSequenceID = .min
        telemetryLogger.isEnabled = false
    }

    private func play() {
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
        } catch {
            handleError(error)
            return
        }
        
        player?.play()
    }
    
    private func handleError(_ error: Error) {
        disconnect()
        delegate?.speakerSource(self, didDisconnectWithError: error)
    }
}

extension PlayerManager: PlayerDelegate {
    func playerDidFailWithError(player: Player, error: Error) {
        handleError(error)
    }

    func playerDidChangePlayerState(player: Player, playerState state: Player.State) {
        switch state {
        case .ready:
            play()
        case .ended:
            handleError(LiveStreamError.liveStreamEndedByModerator)
        case .idle, .buffering, .playing:
            break
        @unknown default:
            break
        }
    }
    
    func playerWillRebuffer(player: Player) {
        print("Player will rebuffer.")
    }
    
    /// Receive timed metadata.
    ///
    /// - Note: If timed metadata is critical to the operation of your app it may be important to handle the case in which no timed metadata is received.
    ///   For example if for some reason the media composer does not send any timed metadata.
    func playerDidReceiveTimedMetadata(player: Player, metadata: TimedMetadata) {
        guard let data = metadata.metadata.data(using: .utf8) else {
            handleError(LiveStreamError.invalidTimedMetadata)
            return
        }
        
        let metadata: PlayerMetadata
        
        do {
            metadata = try jsonDecoder.decode(PlayerMetadata.self, from: data)
        } catch {
            handleError(error)
            return
        }
        
        guard
            metadata.s > lastMetadataSequenceID, // Order is not gaurenteed so discard out of sequence metadata
            !metadata.p.keys.isEmpty // Participants can be empty when room ends so discard this invalid update
        else {
            return
        }
        
        lastMetadataSequenceID = metadata.s
        let participants = metadata.p
            .map { PlayerParticipant(identity: $0, audioLevel: $1.v) }
            .filter { $0.identity != userIdentity }
        
        if self.participants.count == 0 {
            self.participants = participants
            delegate?.speakerSourceDidConnect(self)
        } else {
            let removedParticipants = self.participants.filter { participant in
                participants.first(where: { $0.identity == participant.identity }) == nil
            }
            
            removedParticipants.forEach { participant in
                guard let index = self.participants.firstIndex(where: { $0.identity == participant.identity }) else { return }
                
                self.participants.remove(at: index)
                self.delegate?.speakerSource(self, didRemoveSpeaker: participant)
            }
            
            participants.forEach { participant in
                if let index = self.participants.firstIndex(where: { $0.identity == participant.identity }) {
                    self.participants[index] = participant
                    self.delegate?.speakerSource(self, didUpdateSpeaker: participant)
                } else {
                    self.participants.append(participant)
                    self.delegate?.speakerSource(self, didAddSpeaker: participant)
                }
            }
        }
    }
}
