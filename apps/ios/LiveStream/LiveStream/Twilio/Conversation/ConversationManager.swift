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

import TwilioConversationsClient

protocol ConversationManagerDelegate: AnyObject {
    func conversationManagerDidConnect(_ conversationManager: ConversationManager)
    func conversationManager(_ conversationManager: ConversationManager, didDisconnectWithError error: Error)
    func conversationManager(_ conversationManager: ConversationManager, didAddParticipant participant: ConversationParticipant)
    func conversationManager(_ conversationManager: ConversationManager, didRemoveParticipant participant: ConversationParticipant)
    func conversationManager(_ conversationManager: ConversationManager, didUpdateParticipant participant: ConversationParticipant)
    func conversationManager(_ conversationManager: ConversationManager, didReceiveMessage message: ConversationMessage)
}

class ConversationManager: NSObject {
    weak var delegate: ConversationManagerDelegate?
    var isHandRaised = false {
        didSet { participants.first { $0.identity == userIdentity }?.isHandRaised = isHandRaised }
    }
    private(set) var participants: [ConversationParticipant] = []
    private var client: TwilioConversationsClient?
    private var conversation: TCHConversation?
    private var userIdentity: String!
    private var conversationSID: String!
    private var isDisconnected: Bool { userIdentity == nil && conversationSID == nil }

    func connect(accessToken: String, userIdentity: String, conversationSID: String) {
        guard isDisconnected else { fatalError("Conversation connection already in progress.") }

        self.userIdentity = userIdentity
        self.conversationSID = conversationSID

        let properties = TwilioConversationsClientProperties()
        
        if let region = API.shared.environment.region {
            properties.region = region /// Only used by Twilio employees for internal testing
        }

        TwilioConversationsClient.conversationsClient(
            withToken: accessToken,
            properties: properties,
            delegate: self
        ) { [weak self] result, client in
            guard let client = client else { self?.handleError(result.error!); return }

            self?.client = client
        }
    }

    func disconnect() {
        client?.shutdown()
        client = nil
        conversation = nil
        participants = []
        isHandRaised = false
        userIdentity = nil
        conversationSID = nil
    }
        
    func sendMessage(message: ConversationMessage) {
        guard let attributes = message.attributes else { return }

        conversation?.prepareMessage().setAttributes(attributes, error: nil).buildAndSend(completion: nil)
    }
    
    private func getConversation() {
        client?.conversation(withSidOrUniqueName: conversationSID) { [weak self] result, conversation in
            guard let self = self else {
                return
            }
            guard let conversation = conversation else {
                self.handleError(result.error!)
                return
            }

            self.conversation = conversation
            self.participants = conversation.participants().map { ConversationParticipant(participant: $0) }
            self.delegate?.conversationManagerDidConnect(self)
        }
    }
    
    private func handleError(_ error: Error) {
        disconnect()
        delegate?.conversationManager(self, didDisconnectWithError: error)
    }
}

extension ConversationManager: TwilioConversationsClientDelegate {
    func conversationsClient(
        _ client: TwilioConversationsClient,
        synchronizationStatusUpdated status: TCHClientSynchronizationStatus
    ) {
        switch status {
        case .started, .conversationsListCompleted: return
        case .completed: getConversation()
        case .failed: handleError(LiveStreamError.conversationSyncFailed)
        @unknown default: return
        }
    }
}

extension ConversationManager: TCHConversationDelegate {
    func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        participantJoined participant: TCHParticipant
    ) {
        let participant = ConversationParticipant(participant: participant)
        participants.append(participant)
        delegate?.conversationManager(self, didAddParticipant: participant)
    }
    
    func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        participantLeft participant: TCHParticipant
    ) {
        guard let index = participants.firstIndex(where: { $0.identity == participant.identity }) else { return }
        
        let participant = participants[index]
        participants.remove(at: index)
        delegate?.conversationManager(self, didRemoveParticipant: participant)
    }
    
    func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        participant: TCHParticipant,
        updated: TCHParticipantUpdate
    ) {
        guard let participant = participants.first(where: { $0.identity == participant.identity }) else { return }

        delegate?.conversationManager(self, didUpdateParticipant: participant)
    }
    
    func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        messageAdded message: TCHMessage
    ) {
        guard let message = ConversationMessage(message: message) else { return }
        
        delegate?.conversationManager(self, didReceiveMessage: message)
    }
}
