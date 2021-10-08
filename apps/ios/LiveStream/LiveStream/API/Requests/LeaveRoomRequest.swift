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

struct LeaveRoomRequest: APIRequest {
    struct Parameters: Encodable {
        let passcode: String
        let roomName: String
        let userIdentity: String
    }

    let path = "leave-room"
    let parameters: Parameters
    let responseType = LeaveRoomResponse.self
    
    init(passcode: String, roomName: String, userIdentity: String) {
        parameters = Parameters(passcode: passcode, roomName: roomName, userIdentity: userIdentity)
    }
}
