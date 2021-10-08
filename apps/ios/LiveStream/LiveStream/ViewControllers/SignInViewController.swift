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

import SVProgressHUD
import UIKit

class SignInViewController: UIViewController {
    @IBOutlet weak var nameLabel: FormTextField!
    @IBOutlet weak var passcodeLabel: FormTextField!
    private let authStore = AuthStore.shared
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        authStore.signOut()
    }
    
    @IBAction func signInTap(_ sender: Any) {
        SVProgressHUD.show()
        
        authStore.signIn(
            userIdentity: nameLabel.text?.trimmingCharacters(in: .whitespaces) ?? "",
            passcode: passcodeLabel.text ?? ""
        ) { [weak self] error in
            SVProgressHUD.dismiss()

            if let error = error {
                self?.present(error: error)
            } else {
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}
