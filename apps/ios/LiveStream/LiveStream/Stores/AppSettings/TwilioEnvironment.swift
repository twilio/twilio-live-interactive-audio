//
//  Copyright (C) 2022 Twilio, Inc.
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

enum TwilioEnvironment: String, CaseIterable, Identifiable {
    case prod
    case stage
    case dev

    var id: Self {
        self
    }
    
    var videoEnvironment: String {
        switch self {
        case .prod: return "Production"
        case .stage: return "Staging"
        case .dev: return "Development"
        }
    }
    
    var region: String? {
        switch self {
        case .prod: return nil
        case .stage: return "stage-us1"
        case .dev: return "dev-us1"
        }
    }
}
