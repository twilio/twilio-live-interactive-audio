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

struct ConversationMessage {
    enum MessageType: String {
        case speakerInvite = "speaker_invite"
    }

    let messageType: MessageType
    let toParticipantIdentity: String
    var options: TCHMessageOptions? {
        guard let attributes = TCHJsonAttributes(dictionary: dictionary) else { return nil }

        return TCHMessageOptions().withAttributes(attributes, completion: nil)
    }
    private let messageTypeKey = "message_type"
    private let toParticipantIdentityKey = "to_participant_identity"
    private var dictionary: [AnyHashable: Any] {
        [
            messageTypeKey: messageType.rawValue,
            toParticipantIdentityKey: toParticipantIdentity
        ]
    }

    init(messagetype: MessageType, toParticipantIdentity: String) {
        self.messageType = messagetype
        self.toParticipantIdentity = toParticipantIdentity
    }
    
    init?(message: TCHMessage) {
        guard
            let attributes = message.attributes()?.dictionary,
            let rawMessageType = attributes[messageTypeKey] as? String,
            let messageType = MessageType(rawValue: rawMessageType),
            let toParticipantIdentity = attributes[toParticipantIdentityKey] as? String
        else {
            return nil
        }

        self.messageType = messageType
        self.toParticipantIdentity = toParticipantIdentity
    }
}
