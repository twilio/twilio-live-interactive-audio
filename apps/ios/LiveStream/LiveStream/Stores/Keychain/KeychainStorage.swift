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

import KeychainAccess

// Inspired by https://medium.com/better-programming/create-the-perfect-userdefaults-wrapper-using-property-wrapper-42ca76005ac8
@propertyWrapper
struct KeychainStorage {
    private let key: String
    private let keychain = Keychain()
    
    init(key: String) {
        self.key = key
    }

    var wrappedValue: String? {
        get { keychain[key] }
        set { keychain[key] = newValue }
    }
}
