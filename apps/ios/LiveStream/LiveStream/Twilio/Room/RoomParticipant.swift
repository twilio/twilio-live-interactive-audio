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

import TwilioVideo

class RoomParticipant: LiveStreamSpeaker {
    var identity: String { participant.identity }
    var name: String { LiveStreamUserIdentityComponents(identity: identity).name }
    var isModerator: Bool { LiveStreamUserIdentityComponents(identity: identity).role == .moderator }
    var isMuted: Bool {
        guard let micTrack = participant.audioTracks.first else { return true }

        return !micTrack.isTrackEnabled
    }
    var audioLevel = 0
    let participant: Participant
    
    init(participant: Participant) {
        self.participant = participant
    }
}
