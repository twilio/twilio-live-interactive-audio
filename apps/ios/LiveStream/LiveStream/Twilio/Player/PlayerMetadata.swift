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

struct PlayerMetadata: Decodable {
    typealias Identity = String
    
    struct Participant: Decodable {
        /// Volume.
        ///
        /// - Note: Value is -1 when speaker is muted.
        let v: Int
    }
    
    /// Sequence identifier used to detect and discard out of sequence metadata since order is not gauranteed.
    let s: Int
    
    /// Participants.
    let p: [Identity: Participant]
}
