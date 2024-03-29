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

struct JoinRoomRequest: APIRequest {
    struct Parameters: Encodable {
        let passcode: String
        let userIdentity: String
        let roomName: String
    }

    let path: String
    let parameters: Parameters
    let responseType = JoinRoomResponse.self
    
    init(passcode: String, userIdentity: String, roomName: String, shouldCreateRoom: Bool) {
        parameters = Parameters(passcode: passcode, userIdentity: userIdentity, roomName: roomName)
        
        if shouldCreateRoom {
            path = "create-room"
        } else {
            path = "join-room"
        }
    }
}
