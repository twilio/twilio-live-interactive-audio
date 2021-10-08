//
//  Copyright (C) 2020 Twilio, Inc.
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

import TwilioVideo

protocol RoomManagerDelegate {
    func roomManager(_ roomManager: RoomManager, didReceiveMessage message: RoomMessage)
}

class RoomManager: NSObject, LiveStreamSpeakerSource {
    weak var delegate: (LiveStreamSpeakerSourceDelegate & RoomManagerDelegate)?
    var speakers: [LiveStreamSpeaker] { participants }
    var isMuted: Bool {
        get {
            guard let micTrack = micTrack else { return false }
            
            return !micTrack.isEnabled
        }
        set {
            micTrack?.isEnabled = !newValue
            
            if let participant = participants.first(where: { $0.identity == room?.localParticipant?.identity ?? "" }) {
                delegate?.speakerSource(self, didUpdateSpeaker: participant)
            }
        }
    }
    private var room: Room?
    private var accessToken: String!
    private var roomName: String!
    private var micTrack: LocalAudioTrack?
    private var dataTrack: LocalDataTrack?
    private var participants: [RoomParticipant] = []
    private var statsTimer: Timer?
    
    func configure(accessToken: String, roomName: String) {
        self.accessToken = accessToken
        self.roomName = roomName
    }
    
    func connect() {
        guard room == nil else { fatalError("Room connection already in progress.") }
        
        micTrack = LocalAudioTrack()
        dataTrack = LocalDataTrack()
        let options = ConnectOptions(token: accessToken) { builder in
            builder.roomName = self.roomName
            builder.audioTracks = [self.micTrack].compactMap { $0 }
            builder.dataTracks = [self.dataTrack].compactMap { $0 }
        }
        room = TwilioVideoSDK.connect(options: options, delegate: self)
    }

    func disconnect() {
        room?.disconnect()
        room = nil
        micTrack = nil
        dataTrack = nil
        participants.removeAll()
        statsTimer?.invalidate()
    }
    
    func sendMessage(_ message: RoomMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        
        dataTrack?.send(data)
    }
    
    @discardableResult private func addRemoteParticipant(_ participant: RemoteParticipant) -> RoomParticipant? {
        guard !participant.isMediaComposer else { return nil }

        participant.delegate = self
        let participant = RoomParticipant(participant: participant)
        participants.insert(participant, at: participant.isModerator ? 0 : participants.endIndex)
        return participant
    }

    @objc private func getStats() {
        room?.getStats { [weak self] statsReports in
            guard let self = self, let statsReport = statsReports.first else { return }

            statsReport.localAudioTrackStats.forEach { self.updateAudioLevel(trackSID: $0.trackSid, audioLevel: $0.audioLevel) }
            statsReport.remoteAudioTrackStats.forEach { self.updateAudioLevel(trackSID: $0.trackSid, audioLevel: $0.audioLevel) }
        }
    }
    
    private func updateAudioLevel(trackSID: String, audioLevel: UInt) {
        guard let participant = participants.first(where: { $0.participant.audioTracks.first?.trackSid == trackSID }) else { return }
        
        // Check for mute because local track still has audio level when track is disabled
        participant.audioLevel = participant.isMuted ? 0 : Int(audioLevel)
        delegate?.speakerSource(self, didUpdateSpeaker: participant)
    }
    
    private func handleError(_ error: Error) {
        disconnect()
        delegate?.speakerSource(self, didDisconnectWithError: error)
    }
}

extension RoomManager: RoomDelegate {
    func roomDidConnect(room: Room) {
        room.remoteParticipants.forEach { addRemoteParticipant($0) }
        participants.append(RoomParticipant(participant: room.localParticipant!))
        statsTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(getStats),
            userInfo: nil,
            repeats: true
        )
        delegate?.speakerSourceDidConnect(self)
    }
    
    func roomDidFailToConnect(room: Room, error: Error) {
        handleError(error)
    }
    
    func roomDidDisconnect(room: Room, error: Error?) {
        if let error = error {
            if (error as NSError).isRoomCompletedError {
                handleError(LiveStreamError.liveStreamEndedByModerator)
            } else if (error as NSError).isParticipantNotFoundError {
                // Can receive this error when a speaker is removed by moderator if there is other activity in progress
                handleError(LiveStreamError.speakerMovedToAudienceByModerator)
            } else {
                handleError(error)
            }
        } else {
            // Most of the time there is no error when speaker is removed by moderator
            handleError(LiveStreamError.speakerMovedToAudienceByModerator)
        }
    }
    
    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        guard let participant = addRemoteParticipant(participant) else { return }
        
        delegate?.speakerSource(self, didAddSpeaker: participant)
    }
    
    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        guard let index = participants.firstIndex(where: { $0.identity == participant.identity }) else { return }
        
        let participant = participants[index]
        participants.remove(at: index)
        delegate?.speakerSource(self, didRemoveSpeaker: participant)
    }
}

extension RoomManager: RemoteParticipantDelegate {
    func remoteParticipantDidEnableAudioTrack(
        participant: RemoteParticipant,
        publication: RemoteAudioTrackPublication
    ) {
        guard let participant = participants.first(where: { $0.identity == participant.identity }) else { return }

        delegate?.speakerSource(self, didUpdateSpeaker: participant)
    }
    
    func remoteParticipantDidDisableAudioTrack(
        participant: RemoteParticipant,
        publication: RemoteAudioTrackPublication
    ) {
        guard let participant = participants.first(where: { $0.identity == participant.identity }) else { return }
        
        delegate?.speakerSource(self, didUpdateSpeaker: participant)
    }
    
    func didSubscribeToDataTrack(
        dataTrack: RemoteDataTrack,
        publication: RemoteDataTrackPublication,
        participant: RemoteParticipant
    ) {
        dataTrack.delegate = self
    }
}

extension RoomManager: RemoteDataTrackDelegate {
    func remoteDataTrackDidReceiveData(remoteDataTrack: RemoteDataTrack, message: Data) {
        guard let message = try? JSONDecoder().decode(RoomMessage.self, from: message) else { return }
        
        delegate?.roomManager(self, didReceiveMessage: message)
    }
}

private extension RemoteParticipant {
    var isMediaComposer: Bool { audioTracks.count == 0 }
}

private extension NSError {
    var isRoomCompletedError: Bool {
        domain == TwilioVideoSDK.ErrorDomain && code == TwilioVideoSDK.Error.roomRoomCompletedError.rawValue
    }
    var isParticipantNotFoundError: Bool {
        domain == TwilioVideoSDK.ErrorDomain && code == TwilioVideoSDK.Error.participantNotFoundError.rawValue
    }
}
