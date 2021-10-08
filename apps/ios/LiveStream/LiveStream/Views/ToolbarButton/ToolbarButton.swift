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

import UIKit

class ToolbarButton {
    static var createRoom: UIButton { makeToolbarButton(title: "Create new room", systemImageName: "plus") }
    static var mute: UIButton { makeToolbarButton(title: "Mute", systemImageName: "mic") }
    static var unmute: UIButton { makeToolbarButton(title: "Unmute", systemImageName: "mic.slash") }
    static var raiseHand: UIButton { makeToolbarButton(title: "Raise hand", systemImageName: "hand.raised") }
    static var lowerHand: UIButton { makeToolbarButton(title: "Lower hand", systemImageName: "hand.raised.slash") }
    static var moveToAudience: UIButton { makeToolbarButton(title: "Move to audience") }
    
    private static func makeToolbarButton(title: String, systemImageName: String? = nil) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("\(systemImageName != nil ? " " : "")\(title)", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        button.adjustsImageWhenHighlighted = false

        if let systemImageName = systemImageName {
            let configuration = UIImage.SymbolConfiguration(scale: .medium)
            let image = UIImage(systemName: systemImageName, withConfiguration: configuration)
            button.setImage(image, for: .normal)
        }
        
        return button
    }
}

extension UIBarButtonItem {
    static var spacer: UIBarButtonItem {
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }
}
