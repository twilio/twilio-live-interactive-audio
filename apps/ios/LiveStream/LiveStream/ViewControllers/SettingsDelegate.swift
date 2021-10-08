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

import InAppSettingsKit
import AppCenterCrashes

class SettingsDelegate: NSObject, IASKSettingsDelegate {
    weak var presentingViewController: UIViewController!
    
    func settingsViewControllerDidEnd(_ settingsViewController: IASKAppSettingsViewController) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func settingsViewController(
        _ settingsViewController: IASKAppSettingsViewController,
        buttonTappedFor specifier: IASKSpecifier
    ) {
        switch specifier.key {
        case "SignOut":
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            let signOutAction = UIAlertAction(title: "Sign Out", style: .destructive) { _ in
                self.presentingViewController.dismiss(animated: true) {
                    self.presentingViewController.performSegue(
                        withIdentifier: "SignOut",
                        sender: self.presentingViewController
                    )
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            [signOutAction, cancelAction].forEach { actionSheet.addAction($0) }
            settingsViewController.present(actionSheet, animated: true, completion: nil)
        case "TestCrashReport":
            Crashes.generateTestCrash()
        case "TestDatadog":
            DatadogManager.shared.logger?.debug("Test Datadog integration")
        default:
            break
        }
    }
}
