//
// ContentBlockerManager
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

import Foundation
import SafariServices
import RealmSwift

class ContentBlockerManager {
	
	static let shared = ContentBlockerManager()
	
	private var paused: Bool = false
	
	init() {
		configureRealm()
		reloadContentBlocker()
	}
	
	func subscribeForNotifications() {
		DistributedNotificationCenter.default().addObserver(self,
															selector: #selector(self.pauseNotification),
															name: Constants.PauseNotificationName, object: Constants.SafariPopupExtensionID)
		DistributedNotificationCenter.default().addObserver(self,
															selector: #selector(self.resumeNotification),
															name: Constants.ResumeNotificationName, object: Constants.SafariPopupExtensionID)
		// DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.tabDomainIsChanged), name: Constants.DomainChangedNotificationName, object: Constants.SafariPopupExtensionID)
	}
	
	deinit {
		DistributedNotificationCenter.default().removeObserver(self, name: Constants.PauseNotificationName, object: Constants.SafariPopupExtensionID)
		DistributedNotificationCenter.default().removeObserver(self, name: Constants.ResumeNotificationName, object: Constants.SafariPopupExtensionID)
		//	DistributedNotificationCenter.default().removeObserver(self, name: Constants.SwitchToCustomNotificationName, object: Constants.SafariPopupExtensionID)
		//	DistributedNotificationCenter.default().removeObserver(self, name: Constants.DomainChangedNotificationName, object: Constants.SafariPopupExtensionID)
	}
	
	func configureRealm() {
		let config = Realm.Configuration(
			// Set the new schema version. This must be greater than the previously used
			// version (if you've never set a schema version before, the version is 0).
			schemaVersion: 1,
			
			// Set the block which will be called automatically when opening a Realm with
			// a schema version lower than the one set above
			migrationBlock: { migration, oldSchemaVersion in
				// We haven’t migrated anything yet, so oldSchemaVersion == 0
				if (oldSchemaVersion < 1) {
					// Nothing to do!
					// Realm will automatically detect new properties and removed properties
					// And will update the schema on disk automatically
				}
		})
		
		// Tell Realm to use this new configuration object for the default Realm
		Realm.Configuration.defaultConfiguration = config
		let directory: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppsGroupID)!
		let realmPath = directory.appendingPathComponent("db.realm")
		Realm.Configuration.defaultConfiguration.fileURL = realmPath
		let _ = try! Realm()
		GlobalConfigManager.shared.createConfigIfDoesNotExist()
	}
	
	func updateBlockLists() {
		BlockListFileManager.shared.updateBlockLists()
	}
	
	func isPaused() -> Bool {
		return self.paused
	}
	
	func isDefaultConfigEnabled() -> Bool {
		if let c = GlobalConfigManager.shared.getCurrentConfig() {
			return c.configType.value == ConfigurationType.byDefault.rawValue
		}
		return true
	}
	
	@objc
	func pause() {
		self.paused = true
		reloadContentBlocker()
	}
	
	@objc
	func resume() {
		self.paused = false
		reloadContentBlocker()
	}
	
	@objc
	func pauseNotification() {
		self.paused = true
	}
	
	@objc
	func resumeNotification() {
		self.paused = false
	}
	
	@objc
	func switchToDefault() {
		GlobalConfigManager.shared.switchToConfig(.byDefault)
		self.reloadContentBlocker()
	}
	
	@objc
	func switchToCustom() {
		GlobalConfigManager.shared.switchToConfig(.custom)
		self.reloadContentBlocker()
	}
	
	func reloadContentBlocker() {
		if self.isPaused() {
			loadDummyCB()
		} else {
			if let c = GlobalConfigManager.shared.getCurrentConfig(),
				c.configType.value == ConfigurationType.custom.rawValue {
				self.loadCustomCB()
			} else {
				self.loadDefaultCB()
			}
		}
	}
	
	func trustDomain(domain: String) {
		TrustedSitesDataSource.shared.addDomain(domain)
		WhiteListFileManager.shared.add(domain, completion: {
			self.reloadContentBlocker()
		})
	}
	
	func untrustDomain(domain: String) {
		TrustedSitesDataSource.shared.removeDomain(domain)
		WhiteListFileManager.shared.remove(domain, completion: {
			self.reloadContentBlocker()
		})
	}
	
	func isTrustedDomain(domain: String) -> Bool {
		return TrustedSitesDataSource.shared.isTrusted(domain)
	}
	
	func getCategoryBlockListsFolder() -> String {
		return "BlockListAssets/BlockListByCategory"
	}
	
	func getBlockListsMainFolder() -> String {
		return "BlockListAssets"
	}
	
	@objc
	func trustSiteNotification() {
		let d = UserDefaults(suiteName: Constants.AppsGroupID)
		if let d = d?.value(forKey: "domain") as? String {
			self.trustDomain(domain: d)
			loadDummyCB()
		}
	}
	
	@objc
	func untrustSiteNotification() {
		let d = UserDefaults(suiteName: Constants.AppsGroupID)
		if let d = d?.value(forKey: "domain") as? String {
			self.untrustDomain(domain: d)
			reloadContentBlocker()
		}
	}
	
	@objc
	private func tabDomainIsChanged() {
		let d = UserDefaults(suiteName: Constants.AppsGroupID)
		if let d = d?.value(forKey: "newDomain") as? String {
			if self.isTrustedDomain(domain: d) {
				loadDummyCB()
				return
			}
		}
		self.reloadContentBlocker()
	}
	
	
	/// Load a custom block list file based on user's selected categories
	private func loadCustomCB() {
		if let config = GlobalConfigManager.shared.getCurrentConfig() {
			var fileNames = [String]()
			if config.blockedCategories.count == 0 {
				loadDummyCB()
				return
			}
			if config.blockedCategories.count == CategoryType.allCategoriesCount() {
				loadFullList()
				return
			}
			for i in config.blockedCategories {
				if let c = CategoryType(rawValue: i) {
					fileNames.append(c.fileName())
				}
			}
			// Trigger a Content Blocker reload
			self.updateAndReloadBlockList(fileNames: fileNames, folderName: getCategoryBlockListsFolder())
		}
	}
	
	
	/// Load the default block list file consisting of the default categories only
	private func loadDefaultCB() {
		if let config = GlobalConfigManager.shared.getCurrentConfig() {
			var fileNames = [String]()
			for i in config.defaultBlockedCategories() {
				fileNames.append(i.fileName())
			}
			// Trigger a Content Blocker reload
			self.updateAndReloadBlockList(fileNames: fileNames, folderName: getCategoryBlockListsFolder())
		}
	}
	
	
	/// Load an empty block list file.  Used during  pause and site whitelist scenarios
	private func loadDummyCB() {
		self.updateAndReloadBlockList(fileNames: ["emptyRules"], folderName: getBlockListsMainFolder())
	}
	
	
	/// Load the full block list (all categories)
	private func loadFullList() {
		self.updateAndReloadBlockList(fileNames: ["safariContentBlocker"], folderName: getBlockListsMainFolder())
	}
	
	
	/// Trigger a Content Blocker reload
	/// - Parameter fileNames: The block list json filenames to be loaded
	/// - Parameter folderName: The name of the folder where the json files are located on disk
	private func updateAndReloadBlockList(fileNames: [String], folderName: String) {
		print("ContentBlockerManager.updateAndReloadBlockList: Generating new block list...")
		BlockListFileManager.shared.generateCurrentBlockList(files: fileNames, folderName: folderName) {
			self.reloadCBExtension()
		}
	}
	
	
	/// Reload the Content Blocker extension
	private func reloadCBExtension() {
		print("ContentBlockerManager.reloadCBExtension: Reloading Content Blocker...")
		SFContentBlockerManager.reloadContentBlocker(withIdentifier: Constants.SafariContentBlockerID, completionHandler: { (error) in
			if error != nil {
				print("ContentBlockerManager.reloadCBExtension: Reloading Content Blocker failed with error \(String(describing: error))")
			} else {
				print("ContentBlockerManager.reloadCBExtension: Successfully reloaded Content Blocker!")
			}
		})
	}
}