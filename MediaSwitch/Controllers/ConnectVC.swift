//
//  SpotifyVC.swift
//  MediaSwitch
//
//  Created by Sean Williams on 06/04/2020.
//  Copyright © 2020 Sean Williams. All rights reserved.
//

import Alamofire
import Firebase
import NVActivityIndicatorView
import Network
import StoreKit
import UIKit

class ConnectVC: UIViewController, CAAnimationDelegate, SKCloudServiceSetupViewControllerDelegate {
    
    
    // MARK: - Outlets
    
    @IBOutlet weak var spotifyButtonImageView: UIImageView!
    @IBOutlet weak var appleMusicButton: RoundButton!
    @IBOutlet weak var downArrow: UIImageView!
    @IBOutlet weak var upArrow: UIImageView!
    @IBOutlet weak var connectLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    
    // MARK: - Properties
    
    let redirectUri = URL(string:"media-switch://spotify-login-callback")!
    
    lazy var configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: Auth.spotifyClientID, redirectURL: redirectUri)
        configuration.playURI = nil
        return configuration
    }()
    
    lazy var sessionManager: SPTSessionManager = {
        if let tokenSwapURL = URL(string: "https://mediaswitch.herokuapp.com/api/token"),
            let tokenRefreshURL = URL(string: "https://mediaswitch.herokuapp.com/api/refresh_token") {
            self.configuration.tokenSwapURL = tokenSwapURL
            self.configuration.tokenRefreshURL = tokenRefreshURL
        }
        let manager = SPTSessionManager(configuration: configuration, delegate: self)
        return manager
    }()
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.delegate = self
        return appRemote
    }()
    
    var colourSets = [[CGColor]]()
    var currentColourSet = 0
    var gradientLayer = CAGradientLayer()
    var colourTimer = Timer()
    var viewingAppleMusic = false
    var ref: DatabaseReference!
    var connectedToNetwork = false
    var blurredEffect = UIVisualEffectView()
    var activityView = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
    
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        
        // Monitor network connection
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                self.connectedToNetwork = true
            } else {
                self.connectedToNetwork = false
                self.showAlert(title: "Connection Failed", message: "Your Internet connnection appears to be offline. Please connect and try again.")
                return
            }
        }
        
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
        
        // Setup UI elements
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(connectToSpotifyTapped))
        spotifyButtonImageView.isUserInteractionEnabled = true
        spotifyButtonImageView.addGestureRecognizer(tapGesture)
        
        colourSets = createColorSets()
        
        connectLabel.layer.borderColor = UIColor.label.cgColor
        connectLabel.layer.borderWidth = 1
        connectLabel.layer.cornerRadius = 25
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(showBlurredFXView))
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
        
        activityView.type = .ballPulse
        activityView.tintColor = .white
        activityView.startAnimating()
        blurredEffect.contentView.addSubview(activityView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        
        let i = Int.random(in: 1...2)
        backgroundImageView.image = UIImage(named: "CDBG\(i)")
        
        downArrow.alpha = 0.2
        upArrow.alpha = 0.2
        downArrow.blink(duration: 1, delay: 3, alpha: 0.1)
        upArrow.blink(duration: 1, delay: 3, alpha: 0.1)
        animateColours()
        colourTimer = Timer.scheduledTimer(timeInterval: 4.5, target: self, selector: #selector(animateColours), userInfo: nil, repeats: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var spotifyImageWidth = spotifyButtonImageView.image?.size.width ?? view.frame.size.width - 40
        if spotifyImageWidth > view.frame.width {
            spotifyImageWidth = spotifyButtonImageView.frame.width
        }
        
        appleMusicButton.widthAnchor.constraint(equalToConstant: spotifyImageWidth).isActive = true
        
        gradientLayer.frame = CGRect(x: 0, y: 0, width: spotifyImageWidth, height: appleMusicButton.frame.height)
        gradientLayer.cornerRadius = 25
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.colors = colourSets[currentColourSet]
        appleMusicButton.layer.addSublayer(gradientLayer)
        appleMusicButton.bringSubviewToFront(appleMusicButton.titleLabel!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        colourTimer.invalidate()
        showBlurredFXView(false)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        connectLabel.layer.borderColor = UIColor.label.cgColor
    }
    
    
    // MARK: - Private Methods
    
    @objc func animateColours() {
        if currentColourSet < colourSets.count - 1 {
            currentColourSet += 1
        } else {
            currentColourSet = 0
        }
        
        let colourChangeAnimation = CABasicAnimation(keyPath: "colors")
        colourChangeAnimation.duration = 1.5
        colourChangeAnimation.toValue = colourSets[currentColourSet]
        colourChangeAnimation.fillMode = .forwards
        colourChangeAnimation.isRemovedOnCompletion = false
        colourChangeAnimation.delegate = self
        gradientLayer.add(colourChangeAnimation, forKey: "colorChange")
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            gradientLayer.colors = colourSets[currentColourSet]
        }
    }
    
    @objc func showBlurredFXView(_ showBlur: Bool) {
        activityView.center = connectLabel.center
        
        if showBlur {
            blurredEffect.isHidden = false
            self.activityView.startAnimating()
            
            UIView.animate(withDuration: 0.4) {
                self.connectLabel.alpha = 0
                let blurFX = UIBlurEffect(style: .systemThickMaterialDark)
                self.blurredEffect.effect = blurFX
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.blurredEffect.effect = nil
                self.connectLabel.alpha = 1
                
            }) { _ in
                self.blurredEffect.isHidden = true
            }
        }
    }
    
    func connectionEstablished() {
        viewingAppleMusic = false
        performSegue(withIdentifier: "showImageReader", sender: self)
    }
    
    
    // Apple Music
    
    func showAppleMusicSubscriptionController() {
        let controller = SKCloudServiceController()
        controller.requestCapabilities { (capabilities: SKCloudServiceCapability, error: Error?) in
            guard error == nil else { return }
            
            if capabilities.contains(.musicCatalogSubscriptionEligible) && !capabilities.contains(.musicCatalogPlayback) {
                // Allows subscription to the Apple Music catalog.
                
                let options: [SKCloudServiceSetupOptionsKey: Any] = [.action: SKCloudServiceSetupAction.subscribe]
                
                DispatchQueue.main.async {
                    
                    let setupController = SKCloudServiceSetupViewController()
                    setupController.delegate = self
                    
                    setupController.load(options: options) { [weak self] (result: Bool, error: Error?) in
                        guard error == nil else {
                            self?.showAlert(title: "Music App Not Found", message: "It appears the Apple Music app was deleted from your device. It can be reinstalled from the App Store.", completion: {
                                self?.showBlurredFXView(false)
                            })
                            return
                        }
                        
                        if result {
                            self?.showBlurredFXView(false)
                            self?.present(setupController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    func requestAppleUserToken() {
        let controller = SKCloudServiceController()
        controller.requestUserToken(forDeveloperToken: Auth.Apple.developerToken) { [weak self] (userToken, error) in
            guard error == nil else {
                print(error?.localizedDescription as Any)
                
                // No user token found - offer Apple Music subscription
                DispatchQueue.main.async {
                    let ac = UIAlertController(title: "Apple Music Subscription Required", message: "Please subscribe to Apple Music if you wish to use MediaSwitch to add albums to your library.", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "No Thanks", style: .default, handler: { _ in
                        self?.showBlurredFXView(false)
                    }))
                    ac.addAction(UIAlertAction(title: "Subscribe", style: .default, handler: { _ in
                        self?.showAppleMusicSubscriptionController()
                    }))
                    self?.present(ac, animated: true)
                }
                return
            }
            
            if let userToken = userToken {
                Auth.Apple.userToken = userToken
                DispatchQueue.main.async {
                    self?.performSegue(withIdentifier: "showImageReader", sender: self)
                }
            }
        }
    }
    
    func requestAppleStorefront() {
        let controller = SKCloudServiceController()
        controller.requestStorefrontCountryCode { (code, error) in
            if error != nil {
                print(error?.localizedDescription as Any)
            } else {
                if let code = code {
                    Auth.Apple.storefront = code
                }
            }
        }
    }
    
    func getDeveloperToken() {
        ref.child("tokens").observeSingleEvent(of: .value) { (snapshot) in
            let dict = snapshot.value as? NSDictionary
            Auth.Apple.developerToken = dict?["developerToken"] as? String ?? ""
            self.requestAppleUserToken()
        }
    }
    
    
    // Spotify
    
    @objc func connectToSpotifyTapped() {
        
        UIView.animate(withDuration: 0.1, animations: {
            self.spotifyButtonImageView.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.spotifyButtonImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
            }
        }
        
        let accessToken = UserDefaults.standard.string(forKey: "access-token-key") ?? "NO_ACCESS_TOKEN"
        let userURL = "https://api.spotify.com/v1/me"
        
        AF.request(userURL, method: .get, parameters: [:], encoding: URLEncoding.default, headers: ["Authorization": "Bearer "  + accessToken]).responseJSON { (response) in
            switch response.result {
            case .success:
                
                if response.response?.statusCode == 200 {
                    self.viewingAppleMusic = false
                    self.performSegue(withIdentifier: "showImageReader", sender: self)
                    
                } else {
                    print("Token Has Expired or invalid")
                    // Connect to Spotify to authorise
                    self.initiateSpotifyConnectionSession()
                }
                
            case .failure:
                self.showAlert(title: "Connection Failed", message: "Your Internet connnection appears to be offline. Please connect and try again.")
            }
        }
    }
    
    fileprivate func initiateSpotifyConnectionSession() {
        let scope: SPTScope = [.appRemoteControl, .playlistReadPrivate, .userLibraryModify, .userReadEmail]
        
        ref.child("tokens").observeSingleEvent(of: .value) { snapshot in
            let tokens = snapshot.value as? NSDictionary
            Auth.spotifyClientID = tokens?["spotifyClientID"] as? String ?? ""
            
            if #available(iOS 11, *) {
                // Use to take advantage of SFAuthenticationSession
                self.sessionManager.initiateSession(with: scope, options: .default)
            } else {
                // Use on iOS versions < 11 to use SFSafariViewController
                self.sessionManager.initiateSession(with: scope, options: .default, presenting: self)
            }
        }
        
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showImageReader" {
            let vc = segue.destination as! ImageReaderVC
            vc.viewingAppleMusic = viewingAppleMusic
        }
    }
    
    // MARK: - Action Methods
    
    @IBAction func appleMusicButtonTapped(_ sender: Any) {
        showBlurredFXView(true)
        
        SKCloudServiceController.requestAuthorization { (status) in
            switch status {
            case .denied, .restricted:
                print("Apple Music Denied")
                
                self.showAlert(title: "Apple Music Access Denied", message: "MediaSwitch needs permission to access your Apple Music library to add albums. \n\nPlease go to your device's settings, scroll down to MediaSwitch then allow access to Media & Apple Music.") {
                    self.showBlurredFXView(false)
                    return
                }
                
            case .authorized:
                print("Apple Music Authorized")
                
                if self.connectedToNetwork {
                    self.viewingAppleMusic = true
                    self.getDeveloperToken()
                    self.requestAppleStorefront()
                } else {
                    print("No Connectionn")
                    self.showAlert(title: "Connection Failed", message: "Your Internet connnection appears to be offline. Please connect and try again.")
                    return
                }
                
            default:
                break
            }
        }
    }
}


// MARK: - Session Manager Delegates

extension ConnectVC: SPTSessionManagerDelegate {
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("session failed \(error.localizedDescription)")
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("session renewed \(session.description)")
    }
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        print("sessionManager did initiate")
        appRemote.connectionParameters.accessToken = session.accessToken
        appRemote.connect()
    }
}


// MARK: - AppRemoteDelegate

extension ConnectVC: SPTAppRemoteDelegate {
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        self.appRemote = appRemote
        print("appremoteDidEstablishConnection")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("didFailConnectionAttemptWithError")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("didDisconnectWithError")
    }
}


extension UIView {
    func blink(duration: TimeInterval = 0.5, delay: TimeInterval = 0.0, alpha: CGFloat = 0.0) {
        UIView.animate(withDuration: duration, delay: delay, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
            self.alpha = alpha
        })
    }
}
