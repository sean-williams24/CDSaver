//
//  SpotifyAlbumResultsCVC.swift
//  CDSaver
//
//  Created by Sean Williams on 08/04/2020.
//  Copyright © 2020 Sean Williams. All rights reserved.
//

import Alamofire
import FSPagerView
import Kingfisher
import UIKit

class SpotifyAlbumResultsCVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Outlets
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var alternativeAlbumsView: UIView!
    @IBOutlet weak var alternativeAlbumsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoButton: RoundButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var goButton: RoundButton!
    @IBOutlet weak var addAlbumsButton: UIView!
    @IBOutlet weak var deleteButton: RoundButton!
    @IBOutlet weak var pagerView: FSPagerView! {
        didSet {
            self.pagerView.register(PagerViewCell.self, forCellWithReuseIdentifier: "cell")
        }
    }
    @IBOutlet weak var logoImageView: UIImageView!
    
    
    // MARK: - Properties
    
    var albumResults = [[Album]]()
    var albumGroup = [Album]()
    var failedAlbums: [String] = []
    var numberOfAlbumsAdded = 0
    private let sectionInsets = UIEdgeInsets(top: 0, left: 10.0, bottom: 15.0, right: 10.0)
    var itemsPerRow: CGFloat = 2
    let albumsViewHeight: CGFloat = 290
    var altAlbumsViewStartLocation: CGPoint!
    var originalPoint: CGPoint!
    let newInfoViewMinHeight: CGFloat = 0.0
    var newInfoViewMaxHeight: CGFloat = 110.0
    var albumResultsIndex: Int!
    var selectedAlbums: [IndexPath] = []
    var blurredEffect = UIVisualEffectView()
    var deleting: Bool! {
        didSet {
            deleteButton.isEnabled = deleting
            deleteButton.tintColor = deleting ? .red : .white
        }
    }
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.contentInsetAdjustmentBehavior = .never
        alternativeAlbumsView.backgroundColor = .clear
        alternativeAlbumsViewHeightConstraint.constant = 0
        infoViewHeightConstraint.constant = 0
        collectionView.allowsMultipleSelection = true
        infoView.layer.borderWidth = 0.8

        
        pagerView.transformer = FSPagerViewTransformer(type: .linear)
        let width = view.frame.width / 2
        pagerView.itemSize = CGSize(width: width, height: width)
        pagerView.isUserInteractionEnabled = true
        pagerView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        pagerView.interitemSpacing = 60
//        pagerView.layer.cornerRadius = 10
//        pagerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        let dismissSwipe = UIPanGestureRecognizer(target: self, action: #selector(handleAltAlbumsViewSwipe))
        alternativeAlbumsView.addGestureRecognizer(dismissSwipe)
                
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissAltAlbumsView))
        blurredEffect.addGestureRecognizer(dismissTap)
        blurredEffect.effect = nil
        blurredEffect.alpha = 0.9
        view.addSubview(blurredEffect)
        blurredEffect.translatesAutoresizingMaskIntoConstraints = false
        blurredEffect.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        blurredEffect.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        blurredEffect.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        blurredEffect.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        blurredEffect.isHidden = true
        
        deleting = false
        addAlbumsButton.alpha = 0
        
        let attributedInfoText = NSMutableAttributedString(string: """
            - Tap + button to choose from alternative options
            - Tap albums to delete
            - Add albums to your Spotify library by tapping GO
            """)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.alignment = .left
        attributedInfoText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: 60))
        infoLabel.attributedText = attributedInfoText
        
        addAlbumsButton.backgroundColor = Settings.spotifyGreen
        addAlbumsButton.layer.cornerRadius = 30
        
    }
    

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    
    // MARK: - Private Methods
    
    fileprivate func showBlurredFXView(_ showBlur: Bool) {
        
        if showBlur {
            blurredEffect.isHidden = false
            view.bringSubviewToFront(alternativeAlbumsView)
            
            UIView.animate(withDuration: 0.4) {
                let blurFX = UIBlurEffect(style: .systemThickMaterialDark)
                self.blurredEffect.effect = blurFX
            }
        } else {
            UIView.animate(withDuration: 0.4, animations: {
                self.blurredEffect.effect = nil
            }) { _ in
                self.blurredEffect.isHidden = true
            }
        }
    }
    
    @objc func dismissAltAlbumsView() {
        alternativeAlbumsViewHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        })
        showBlurredFXView(false)
    }
    
    
    @objc func handleAltAlbumsViewSwipe(_ gesture: UIPanGestureRecognizer) {
        
        let swipeDistancePoint = gesture.translation(in: view)
        
        guard let albumsView = gesture.view else { return }
        let newYPointToSet = albumsView.center.y + swipeDistancePoint.y
        
        switch gesture.state {
        case .began:
            print("")

        case .changed:
            if newYPointToSet <= originalPoint.y {
                return
            } else {
                albumsView.center = CGPoint(x: albumsView.center.x, y: newYPointToSet)
                gesture.setTranslation(.zero, in: view)
            }

        case .ended:
            let midPoint = originalPoint.y + (albumsViewHeight / 2)
            if newYPointToSet > midPoint {
                alternativeAlbumsViewHeightConstraint.constant = 0
                UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
                    self.view.layoutIfNeeded()
                })

                showBlurredFXView(false)
                
            } else {
                UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
                    albumsView.center = CGPoint(x: albumsView.center.x, y: self.originalPoint.y)
                })
            }
            
        default:
            break
        }
    }

    fileprivate func animateDropDownView() {
        if infoViewHeightConstraint.constant == newInfoViewMinHeight {
            self.infoViewHeightConstraint.constant = newInfoViewMaxHeight
        } else {
            self.infoViewHeightConstraint.constant = newInfoViewMinHeight
        }
        
        UIView.animate(withDuration: 0.4) {
            self.view.layoutIfNeeded()
        }
    }
    
    
    // MARK: - Action Methods

    @IBAction func alternativeAlbumsButtonTapped(_ sender: UIButton) {
        
        showBlurredFXView(true)
        
        albumGroup = albumResults[sender.tag]
        albumResultsIndex = sender.tag
        pagerView.reloadData()
        
        alternativeAlbumsViewHeightConstraint.constant = alternativeAlbumsViewHeightConstraint.constant == albumsViewHeight ? 0 : albumsViewHeight
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }) { _ in
            self.originalPoint = self.alternativeAlbumsView.center
        }
    }
    
    
    @IBAction func infoButtonTapped(_ sender: Any) {
        if infoViewHeightConstraint.constant == newInfoViewMinHeight {
            addAlbumsButton.alpha = 0
            infoLabel.isHidden = false
            animateDropDownView()
        } else if infoViewHeightConstraint.constant != newInfoViewMinHeight && infoLabel.isHidden == true {
            self.infoViewHeightConstraint.constant = newInfoViewMinHeight
            UIView.animate(withDuration: 0.4, animations: {
                self.view.layoutIfNeeded()
            }) { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    self.logoImageView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                    self.addAlbumsButton.alpha = 0
                }) { _ in

                }
                self.infoLabel.isHidden = false
                self.animateDropDownView()
            }
        } else {
            animateDropDownView()
        }
    }
        
    
    
    @IBAction func goButtonTapped(_ sender: Any) {
        if infoViewHeightConstraint.constant == newInfoViewMinHeight {
            infoLabel.isHidden = true
            UIView.animate(withDuration: 0.4) {
                self.logoImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
                self.addAlbumsButton.alpha = 1
            }
            animateDropDownView()
        } else if infoViewHeightConstraint.constant != newInfoViewMinHeight && infoLabel.isHidden == false {
            self.infoViewHeightConstraint.constant = newInfoViewMinHeight
            UIView.animate(withDuration: 0.4, animations: {
                self.view.layoutIfNeeded()
            }) { _ in
                self.infoLabel.isHidden = true
                UIView.animate(withDuration: 0.4) {
                    self.logoImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
                    self.addAlbumsButton.alpha = 1
                }
                self.animateDropDownView()
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.logoImageView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                self.addAlbumsButton.alpha = 0
            }) { _ in
            }
            self.animateDropDownView()

        }
    }
    
    
    @IBAction func addAlbumsButtonTapped(_ sender: Any) {
//        showBlurredFXView(true)
        blurredEffect.isUserInteractionEnabled = false
        
        let accessToken = UserDefaults.standard.string(forKey: "access-token-key") ?? "NO_ACCESS_TOKEN"
        print(albumResults.count)
        var index = 0
        let totalAlbums = albumResults.count
        for albumCollection in self.albumResults {
             if let album = albumCollection.first {
                 let addAlbumsURL = "https://api.spotify.com/v1/me/albums?ids=\(album.id)"
                 
                 AF.request(addAlbumsURL, method: .put, parameters: ["ids": album.id], encoding: URLEncoding.default, headers: ["Authorization": "Bearer "+accessToken]).response { (response) in
                    
                     if let statusCode = response.response?.statusCode {
                         if statusCode == 200 {
                            print("\(album.name) Added to spotify")
                            self.numberOfAlbumsAdded += 1
//                            self.albumResults.removeAll { (albumArray) -> Bool in
//                                return albumArray.first?.id == albumCollection.first?.id
//                            }
                            
                            for (i, albumArray) in self.albumResults.enumerated() {
                                if albumArray.first?.id == albumCollection.first?.id {
                                    self.albumResults.remove(at: i)
                                    self.collectionView.deleteItems(at: [IndexPath(item: i, section: 0)])
                                    print("\(album.name) removed from results")
                                    index += 1
                                }
                            }
//                            self.blurredEffect.isUserInteractionEnabled = true
//                             self.showBlurredFXView(false)
                             
                         } else {
                            print("\(album.name) failed to add")
                            if let artist = album.artists.first {
                                self.failedAlbums.append("\(artist.name) - \(album.name)")
                            } else {
                                self.failedAlbums.append(album.name)
                            }
                            index += 1
                        }
                     }
                    print(index)
                    if index == totalAlbums {
                        print("Completion")
                        self.performSegue(withIdentifier: "addAlbumsCompletion", sender: self)
                    }
                 }
             }
         }
    }
    
    
    @IBAction func deleteButtonTapped(_ sender: Any) {
        for indexPath in selectedAlbums.sorted().reversed() {
            albumResults.remove(at: indexPath.item)
        }
        
        self.collectionView.performBatchUpdates({
            self.collectionView.deleteItems(at: selectedAlbums)
        }) { _ in
            self.selectedAlbums.removeAll()
            self.collectionView.reloadData()
            self.deleting = !self.selectedAlbums.isEmpty

        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! AddToSpotifyVC
        vc.failedAlbums = self.failedAlbums
        vc.numberOfAlbumsAdded = self.numberOfAlbumsAdded
    }

    
    // MARK: - UICollectionViewDataSource + Delegate


    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albumResults.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "albumCell", for: indexPath) as! AlbumCVCell
        cell.imageView.backgroundColor = .white
        let albumGroup = albumResults[indexPath.item]
        
        if !albumGroup.isEmpty {
            let firstAlbum = albumGroup[0]
            let albumCoverString = firstAlbum.images[0].url
            
//            print("ALBUM NAME: \(firstAlbum.name)")
//            print("AMOUNT OF OPTIONS: \(albumGroup.count)")
            
            if albumGroup.count == 1 {
                cell.alternativesButtonView.isHidden = true
            } else {
                cell.alternativesButtonView.isHidden = false
            }
            
            cell.albumTitleTextLabel.text = firstAlbum.name
            cell.artistTextLabel.text = firstAlbum.artists[0].name
            cell.alternativesButton.tag = indexPath.item
            
            // Download and cahce album cover image
            let imageURL = URL(string: albumCoverString)
            cell.imageView.kf.setImage(with: imageURL)
            
            let processor = DownsamplingImageProcessor(size: cell.imageView.bounds.size)
                |> RoundCornerImageProcessor(cornerRadius: 3)

            cell.imageView.kf.indicatorType = .activity
            cell.imageView.kf.setImage(
                with: imageURL,
                placeholder: UIImage(named: "placeholderImage"),
                options: [
                    .processor(processor),
                    .scaleFactor(UIScreen.main.scale),
                    .transition(.flipFromLeft(1)),
                    .cacheOriginalImage
                ])
            {
                result in
                switch result {
                case .success:
//                    print("Task done for: \(value.source.url?.absoluteString ?? "")")
                    print("")
                case .failure(let error):
                    print("Job failed: \(error.localizedDescription)")
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        deleting = true
        selectedAlbums.append(indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        selectedAlbums.removeAll(where: {$0 == indexPath})
        deleting = !selectedAlbums.isEmpty
        
    }

    
    // MARK: - UICollectionViewFlowDelegate

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem + 47)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        sectionInsets.left
    }
}


// MARK: - Alternative Albums Menu

extension SpotifyAlbumResultsCVC: FSPagerViewDelegate, FSPagerViewDataSource {
    
    func numberOfItems(in pagerView: FSPagerView) -> Int {
        return albumGroup.count
    }
    
    
    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index) as! PagerViewCell
        let album = albumGroup[index]
        let albumCoverString = album.images[0].url
        cell.albumTitleLabel?.text = album.name
        
        // Download and cache album cover image
        let imageURL = URL(string: albumCoverString)
        cell.imageView?.kf.setImage(with: imageURL)
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.layer.cornerRadius = 3

        return cell
    }
    
    func pagerView(_ pagerView: FSPagerView, shouldHighlightItemAt index: Int) -> Bool {
        return true
    }
    
    func pagerView(_ pagerView: FSPagerView, shouldSelectItemAt index: Int) -> Bool {
        return true
    }
    
    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        let chosenAlbum = albumGroup[index]
        
        alternativeAlbumsViewHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        })
        
        showBlurredFXView(false)
        
        for (i, album) in albumGroup.enumerated().reversed() {
            if album.id == chosenAlbum.id {
                albumGroup.remove(at: i)
                albumGroup.insert(chosenAlbum, at: 0)
                
                albumResults.remove(at: albumResultsIndex)
                albumResults.insert(albumGroup, at: albumResultsIndex)
                collectionView.reloadItems(at: [IndexPath(item: albumResultsIndex, section: 0)])
                
                
            }
        }
    }
}


// MARK: - ScrollView Delegates

extension SpotifyAlbumResultsCVC: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let newInfoViewHeight = infoViewHeightConstraint.constant - offset
        
//        if newInfoViewHeight < newInfoViewMinHeight {
//            infoViewHeightConstraint.constant = newInfoViewMinHeight
//        } else if newInfoViewHeight > newInfoViewMaxHeight {
//            infoViewHeightConstraint.constant = newInfoViewMaxHeight
//        } else {
//            infoViewHeightConstraint.constant = newInfoViewHeight
//            scrollView.contentOffset.y = 0.0
//        }
    }
    
//     func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
//
//     if(velocity.y>0) {
//        UIView.animate(withDuration: 0.5, delay: 0, options: UIView.AnimationOptions(), animations: {
//             self.navigationController?.setNavigationBarHidden(true, animated: true)
//         }, completion: nil)
//
//     } else {
//        UIView.animate(withDuration: 0.5, delay: 0, options: UIView.AnimationOptions(), animations: {
//            self.navigationController?.setNavigationBarHidden(false, animated: true)
//        }, completion: nil)
//        }
//    }
    
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //        if infoViewHeightConstraint.constant < (newInfoViewMaxHeight / 2) {
        //            self.infoViewHeightConstraint.constant = self.newInfoViewMinHeight
        //        } else {
        //            self.infoViewHeightConstraint.constant = self.newInfoViewMaxHeight
        //        }
        if infoViewHeightConstraint.constant != newInfoViewMinHeight {
            infoViewHeightConstraint.constant = newInfoViewMinHeight
        }
        
        UIView.animate(withDuration: 0.4, animations: {
                 self.logoImageView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                 self.addAlbumsButton.alpha = 0
            self.view.layoutIfNeeded()

             }) { _ in
             }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if infoViewHeightConstraint.constant != newInfoViewMinHeight {
            infoViewHeightConstraint.constant = newInfoViewMinHeight
        }
        
        UIView.animate(withDuration: 0.4, animations: {
                self.logoImageView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                self.addAlbumsButton.alpha = 0
            self.view.layoutIfNeeded()

            }) { _ in
                
            }
    }
    
}
