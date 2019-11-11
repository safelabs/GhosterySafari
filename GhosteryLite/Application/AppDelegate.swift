//
// AppDelegate
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	var mainWindow: NSWindow?
	
	@IBOutlet weak var protectionConfigMenu: NSMenuItem!
	
	/// Sent by the default notification center immediately before the application object is initialized.
	func applicationWillFinishLaunching(_ notification: Notification) {
		self.updateConfigState()
		TelemetryManager.shared.sendSignal(.install)
		TelemetryManager.shared.sendSignal(.upgrade)
	}
	
	/// Sent by the default notification center after the application has been launched and initialized but before it has received its first event.
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		print("AppDelegate.applicationDidFinishLaunching: Ghostery Lite launched successfully")
		// Set prefs
		Preferences.setAppPreference(key: "NSInitialToolTipDelay", value: 50)
		// Create notification listeners
		DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.updateConfigState), name: Constants.SwitchToDefaultNotificationName, object: Constants.SafariPopupExtensionID)
		DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.updateConfigState), name: Constants.SwitchToCustomNotificationName, object: Constants.SafariPopupExtensionID)
		// Handle first launch bootstrapping
		if Preferences.isAppFirstLaunch() {
			self.handleInitialLaunch()
		}
		// Check for new Block Lists on CDN
		ContentBlockerManager.shared.checkForUpdatedBlockLists()
	}
	
	/// Sent by the default notification center immediately after the application becomes active.
	func applicationDidBecomeActive(_ notification: Notification) {
		self.updateConfigState()
		TelemetryManager.shared.sendSignal(.active, ghostrank: 3)
	}
	
	/// Sent by the default notification center immediately before the application terminates.
	func applicationWillTerminate(_ aNotification: Notification) {
		DistributedNotificationCenter.default().removeObserver(self, name: Constants.SwitchToDefaultNotificationName, object: Constants.SafariPopupExtensionID)
		DistributedNotificationCenter.default().removeObserver(self, name: Constants.SwitchToCustomNotificationName, object: Constants.SafariPopupExtensionID)
	}
	
	/// Invoked when the user closes the last window the application has open.
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	/// Sent by the application to the delegate prior to default behavior to reopen (rapp) AppleEvents.
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		if !flag {
			mainWindow?.makeKeyAndOrderFront(self)
		}
		return true
	}
	
	@objc
	func updateConfigState() {
		if let m = self.protectionConfigMenu?.submenu {
			if ContentBlockerManager.shared.isDefaultConfigEnabled() {
				m.items[0].state = NSControl.StateValue(rawValue: 1)
				m.items[1].state = NSControl.StateValue(rawValue: 0)
			} else {
				m.items[0].state = NSControl.StateValue(rawValue: 0)
				m.items[1].state = NSControl.StateValue(rawValue: 1)
			}
		}
	}
	
	/// Provision the application preferences and resources on a fresh installation
	private func handleInitialLaunch(){
		print("AppDelegate.handleInitialLaunch: Initial launch detected")
		// Copy block list assets to Group Containers
		guard let resources = Bundle.main.resourceURL?.appendingPathComponent("BlockListAssets", isDirectory: true).path,
			let groupStorageFolder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppsGroupID)?.appendingPathComponent("BlockListAssets", isDirectory: true).path else {
				print("AppDelegate.applicationDidFinishLaunching: Error copying block list assets to Group Containers")
				return
		}
		FileManager.default.copyFiles(resources, groupStorageFolder)
		
		// Save Ghostery block list version to Preferences to prevent unnecessary update check
	}
}
