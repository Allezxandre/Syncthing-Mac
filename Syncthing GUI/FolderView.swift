//
//  FolderView.swift
//  Syncthing GUI
//
//  Created by Alexandre Jouandin on 2015/06/03.
//  Copyright (c) 2015 Alexandre Jouandin. All rights reserved.
//

import Cocoa

class FolderView: NSTableCellView {
    
    var delegateInteraction: SyncthingInteractionDelegate!
    
    var folder: SyncthingFolder!
    
    // MARK: IBOutlets
    @IBOutlet weak var folderName: NSTextField!
    @IBOutlet weak var folderPath: NSPathControl!
    @IBOutlet weak var folderProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressPercentageTextField: NSTextField!
    @IBOutlet weak var folderIdleImage: NSImageView!
    @IBOutlet weak var inSyncLabel: NSTextField!
    
    // MARK: IBActions
    @IBAction func revealFolder(sender: NSButton) {
        self.delegateInteraction.openFolder(folderName.stringValue)
    }
    @IBAction func rescanFolder(sender: AnyObject) {
        self.delegateInteraction.rescanFolder(folderName.stringValue)
    }
    
    // MARK: Variables
    
    var syncIdle: Bool = false {
        didSet{
            folderIdleImage.hidden = !self.syncIdle
            inSyncLabel.hidden = !self.syncIdle
            progressPercentageTextField.hidden = self.syncIdle
            folderProgressIndicator.hidden = self.syncIdle
            if self.syncIdle {
                folderProgressIndicator.stopAnimation(nil)
            } else {
                folderProgressIndicator.startAnimation(nil)
            }
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
}
