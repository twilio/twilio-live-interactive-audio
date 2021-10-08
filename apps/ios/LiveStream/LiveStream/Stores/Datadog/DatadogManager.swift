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

import Datadog

class DatadogManager {
    static let shared = DatadogManager()
    private(set) var logger: Logger?
    private let appInfoStore = AppInfoStore()
    
    func configure() {
        guard !appInfoStore.datadogClientToken.isEmpty else {
            return // Debug config or no secrets present
        }

        let configuration = Datadog.Configuration
            .builderUsing(clientToken: appInfoStore.datadogClientToken, environment: "prod")
            .set(serviceName: "livestream-interactive-audio-app-ios")
            .build()

        Datadog.initialize(
            appContext: .init(),
            trackingConsent: .granted, // Always granted since Datadog is only used for internal testing
            configuration: configuration
        )
        
        logger = Logger.builder
            .sendNetworkInfo(true)
            .printLogsToConsole(true, usingFormat: .shortWith(prefix: "[Datadog] "))
            .build()

        logger?.addTag(withKey: "group", value: "livestreaming")
        logger?.addTag(withKey: "team", value: "ahoy")
    }
}
