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

struct LiveStreamUserIdentityComponents {
    let identity: String
    let name: String
    let role: LiveStreamRole
    
    init(name: String, role: LiveStreamRole) {
        self.name = name
        self.role = role
        identity = role.identityPrefix + name
    }
    
    init(identity: String) {
        self.identity = identity
        role = identity.prefix(2) == "m_" ? .moderator : .audience
        name = String(identity.dropFirst(2))
    }
}

private extension LiveStreamRole {
    var identityPrefix: String {
        switch self {
        case .moderator: return "m_"
        case .speaker, .audience: return "s_"
        }
    }
}
