//
//  ImageReaderVC.swift
//  CDSaver
//
//  Created by Sean Williams on 12/02/2020.
//  Copyright © 2020 Sean Williams. All rights reserved.
//

import Firebase
import UIKit
import QCropper

class ImageReaderVC: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    
    // MARK: - Outlets
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var imageLibraryButton: UIButton!
    @IBOutlet weak var blurredEffectView: UIVisualEffectView!
    @IBOutlet weak var coverButtonView: UIView!
    @IBOutlet weak var coverButton: UIButton!
    @IBOutlet weak var buttonStack: UIStackView!
    @IBOutlet weak var albumStackView: UIView!
    @IBOutlet weak var stackButton: UIButton!
    
    
    // MARK: - Properties
    
    let processor = ScaledElementProcessor()
    var albumTitles = [String]()
    let blurEffect = UIBlurEffect(style: .systemChromeMaterialDark)
    var viewingAppleMusic: Bool!
    var spotifyAlbums: [[SpotifyAlbum]] = []
    var appleMusicAlbums: [[AppleMusicAlbum]] = []

    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = false
        
        blurredEffectView.effect = nil
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissBlurView))
        blurredEffectView.addGestureRecognizer(dismissTap)
        
        coverButtonView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        coverButtonView.layer.cornerRadius = 30
        albumStackView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        albumStackView.layer.cornerRadius = 30
        blurredEffectView.isHidden = true
        
        let buttonTint = viewingAppleMusic ? UIColor.systemPink : Style.Colours.spotifyGreen
        
        cameraButton.tintColor = buttonTint
        imageLibraryButton.tintColor = buttonTint
        stackButton.tintColor = buttonTint
        coverButton.tintColor = buttonTint
        navigationController?.navigationBar.tintColor = buttonTint
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        blurredEffectView.effect = nil
        blurredEffectView.isHidden = true
        blurredEffectView.isUserInteractionEnabled = true
    }

    // MARK: - Private Methods
    
    @objc func dismissBlurView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.blurredEffectView.effect = nil
            self.buttonStack.alpha = 0
        }) { _ in
            self.blurredEffectView.isHidden = true
        }
    }
    
    @IBAction func albumCoverExtraction() {
        blurredEffectView.isUserInteractionEnabled = false
        albumTitles.removeAll()
        
        processor.process(in: imageView) { (text, result) in
            guard let result = result else {
                // Show alert
                return
            }
            
            for block in result.blocks {
                var albumName = block.text.withoutSpecialCharacters
                
                if albumName.contains("\n") {
                    var blockArray = albumName.components(separatedBy: "\n")
                    blockArray.removeDuplicates()
                    albumName = blockArray.joined(separator: " ")
                }
                
                if !albumName.isNumeric {
                    self.albumTitles.append(albumName)
                }
            }
            
            if self.viewingAppleMusic {
                  AlbumSearchClient.appleMusicAlbumSearch(with: self.albumTitles.removingDuplicates()) { (appleMusicAlbumResults) in
                      self.appleMusicAlbums = appleMusicAlbumResults
                      self.performSegue(withIdentifier: "showAlbums", sender: self)
                  }
              } else {
                  let albumSearcher = AlbumSearchClient()
                     albumSearcher.spotifyAlbumSearch(with: self.albumTitles.removingDuplicates()) { (spotifyAlbumResults) in
                         self.spotifyAlbums = spotifyAlbumResults
                         self.performSegue(withIdentifier: "showAlbums", sender: self)
                     }
              }
        }
    }
    
    
    @IBAction func albumStackExtraction() {
        blurredEffectView.isUserInteractionEnabled = false
        albumTitles.removeAll()
        
        var tempAlbumArray: [String] = []
        var previousYPosition: CGFloat = 0
        
        processor.process(in: imageView) { (text, result) in
            guard let result = result else {
                print("No titles?")
                // SHOW ALERT
                return
            }
            
            for block in result.blocks {
                var albumName = block.text.withoutSpecialCharacters
                
                if albumName.contains("\n") {
                    var blockArray = albumName.components(separatedBy: "\n")
                    blockArray.removeDuplicates()
                    albumName = blockArray.joined(separator: " ")
                }
                
                // Ensure string is not purely numeric
                if !albumName.isNumeric {
                    if let topLeftPoint = block.cornerPoints?.first as? CGPoint {
                        if previousYPosition == 0 {
                            // First result
                            previousYPosition = topLeftPoint.y
                            tempAlbumArray.append(albumName)
                            
                        } else {
                            // Second result and onward >>>
                            if topLeftPoint.y - previousYPosition < 50 {
                                // On the same disc
                                previousYPosition = topLeftPoint.y
                                
                                for tempAlbum in tempAlbumArray {
                                    let combinedStrings = tempAlbum + " " + albumName
                                    tempAlbumArray.insert(combinedStrings, at: 0)
                                }
                                tempAlbumArray.append(albumName)
                                
                            } else {
                                // New disc
                                // Add temp albums to global array (previous disc)
                                self.albumTitles += tempAlbumArray
                                
                                // clear temp array
                                tempAlbumArray.removeAll()
                                
                                // add first result on next disc to temp array and set Y position
                                tempAlbumArray.append(albumName)
                                previousYPosition = topLeftPoint.y
                            }
                        }
                    }
                }
            }
            self.albumTitles += tempAlbumArray
            print("Extraction complete")
            
            if self.viewingAppleMusic {
                AlbumSearchClient.appleMusicAlbumSearch(with: self.albumTitles.removingDuplicates()) { (appleMusicAlbumResults) in
                    self.appleMusicAlbums = appleMusicAlbumResults
                    self.performSegue(withIdentifier: "showAlbums", sender: self)
                }
            } else {
                let albumSearcher = AlbumSearchClient()
                albumSearcher.spotifyAlbumSearch(with: self.albumTitles.removingDuplicates()) { (spotifyAlbumResults) in
                    self.spotifyAlbums = spotifyAlbumResults
                    self.performSegue(withIdentifier: "showAlbums", sender: self)
                }
            }

        }
    }
    
    // MARK: - Navigation
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! SpotifyAlbumResultsCVC
//        vc.albumTitles = self.albumTitles.removingDuplicates()
        if viewingAppleMusic {
            vc.appleAlbumResults = appleMusicAlbums
            vc.viewingAppleMusic = true
        } else {
            vc.spotifyAlbumResults = spotifyAlbums
            vc.viewingAppleMusic = false
        }
        
    }
    
    // MARK: - Image Picker Delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { return }

        let cropper = CropperViewController(originalImage: image)
        cropper.delegate = self

        picker.dismiss(animated: true) {
            self.present(cropper, animated:  true)
        }
        
        imageView.image = image
    }
    
    // MARK: - Action Methods
    
    @IBAction func imageLibraryButtonTapped(_ sender: Any) {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        vc.allowsEditing = false
        
        present(vc, animated: true)
    }
    
    @IBAction func cameraButtonTapped(_ sender: Any) {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        vc.allowsEditing = false
        vc.showsCameraControls = true
        vc.cameraCaptureMode = .photo
        
        present(vc, animated: true)
    }
    
    
    @IBAction func extractAlbumsTapped(_ sender: Any) {
//        blurredEffectView.alpha = 1
        blurredEffectView.isHidden = false
        UIView.animate(withDuration: 0.4) {
//            self.blurredEffectView.alpha = 1
            self.blurredEffectView.effect = self.blurEffect
            self.buttonStack.alpha = 1
        }

    }
    
    @IBAction func unwindAction(unwindSegue: UIStoryboardSegue) {
        
    }
}


    // MARK: - Extensions

extension ImageReaderVC: CropperViewControllerDelegate {
    
        func cropperDidConfirm(_ cropper: CropperViewController, state: CropperState?) {
            cropper.dismiss(animated: true, completion: nil)

            if let state = state,
                let image = cropper.originalImage.cropped(withCropperState: state) {
    //            cropperState = state
                imageView.image = image
            }
        }
}

extension String {
    var isNumeric: Bool {
        guard self.count > 0 else { return false }
        
        let legitCharacters: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", " ", "-"]
        return Set(self).isSubset(of: legitCharacters)

    }
    
    var withoutSpecialCharacters: String {
        return self.components(separatedBy: CharacterSet.symbols).joined(separator: "")
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
    
    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}


