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

enum LiveStreamError: Error {
    case conversationSyncFailed
    case invalidTimedMetadata
    case liveStreamEndedByModerator
    case other(message: String)
    case speakerMovedToAudienceByModerator
}

// MARK: - Booleans
extension LiveStreamError {
    var isLiveStreamEndedByModeratorError: Bool {
        if case .liveStreamEndedByModerator = self { return true }
        return false
    }

    var isSpeakerMovedToAudienceByModeratorError: Bool {
        if case .speakerMovedToAudienceByModerator = self { return true }
        return false
    }
}

// MARK: - Descriptions
extension LiveStreamError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .conversationSyncFailed: return "Conversation synchronization failed."
        case .invalidTimedMetadata: return "Invalid timed metadata."
        case .liveStreamEndedByModerator: return "Live stream ended by moderator."
        case let .other(message): return message
        case .speakerMovedToAudienceByModerator: return "Speaker moved to audience by moderator."
        }
    }
}
