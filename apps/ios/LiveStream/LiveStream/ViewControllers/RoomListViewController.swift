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

import Combine
import UIKit
import SwiftUI

class RoomListViewController: UITableViewController {
    private let authStore = AuthStore.shared
    private let settingsViewModel = GeneralSettingsViewModel()
    private let api = API.shared
    private var rooms: [String] = []
    private var roomName: String?
    private var subscriptions = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView() // Remove empty cells

        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        let createRoomButton = ToolbarButton.createRoom
        createRoomButton.addTarget(self, action: #selector(handleCreateRoomTap), for: .touchUpInside)
        toolbarItems = [.spacer, UIBarButtonItem(customView: createRoomButton), .spacer]
        
        if authStore.isSignedIn {
            refresh()
        }
        
        settingsViewModel.$signOut
            .filter { $0 }
            .sink { [weak self] _ in
                self?.dismiss(animated: true) {
                    self?.performSegue(withIdentifier: "SignOut", sender: self)
                }
            }
            .store(in: &subscriptions)

        let environment = api.environment
        
        switch environment {
        case .stage, .dev:
            let environmentBadge = EnvironmentBadge(environment: environment)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: environmentBadge)
        case .prod:
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // For app launch
        if !authStore.isSignedIn {
            performSegue(withIdentifier: "SignIn", sender: self)
        }
    }
        
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "Room":
            let navigationController = segue.destination as! UINavigationController
            let roomViewController = navigationController.viewControllers.first as! RoomViewController
            
            if let roomName = roomName {
                roomViewController.liveStreamManager = LiveStreamManager(roomName: roomName, shouldCreateRoom: true)
                self.roomName = nil
            } else {
                let selectedRow = tableView.indexPathForSelectedRow!
                let roomName = tableView.cellForRow(at: selectedRow)?.textLabel?.text ?? ""
                roomViewController.liveStreamManager = LiveStreamManager(roomName: roomName, shouldCreateRoom: false)
                tableView.deselectRow(at: selectedRow, animated: true)
            }
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rooms.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RoomCell")!
        cell.textLabel?.text = rooms[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "Room", sender: self)
    }
    
    @IBAction func settingsTap(_ sender: Any) {
        let settingsView = GeneralSettingsView()
            .environmentObject(settingsViewModel)
        let settingsController = UIHostingController(rootView: settingsView)
        present(settingsController, animated: true, completion: nil)
    }
    
    @objc private func handleCreateRoomTap() {
        let alert = UIAlertController(
            title: "Name your Room",
            message: "Provide a descriptive name to let people know what you’ll be chatting about in the Room.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Room name"
            textField.autocapitalizationType = .sentences
            textField.returnKeyType = .done
        }
        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
            guard let textField = alert.textFields?.first else { return }
            
            self.roomName = textField.text
            self.performSegue(withIdentifier: "Room", sender: self)
        }
        alert.addAction(createAction)
        let cancelAction = UIAlertAction(title: "Never mind", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func refresh() {
        let request = GetRoomsRequest(passcode: authStore.passcode ?? "")
        
        api.request(request) { [weak self] result in
            switch result {
            case let .success(response):
                self?.rooms = response.rooms.map { $0.roomName }
                self?.tableView.reloadData()
                self?.refreshControl?.endRefreshing()
            case let .failure(error):
                self?.refreshControl?.endRefreshing()
                self?.present(error: error)
            }
        }
    }
}
