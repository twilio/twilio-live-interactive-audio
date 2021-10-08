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

class ParticipantCell: UICollectionViewCell, NibLoadableView {
    struct Badge {
        let systemImageName: String
        
        static let muted = Badge(systemImageName: "mic.slash")
        static let handRaised = Badge(systemImageName: "hand.raised")
    }
    
    // Active speaker uses a special circle view that does not use cornerRadius to draw the circle since
    // it was causing the circle to be distorted when scaling the circle and applying a collection view insert, delete,
    // or move at the same time.
    @IBOutlet weak var activeSpeakerView: CircleView!
    @IBOutlet weak var avatarBorderView: UIView!
    @IBOutlet weak var avatarBackgroundView: UIView!
    @IBOutlet weak var badgeBackgroundView: UIView!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var firstInitialLabel: UILabel!
    @IBOutlet weak var moderatorView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!

    override var bounds: CGRect {
        didSet {
            // https://theswiftdev.com/uicollectionview-cells-with-circular-images-plus-rotation-support/
            layoutIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        activeSpeakerView.circleColor = UIColor(hex: 0x14B053)

        // https://theswiftdev.com/uicollectionview-cells-with-circular-images-plus-rotation-support/
        let circleViews: [UIView] = [avatarBackgroundView, badgeBackgroundView, avatarBorderView]
        circleViews.forEach { $0.layer.cornerRadius = $0.frame.size.width / 2 }
        
        // https://stackoverflow.com/questions/4754392/uiview-with-rounded-corners-and-drop-shadow/34984063
        badgeBackgroundView.layer.shadowColor = UIColor(hex: 0x121C2D).cgColor
        badgeBackgroundView.layer.shadowOpacity = 0.1
        badgeBackgroundView.layer.shadowRadius = 4
        badgeBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    
    func configure(name: String, isModerator: Bool, audioLevel: Int, badge: Badge?) {
        nameLabel.text = name
        firstInitialLabel.text = name.prefix(1).uppercased()
        moderatorView.isHidden = !isModerator
        updateAudioLevel(audioLevel: audioLevel)
        
        if let badge = badge {
            badgeBackgroundView.isHidden = false
            let configuration = UIImage.SymbolConfiguration(weight: .bold)
            let image = UIImage(systemName: badge.systemImageName, withConfiguration: configuration)
            badgeImageView.image = image?.withTintColor(UIColor(hex: 0x4B5671))
        } else {
            badgeBackgroundView.isHidden = true
        }
    }

    func updateAudioLevel(audioLevel: Int) {
        let scale: CGFloat
        let maxGrowth: CGFloat = 0.22 // Max percentage increase that active speaker circle should ever grow
        let maxScale = 1 + maxGrowth // Max value that active speaker circle will be scaled by
        let minSpeakingScale: CGFloat = 1.05 // Min scale to use for speaking so that UI is visible and not just 1 pix thick
        let minAudioLevel = 1_000 // Lower values will not show active speaker UI
        let maxAudioLevel = 10_000 // Higher values will not increase the size of active speaker UI
        
        if audioLevel > maxAudioLevel {
            scale = maxScale
        } else if audioLevel > minAudioLevel {
            scale = max(minSpeakingScale, ((CGFloat(audioLevel) / CGFloat(maxAudioLevel)) * maxGrowth) + 1)
        } else {
            scale = 1.0
        }
        
        UIView.animate(withDuration: 0.1) {
            self.activeSpeakerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
