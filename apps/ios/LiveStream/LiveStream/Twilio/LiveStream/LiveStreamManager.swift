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

import Foundation

protocol LiveStreamDelegate: AnyObject {
    func liveStreamManagerIsConnecting(_ liveStreamManager: LiveStreamManager)
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didConnectWithError error: Error?)
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didDisconnectWithError error: Error)
    func liveStreamManagerDidInsertOrDeleteOrMoveParticipants(_ liveStreamManager: LiveStreamManager)
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didUpdateSpeakerAt index: Int)
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didUpdateAudienceAt index: Int)
    func liveStreamManagerDidReceiveSpeakerInvite(_ liveStreamManager: LiveStreamManager)
    func liveStreamManagerWasMutedByModerator(_ liveStreamManager: LiveStreamManager)
}

class LiveStreamManager {
    weak var delegate: LiveStreamDelegate?
    let roomName: String
    var speakers: [LiveStreamSpeaker] { speakerSource?.speakers ?? [] }
    var audience: [LiveStreamAudience] = []
    var isMuted: Bool {
        get { roomManager.isMuted }
        set { roomManager.isMuted = newValue }
    }
    var isHandRaised: Bool {
        get { conversationManager.isHandRaised }
        set { conversationManager.isHandRaised = newValue }
    }
    var userIdentity: String { LiveStreamUserIdentityComponents(name: authStore.userIdentity, role: role).identity }
    private(set) var state: LiveStreamState = .disconnected
    private(set) var role: LiveStreamRole
    private let conversationManager = ConversationManager()
    private let roomManager = RoomManager()
    private let playerManager = PlayerManager()
    private let api = API.shared
    private let authStore = AuthStore.shared
    private var speakerSource: LiveStreamSpeakerSource?
    private var error: Error?

    init(roomName: String, shouldCreateRoom: Bool) {
        self.roomName = roomName
        role = shouldCreateRoom ? .moderator : .audience
        roomManager.delegate = self
        playerManager.delegate = self
        conversationManager.delegate = self
    }
    
    func connect() {
        guard state == .disconnected else { fatalError("Live stream connection already in progress.") }
        
        state = .connecting
        
        /// Set environment variable used by `TwilioVideo` and `TwilioLivePlayer`. This is only used by Twilio employees for internal testing.
        setenv("TWILIO_ENVIRONMENT", api.environment.videoEnvironment, 1)
        
        delegate?.liveStreamManagerIsConnecting(self)

        let request = JoinRoomRequest(
            passcode: authStore.passcode ?? "",
            userIdentity: userIdentity,
            roomName: roomName,
            shouldCreateRoom: role == .moderator
        )
        
        api.request(request) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(response):
                self.roomManager.configure(accessToken: response.token, roomName: self.roomName)
                self.playerManager.configure(accessToken: response.token, userIdentity: self.userIdentity)
                self.conversationManager.connect(
                    accessToken: response.token,
                    userIdentity: self.userIdentity,
                    conversationSID: response.conversationSid
                )
            case let .failure(error):
                self.handleError(error)
            }
        }
    }
    
    func disconnect() {
        state = .disconnected
        conversationManager.disconnect()
        roomManager.disconnect()
        playerManager.disconnect()
        audience.removeAll()
        
        switch role {
        case .moderator:
            let request = DeleteRoomRequest(passcode: authStore.passcode ?? "", roomName: roomName)
            api.request(request)
        case .speaker, .audience:
            role = .audience
            let request = LeaveRoomRequest(
                passcode: authStore.passcode ?? "",
                roomName: roomName,
                userIdentity: userIdentity
            )
            api.request(request)
        }
    }
    
    /// Moderator send speaker invite to audience member.
    func sendSpeakerInvite(to audience: LiveStreamAudience) {
        let message = ConversationMessage(messagetype: .speakerInvite, toParticipantIdentity: audience.identity)
        conversationManager.sendMessage(message: message)
    }
    
    /// Moderator mute a speaker.
    func muteSpeaker(_ speaker: LiveStreamSpeaker) {
        let message = RoomMessage(messageType: .mute, toParticipantIdentity: speaker.identity)
        roomManager.sendMessage(message)
    }
    
    /// Moderator move speaker to audience.
    func moveSpeakerToAudience(_ speaker: LiveStreamSpeaker) {
        let request = RemoveSpeakerRequest(passcode: authStore.passcode ?? "", roomName: roomName, userIdentity: speaker.identity)
        api.request(request)
    }

    /// Audience member accept speaker invite.
    func acceptSpeakerInvite() {
        role = .speaker
        state = .connecting
        delegate?.liveStreamManagerIsConnecting(self)
        joinSpeakers()
    }

    /// Speaker return to audience.
    func leaveSpeakers() {
        role = .audience
        state = .connecting
        delegate?.liveStreamManagerIsConnecting(self)
        joinAudience()
    }

    private func joinSpeakers() {
        playerManager.pause()
        roomManager.connect()
        speakerSource = roomManager
    }
    
    private func joinAudience() {
        roomManager.disconnect()
        playerManager.connect()
        speakerSource = playerManager
        conversationManager.isHandRaised = false
    }
    
    private func handleError(_ error: Error) {
        disconnect()
        delegate?.liveStreamManager(self, didDisconnectWithError: error)
    }
    
    @discardableResult private func moveRaisedHandsToFront() -> Bool {
        let sorted = audience.sorted { $0.isHandRaised && !$1.isHandRaised }
        
        if !sorted.difference(from: audience, by: { $0.identity == $1.identity }).isEmpty {
            audience = sorted
            return true
        } else {
            return false
        }
    }
}

extension LiveStreamManager: ConversationManagerDelegate {
    func conversationManagerDidConnect(_ conversationManager: ConversationManager) {
        switch role {
        case .moderator, .speaker: joinSpeakers()
        case .audience: joinAudience()
        }
    }
    
    func conversationManager(_ conversationManager: ConversationManager, didDisconnectWithError error: Error) {
        handleError(error)
    }
    
    func conversationManager(
        _ conversationManager: ConversationManager,
        didAddParticipant participant: ConversationParticipant
    ) {
        guard state != .connecting else { return }

        audience.append(participant)
        delegate?.liveStreamManagerDidInsertOrDeleteOrMoveParticipants(self)
    }

    func conversationManager(
        _ conversationManager: ConversationManager,
        didRemoveParticipant participant: ConversationParticipant
    ) {
        guard state != .connecting else { return }

        audience.removeAll { $0.identity == participant.identity }
        delegate?.liveStreamManagerDidInsertOrDeleteOrMoveParticipants(self)
    }

    func conversationManager(
        _ conversationManager: ConversationManager,
        didUpdateParticipant participant: ConversationParticipant
    ) {
        guard
            state != .connecting,
            let index = self.audience.firstIndex(where: { $0.identity ==  participant.identity })
        else {
            return
        }

        delegate?.liveStreamManager(self, didUpdateAudienceAt: index)
        
        if moveRaisedHandsToFront() {
            delegate?.liveStreamManagerDidInsertOrDeleteOrMoveParticipants(self)
        }
    }
    
    func conversationManager(
        _ conversationManager: ConversationManager,
        didReceiveMessage message: ConversationMessage
    ) {
        guard state != .connecting, message.toParticipantIdentity == userIdentity else { return }
        
        switch message.messageType {
        case .speakerInvite: delegate?.liveStreamManagerDidReceiveSpeakerInvite(self)
        }
    }
}

extension LiveStreamManager: RoomManagerDelegate {
    func roomManager(_ roomManager: RoomManager, didReceiveMessage message: RoomMessage) {
        guard state != .connecting, message.toParticipantIdentity == userIdentity else { return }
        
        switch message.messageType {
        case .mute:
            isMuted = true
            delegate?.liveStreamManagerWasMutedByModerator(self)
        }
    }
}

extension LiveStreamManager: LiveStreamSpeakerSourceDelegate {
    func speakerSourceDidConnect(_ speakerSource: LiveStreamSpeakerSource) {
        audience = conversationManager.participants.filter { participant in
            !speakers.contains { $0.identity == participant.identity }
        }
        moveRaisedHandsToFront()
        state = .connected
        delegate?.liveStreamManager(self, didConnectWithError: error)
        error = nil
    }

    func speakerSource(_ speakerSource: LiveStreamSpeakerSource, didDisconnectWithError error: Error) {
        if let error = error as? LiveStreamError, error.isSpeakerMovedToAudienceByModeratorError {
            self.error = error
            leaveSpeakers()
        } else {
            handleError(error)
        }
    }

    func speakerSource(_ speakerSource: LiveStreamSpeakerSource, didAddSpeaker speaker: LiveStreamSpeaker) {
        guard state != .connecting else { return }

        audience.removeAll { $0.identity == speaker.identity }
        delegate?.liveStreamManagerDidInsertOrDeleteOrMoveParticipants(self)
    }
    
    func speakerSource(_ speakerSource: LiveStreamSpeakerSource, didRemoveSpeaker speaker: LiveStreamSpeaker) {
        guard
            state != .connecting,
            let participant = conversationManager.participants.first(where: { $0.identity == speaker.identity })
        else {
            return
        }
        
        audience.append(participant)
        delegate?.liveStreamManagerDidInsertOrDeleteOrMoveParticipants(self)
        
        if moveRaisedHandsToFront() {
            delegate?.liveStreamManagerDidInsertOrDeleteOrMoveParticipants(self)
        }
    }

    func speakerSource(_ speakerSource: LiveStreamSpeakerSource, didUpdateSpeaker speaker: LiveStreamSpeaker) {
        guard
            state != .connecting,
            let index = speakers.firstIndex(where: { $0.identity == speaker.identity })
        else {
            return
        }

        delegate?.liveStreamManager(self, didUpdateSpeakerAt: index)
    }
}
