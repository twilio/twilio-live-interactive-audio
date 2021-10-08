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

class RoomViewController: UICollectionViewController {
    enum Section: Int, CaseIterable {
        case speakers
        case audience
    }
    
    struct Item: Hashable {
        let section: Section
        let identity: String
    }
    
    var liveStreamManager: LiveStreamManager!
    private lazy var dataSource = makeDataSource()
    private var audioLevelTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        liveStreamManager.delegate = self
        liveStreamManager.connect()
        UIApplication.shared.isIdleTimerDisabled = true
        configureToolbar()
        collectionView.collectionViewLayout = makeLayout()
        collectionView.register(
            SpeakersHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            AudienceHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(ParticipantCell.self)
        
        // Just using a Timer here since we only get real audio samples from the video room
        // and live stream at 2 Hz. And so the active speaker samples and animation is more of an approximation.
        audioLevelTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(handleAudioLevelTimer),
            userInfo: nil,
            repeats: true
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if liveStreamManager.state == .connecting {
            SVProgressHUD.show()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    @IBAction func leaveTap(_ sender: Any) {
        if liveStreamManager.role == .moderator && (liveStreamManager.speakers.count > 1 || liveStreamManager.audience.count > 0) {
            let menu = UIAlertController(
                title: "Are you sure?",
                message: "Leaving will end the Room instance for all participants.",
                preferredStyle: .alert
            )
            let deleteRoomAction = UIAlertAction(title: "Leave room", style: .destructive) { _ in
                self.disconnect()
                self.dismiss(animated: true, completion: nil)
            }
            let cancelAction = UIAlertAction(title: "Never mind", style: .cancel)
            [deleteRoomAction, cancelAction].forEach { menu.addAction($0) }
            present(menu, animated: true, completion: nil)
        } else {
            disconnect()
            dismiss(animated: true, completion: nil)
        }
    }
    
    private func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int,
          layoutEnvironment: NSCollectionLayoutEnvironment)
            -> NSCollectionLayoutSection? in

            switch Section.allCases[sectionIndex] {
            case .speakers: return self.makeSectionLayout(itemsPerRow: 3, spaceBetweenItems: 15, leadingAndTrailingSpace: 20)
            case .audience: return self.makeSectionLayout(itemsPerRow: 4, spaceBetweenItems: 18, leadingAndTrailingSpace: 25)
          }
        }
        
        return layout
    }
    
    private func makeSectionLayout(itemsPerRow: Int, spaceBetweenItems: CGFloat, leadingAndTrailingSpace: CGFloat) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(50)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(50)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitem: item,
            count: itemsPerRow
        )
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leadingAndTrailingSpace, bottom: 0, trailing: leadingAndTrailingSpace)
        group.interItemSpacing = .fixed(spaceBetweenItems)
        let section = NSCollectionLayoutSection(group: group)
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(50)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        section.interGroupSpacing = 25

        return section
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView,
            cellProvider: { collectionView, indexPath, item in // Make sure I don't need weak self
                let cell: ParticipantCell = collectionView.dequeueReusableCell(for: indexPath)
                switch Section(rawValue: indexPath.section)! {
                case .speakers: cell.configure(speaker: self.liveStreamManager.speakers[indexPath.row])
                case .audience: cell.configure(audience: self.liveStreamManager.audience[indexPath.row])
                }
                return cell
            }
        )
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                switch Section(rawValue: indexPath.section)! {
                case .speakers:
                    let view: SpeakersHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath)
                    view.configure(roomName: self.liveStreamManager.roomName)
                    return view
                case .audience:
                    let view: AudienceHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath)
                    return view
                }
            default:
                fatalError()
            }
        }
        
        return dataSource
    }
    
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.speakers, .audience])
        snapshot.appendItems(liveStreamManager.speakers.map { Item(section: .speakers, identity: $0.identity) }, toSection: .speakers)
        snapshot.appendItems(liveStreamManager.audience.map { Item(section: .audience, identity: $0.identity) }, toSection: .audience)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    private func configureToolbar() {
        switch liveStreamManager.role {
        case .moderator:
            let muteButton = liveStreamManager.isMuted ? ToolbarButton.unmute : ToolbarButton.mute
            muteButton.addTarget(self, action: #selector(handleMuteButtonTap), for: .touchUpInside)
            toolbarItems = [.spacer, UIBarButtonItem(customView: muteButton), .spacer]
        case .speaker:
            let muteButton = liveStreamManager.isMuted ? ToolbarButton.unmute : ToolbarButton.mute
            muteButton.addTarget(self, action: #selector(handleMuteButtonTap), for: .touchUpInside)
            let moveToAudienceButton = ToolbarButton.moveToAudience
            moveToAudienceButton.addTarget(self, action: #selector(handleMoveToAudienceButtonTap), for: .touchUpInside)
            toolbarItems = [UIBarButtonItem(customView: muteButton), .spacer, UIBarButtonItem(customView: moveToAudienceButton)]
        case .audience:
            let raiseHandButton = liveStreamManager.isHandRaised ? ToolbarButton.lowerHand : ToolbarButton.raiseHand
            raiseHandButton.addTarget(self, action: #selector(handleRaiseHandButtonTap), for: .touchUpInside)
            toolbarItems = [.spacer, UIBarButtonItem(customView: raiseHandButton), .spacer]
        }
    }
    
    @objc private func handleMuteButtonTap() {
        liveStreamManager.isMuted.toggle()
        configureToolbar()
    }
    
    @objc private func handleMoveToAudienceButtonTap() {
        let message = "This will place you back in the audience where you can raise your hand to join the conversation again."
        let alert = UIAlertController(
            title: "Move to Audience?",
            message: message,
            preferredStyle: .alert
        )
        let joinAudienceAction = UIAlertAction(title: "Move", style: .destructive) { _ in
            self.liveStreamManager.leaveSpeakers()
        }
        let cancelAction = UIAlertAction(title: "Never mind", style: .cancel)
        [joinAudienceAction, cancelAction].forEach { alert.addAction($0) }
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func handleRaiseHandButtonTap() {
        if liveStreamManager.isHandRaised {
            liveStreamManager.isHandRaised.toggle()
            configureToolbar()
        } else {
            let message = "This will let the speakers know you have something you’d like to say."
            let alert = UIAlertController(
                title: "Raise your hand?",
                message: message,
                preferredStyle: .alert
            )
            let raiseHandAction = UIAlertAction(title: "Raise hand", style: .default) { _ in
                self.liveStreamManager.isHandRaised.toggle()
                self.configureToolbar()
            }
            let cancelAction = UIAlertAction(title: "Never mind", style: .cancel)
            [raiseHandAction, cancelAction].forEach { alert.addAction($0) }
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section), liveStreamManager.role == .moderator else { return }
        
        switch section {
        case .speakers:
            let participant = liveStreamManager.speakers[indexPath.item]
            
            guard participant.identity != liveStreamManager.userIdentity else { return } // Don't tap on me
            
            let menu = UIAlertController(title: participant.name, message: nil, preferredStyle: .actionSheet)
            let muteAction = UIAlertAction(title: "Mute speaker", style: .default) { _ in
                self.liveStreamManager.muteSpeaker(participant)
            }
            let moveToAudienceAction = UIAlertAction(title: "Move to audience", style: .default) { _ in
                self.liveStreamManager.moveSpeakerToAudience(participant)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            if !participant.isMuted {
                menu.addAction(muteAction)
            }
            menu.addAction(moveToAudienceAction)
            menu.addAction(cancelAction)
            present(menu, animated: true, completion: nil)
        case .audience:
            let participant = liveStreamManager.audience[indexPath.item]
            
            guard participant.identity != AuthStore.shared.userIdentity else { return } // Don't tap on me
            guard participant.isHandRaised else { return }
            
            let menu = UIAlertController(title: participant.name, message: nil, preferredStyle: .actionSheet)
            let inviteToSpeakAction = UIAlertAction(title: "Invite to speak", style: .default) { _ in
                self.liveStreamManager.sendSpeakerInvite(to: participant)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            [inviteToSpeakAction, cancelAction].forEach { menu.addAction($0) }
            present(menu, animated: true, completion: nil)
        }
    }
    
    private func showForceLeaveAlert() {
        let alert = UIAlertController(
            title: "Moved to Audience",
            message: "You have been moved to the audience by a moderator.",
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

    @objc private func handleAudioLevelTimer() {
        // We only receive 2 real audio level samples per second for each speaker. This is not enough
        // samples to make it obvious that the active speaker UI represents real-time audio level.
        // So generate some fake samples by adding a little jitter to make the active speaker UI more intuitive.
        
        guard liveStreamManager.state == .connected else { return }
        
        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard Section(rawValue: indexPath.section) == .speakers else { return }
            
            let speaker = self.liveStreamManager.speakers[indexPath.item]

            guard speaker.audioLevel > 1_000 else { return } // Don't add random jitter if audio level is low
            
            let randomJitter = Int.random(in: -2_000...2_000)

            let cell = self.collectionView.cellForItem(at: indexPath) as! ParticipantCell

            cell.updateAudioLevel(audioLevel: max(0, speaker.audioLevel + randomJitter))
        }
    }
    
    private func disconnect() {
        liveStreamManager.disconnect()
        audioLevelTimer?.invalidate()
    }
}

extension RoomViewController: LiveStreamDelegate {
    func liveStreamManagerIsConnecting(_ liveStreamManager: LiveStreamManager) {
        guard viewIfLoaded?.window != nil else { return } // View is not visible yet
        
        SVProgressHUD.show()
    }
    
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didConnectWithError error: Error?) {
        SVProgressHUD.dismiss()
        configureToolbar()
        applySnapshot(animatingDifferences: true) // Handles inserts, deletes, and moves

        // Get updates that were ignored during role change
        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard let cell = collectionView.cellForItem(at: indexPath) as? ParticipantCell else { return }

            switch Section(rawValue: indexPath.section)! {
            case .speakers: cell.configure(speaker: liveStreamManager.speakers[indexPath.item])
            case .audience: cell.configure(audience: liveStreamManager.audience[indexPath.item])
            }
        }

        if let error = error as? LiveStreamError, error.isSpeakerMovedToAudienceByModeratorError {
            showForceLeaveAlert()
        }
    }

    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didDisconnectWithError error: Error) {
        SVProgressHUD.dismiss()

        if let error = error as? LiveStreamError, error.isLiveStreamEndedByModeratorError {
            let alert = UIAlertController(
                title: "Room is no longer available",
                message: "This room has been ended by the Room moderator.",
                preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.dismiss(animated: true, completion: nil)
            }
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
        } else {
            present(error: error) { self.dismiss(animated: true, completion: nil) }
        }
    }
    
    func liveStreamManagerDidInsertOrDeleteOrMoveParticipants(_ liveStreamManager: LiveStreamManager) {
        applySnapshot(animatingDifferences: true)
    }
    
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didUpdateSpeakerAt index: Int) {
        let indexPath = IndexPath(item: index, section: Section.speakers.rawValue)
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? ParticipantCell else { return }
        
        cell.configure(speaker: liveStreamManager.speakers[index])
    }
    
    func liveStreamManager(_ liveStreamManager: LiveStreamManager, didUpdateAudienceAt index: Int) {
        let indexPath = IndexPath(item: index, section: Section.audience.rawValue)

        guard let cell = collectionView.cellForItem(at: indexPath) as? ParticipantCell else { return }

        cell.configure(audience: liveStreamManager.audience[index])
    }

    func liveStreamManagerDidReceiveSpeakerInvite(_ liveStreamManager: LiveStreamManager) {
        let alert = UIAlertController(
            title: "You have been invited to join as a speaker",
            message: nil,
            preferredStyle: .alert
        )
        let joinAction = UIAlertAction(title: "Join", style: .default) { _ in
            self.liveStreamManager.acceptSpeakerInvite()
        }
        alert.addAction(joinAction)
        let cancelAction = UIAlertAction(title: "Not now", style: .cancel) { _ in
            self.liveStreamManager.isHandRaised = false
            self.configureToolbar()
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    func liveStreamManagerWasMutedByModerator(_ liveStreamManager: LiveStreamManager) {
        configureToolbar()
    }
}

private extension ParticipantCell {
    func configure(speaker: LiveStreamSpeaker) {
        configure(
            name: speaker.name,
            isModerator: speaker.isModerator,
            audioLevel: speaker.audioLevel,
            badge: speaker.isMuted ? .muted : nil
        )
    }
    
    func configure(audience: LiveStreamAudience) {
        configure(
            name: audience.name,
            isModerator: false,
            audioLevel: 0,
            badge: audience.isHandRaised ? .handRaised : nil
        )
    }
}
