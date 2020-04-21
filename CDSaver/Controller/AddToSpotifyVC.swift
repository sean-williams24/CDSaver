//
//  AddToSpotifyVC.swift
//  CDSaver
//
//  Created by Sean Williams on 17/04/2020.
//  Copyright © 2020 Sean Williams. All rights reserved.
//

import UIKit

class AddToSpotifyVC: UIViewController {

    @IBOutlet weak var resultsTextLabel: UILabel!
    
    var failedAlbums: [String] = []
    var numberOfAlbumsAdded: Int!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
//        
//        let blurEffect = UIBlurEffect(style: .dark)
//        let blurView = UIVisualEffectView(effect: blurEffect)
//        blurView.translatesAutoresizingMaskIntoConstraints = false
//        view.insertSubview(blurView, at: 0)
//        
//        NSLayoutConstraint.activate([
//        blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
//        blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
//        ])
//        
//        // 1
//        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
//        // 2
//        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
//        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
//        // 3
//        vibrancyView.contentView.addSubview(resultsTextLabel)
//        // 4
//        blurView.contentView.addSubview(vibrancyView)
//        
//        NSLayoutConstraint.activate([
//          vibrancyView.heightAnchor.constraint(equalTo: blurView.contentView.heightAnchor),
//          vibrancyView.widthAnchor.constraint(equalTo: blurView.contentView.widthAnchor),
//          vibrancyView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
//          vibrancyView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor)
//          ])
//
//        NSLayoutConstraint.activate([
//          view.centerXAnchor.constraint(equalTo: vibrancyView.contentView.centerXAnchor),
//          view.centerYAnchor.constraint(equalTo: vibrancyView.contentView.centerYAnchor),
//          ])
        
//        failedAlbums = ["The Killing", "Slipknot"]
        
        resultsTextLabel.text = """
        All Done
        
        \(numberOfAlbumsAdded!) albums added to your Spotify library
        
        
        """
        
        if failedAlbums.count != 0 {
            resultsTextLabel.text?.append("\n\(failedAlbums.count) failed to add:")
            
            for album in failedAlbums {
                resultsTextLabel.text?.append("\n\(album)")
            }
        }
    }

}