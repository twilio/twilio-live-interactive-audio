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

import SwiftyUserDefaults

class AuthStore {
    static let shared = AuthStore()
    var isSignedIn: Bool { keychainStore.passcode != nil && !Defaults.userIdentity.isEmpty }
    var passcode: String? { keychainStore.passcode }
    var userIdentity: String { Defaults.userIdentity }
    private let api = API.shared
    private let keychainStore = KeychainStore()

    func signIn(userIdentity: String, passcode: String, completion: @escaping (Error?) -> Void) {
        let request = GetRoomsRequest(passcode: passcode)
        
        api.request(request) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.keychainStore.passcode = passcode
                Defaults.userIdentity = userIdentity
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }

    func signOut() {
        keychainStore.passcode = nil
        Defaults.removeAll()
    }
}
