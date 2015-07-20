//
//  ViewController.swift
//  Syncthing GUI
//
//  Created by Alexandre Jouandin on 2015/05/14.
//  Copyright (c) 2015 Alexandre Jouandin. All rights reserved.
//

import Cocoa
import AppKit

protocol SyncthingDisplayDelegate {
    func reloadData() -> ()
}

/** 
The Main View controller from the main Window
*/
class ViewController: NSViewController, SyncthingDisplayDelegate {
    
    var syncthingSystem = SyncthingCommunication()
    
    var delegateInteraction: SyncthingInteractionDelegate!
    
    // MARK: IBOutlets
    @IBOutlet weak var folderTableView: NSTableView!
    @IBOutlet weak var spinningWheel: NSProgressIndicator!
    
    // MARK: IBActions
    @IBAction func refreshButtonPressed(sender: AnyObject) {
        print("button Pressed by \(sender)")
        syncthingSystem.fetchEverything()
    }
    
    // MARK: Overrides
    override func viewDidLoad() {
        super.viewDidLoad()
            // Load settings
        
        /* // To reset settings on your machine, use this:
        let appDomain = NSBundle.mainBundle().bundleIdentifier!
        NSUserDefaults.standardUserDefaults().removePersistentDomainForName(appDomain)
        */
        /** Available settings:
- `Clients`: an Array of clients with 4 parameters: Name, IPaddress, Port and APIkey
- `RefreshRate`: Refresh rate, in seconds
- `ResfreshRateBackground`: Refresh rate when the app is in background, in seconds
        */
        let userPreferences = NSUserDefaults.standardUserDefaults()
        userPreferences.registerDefaults(
            ["Clients": [["Name": "Local Syncthing",
                         "BaseURL": "http://localhost",
                         "Port": 8080,
                         "APIkey": ""]],
            "RefreshRate": 1,
            "RefreshRateBackground": 20])
            // Set up the table appearance
        folderTableView.hidden = true
        spinningWheel.hidden = false
        spinningWheel.startAnimation(nil)
            // Warm up the Syncthing Backend
        syncthingSystem.delegateForDisplay = self
            // Set things up
        let firstClient = (userPreferences.objectForKey("Clients"))![0]
        print(firstClient)
        // syncthingSystem.baseUrlString = firstClient["IPaddress"]
        //syncthingSystem.port =
        // syncthingSystem.apiKey =
            // Ready
        syncthingSystem.fetchEverything()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // MARK: Delegate
    
    func reloadData() -> () {
        spinningWheel.stopAnimation(nil)
        spinningWheel.hidden = true
        folderTableView.hidden = false
        folderTableView.reloadData()
    }
}

// http://nscurious.com/2015/04/08/using-view-based-nstableview-with-swift/

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return syncthingSystem.syncthing.foldersInSync.count
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let cell = tableView.makeViewWithIdentifier("syncthingFolderView", owner: nil) as! FolderView
        return cell.frame.height
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeViewWithIdentifier("syncthingFolderView", owner: nil) as! FolderView
        let folderId = syncthingSystem.syncthing.foldersList[row]
        let folder = syncthingSystem.syncthing.foldersInSync[folderId]
        // set folder display
            cell.folderName.stringValue = folder!.id
            cell.folderPath.URL = folder!.path
            cell.syncIdle = folder!.idle
        if !folder!.idle {
            // folder is not idle
            if folder?.syncPercentage == nil {
                cell.folderProgressIndicator.indeterminate = true
                cell.folderProgressIndicator.startAnimation(nil)
            } else {
                cell.folderProgressIndicator.stopAnimation(nil)
                cell.folderProgressIndicator.indeterminate = false
                cell.folderProgressIndicator.doubleValue = folder!.syncPercentage!
            }
        }
            cell.delegateInteraction = self.syncthingSystem
        
        return cell
    }
}
