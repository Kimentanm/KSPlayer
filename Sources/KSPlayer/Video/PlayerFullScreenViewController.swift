//
//  PlayerFullScreenViewController.swift
//  KSPlayer
//
//  Created by kintan on 2021/8/20.
//
#if canImport(UIKit) && os(iOS)

import UIKit
protocol PlayerViewFullScreenDelegate: AnyObject {
    func player(isMaskShow: Bool, isFullScreen: Bool)
}

class PlayerFullScreenViewController: UIViewController {
    private let isHorizonal: Bool
    private var statusHiden = false
    init(isHorizonal: Bool) {
        self.isHorizonal = isHorizonal
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        KSOptions.supportedInterfaceOrientations = isHorizonal ? .landscape : .portrait
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override var shouldAutorotate: Bool {
        KSOptions.supportedInterfaceOrientations == .all
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : (isHorizonal ? .landscape : .portrait)
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}

extension PlayerFullScreenViewController: PlayerViewFullScreenDelegate {
    func player(isMaskShow: Bool, isFullScreen: Bool) {
        if isFullScreen {
            statusHiden = !isMaskShow
            setNeedsFocusUpdate()
        }
    }
}

#endif
