//
// HomeViewController
// GhosteryLite
//
// Ghostery Lite for Safari
// https://www.ghostery.com/
//
// Copyright 2019 Ghostery, Inc. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0
//

import Cocoa
import SafariServices

class HomeViewController: NSViewController {
	
	/// Set delegate to DetailViewControllerDelegate
	var delegate: DetailViewControllerDelegate?
	
	@IBOutlet weak var titleText: NSTextField!
	@IBOutlet weak var subtitleText: NSTextField!
	@IBOutlet weak var editSettingsText: NSTextField!
	@IBOutlet weak var editSettingsBtn: NSButton!
	@IBOutlet weak var trustedSitesText: NSTextField!
	@IBOutlet weak var trustedSitesBtn: NSButton!
	@IBOutlet weak var EnableExtensionsPromptView: NSBox!
	@IBOutlet weak var enableGhosteryLitePromptText: NSTextField!
	@IBOutlet weak var enableGhosteryLiteBtn: NSButton!
	
	/// Action taken when Enable button is clicked
	/// - Parameter sender: The enable button
	@IBAction func enableGhosteryLite(_ sender: NSButton) {
		self.EnableExtensionsPromptView.isHidden = true
		HomeViewController.showSafariPreferencesForExtension()
	}
	
	/// Action taken when the Settings button  is clicked
	/// - Parameter sender: The settings button
	@IBAction func editSettingsClicked(_ sender: Any) {
		self.delegate?.showSettingsPanel()
	}
	
	/// Action taken when the trusted sites button is clicked
	/// - Parameter sender: The trusted sites button
	@IBAction func trustedSitesClicked(_ sender: Any) {
		self.delegate?.showTrustedSitesPanel()
	}
	
	/// Called after the view controller’s view has been loaded into memory.
	override func viewDidLoad() {
		super.viewDidLoad()
		initComponents()
		// Check for application first launch
		if !Preferences.isFirstLaunch() {
			// Check that all safari extensions are currently enabled
			Utils.areExtensionsEnabled { (extensionsEnabled, error) in
				if let error = error as NSError? {
					Utils.logger("Error \(error), \(error.userInfo)")
				}
				// Show / hide the enable extensions prompt
				self.EnableExtensionsPromptView.isHidden = extensionsEnabled
			}
		}
		DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.editSettingsClicked(_:)), name: Constants.NavigateToSettingsNotificationName, object: Constants.SafariExtensionID)
	}
	
	/// Called when the view controller’s view is fully transitioned onto the screen.
	override func viewDidAppear() {
		super.viewDidAppear()
		Telemetry.shared.sendSignal(.engaged, source: TelemetryService.PingSource.ghosteryLiteApplication)
	}
	
	/// Launches Safari and opens the preferences panel for a Safari app extension.
	class func showSafariPreferencesForExtension() {
		SFSafariApplication.showPreferencesForExtension(withIdentifier: Constants.SafariExtensionID, completionHandler: { (error) in
			if let error = error as NSError? {
				Utils.logger("Error \(error), \(error.userInfo)")
			}
		})
	}
	
	/// Set formatting for view text and buttons
	private func initComponents() {
		titleText.font = NSFont(name: "Roboto-Regular", size: 24)
		subtitleText.attributedStringValue = subtitleText.stringValue.attributedString(withTextAlignment: .left, fontName: "Roboto-Regular", fontSize: 16, fontColor: NSColor.panelTextColor(), isUnderline: false, lineSpacing: 6)
		editSettingsText.attributedStringValue = editSettingsText.stringValue.attributedString(withTextAlignment: .left, fontName: "Roboto-Medium", fontSize: 16.0, fontColor: NSColor.panelTextColor(), lineSpacing: 12.0)
		trustedSitesText.attributedStringValue = trustedSitesText.stringValue.attributedString(withTextAlignment: .left, fontName: "Roboto-Medium", fontSize: 16.0, fontColor: NSColor.panelTextColor(), lineSpacing: 12.0)
			
		let textColor = NSColor(named: "homeBtnTextColor") ?? NSColor.black
		editSettingsBtn.attributedTitle = editSettingsBtn.title.attributedString(withTextAlignment: .center, fontName: "RobotoCondensed-Bold", fontSize: 14.0, fontColor: textColor)
		trustedSitesBtn.attributedTitle = trustedSitesBtn.title.attributedString(withTextAlignment: .center, fontName: "RobotoCondensed-Bold", fontSize: 14.0, fontColor: textColor)
		enableGhosteryLiteBtn.attributedTitle = enableGhosteryLiteBtn.title.attributedString(withTextAlignment: .center, fontName: "Roboto-Regular", fontSize: 14.0, fontColor: NSColor(rgb: 0x4a4a4a))
	}
}
