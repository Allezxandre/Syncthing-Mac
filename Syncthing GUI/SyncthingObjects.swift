//
//  SyncthingObjects.swift
//  Syncthing GUI
//
//  Created by Alexandre Jouandin on 2015/06/01.
//  Copyright (c) 2015 Alexandre Jouandin. All rights reserved.
//

import Foundation
import AppKit
import SwiftyJSON

// MARK: Syncthing subclasses

class Connection : Equatable, CustomStringConvertible {
    var deviceID: String
    var ipAddress: String
    var bytesIn: Int = 0
    var bytesOut: Int = 0
    var description: String { // used by print -> http://vperi.com/2014/06/04/textual-representation-for-classes-in-swift/
        return "[\n Device ID: '\(deviceID)',\n IP Address: '\(ipAddress)',\n Bytes In: \(bytesIn),\n Bytes Out: \(bytesOut)\n]"
    }
    init(thisDeviceID: String, thisIpAddress: String) {
        self.deviceID = thisDeviceID
        self.ipAddress = thisIpAddress
    }
    init(thisDeviceID: String, thisIpAddress: String, bytesIn: Int, bytesOut: Int) {
        self.deviceID = thisDeviceID
        self.ipAddress = thisIpAddress
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

class SyncthingError: Equatable, CustomStringConvertible {
    var time: NSDate
    var errorDescription: String
    var description: String {
        return "\(time) — \(errorDescription)"
    }
    init(error: String, withDate: NSDate) {
        self.errorDescription = error
        self.time = withDate
    }
    init(error: String, withDateString: String) {
        self.errorDescription = error
        let dateFormatter = NSDateFormatter()
        // As from Wikipedia:
        // http://en.wikipedia.org/wiki/ISO_8601
        // http://fr.wikipedia.org/wiki/ISO_8601
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSSzzzzzz"
        if let withDate = dateFormatter.dateFromString(withDateString) {
            self.time = withDate
        } else {
            self.time = NSDate()
            NSLog("Error formatting date string: '\(withDateString)'")
        }
    }
}

struct SyncthingStatus: CustomStringConvertible {
    var alloc: Int
    var cpuPercent: Double
    var extAnnounceOK: Dictionary<String, Bool>
    var goRoutines: Int
    var myID: String
    let pathSeparator = "/"
    var sys: Int
    var tilde: String
    var description: String {
        return "[alloc: \(self.alloc), cpuPercent: \(self.cpuPercent), extAnnounceOK: \(self.extAnnounceOK), goRoutines: \(self.goRoutines), myID: \"\(self.myID)\", pathSeparator: \"\(self.pathSeparator)\", sys: \(self.sys), tilde: \"\(self.tilde)\"]"
    }
}

// MARK: File System

/**
    SyncthingFolders are stored in a dictionnary like `Dictionary<ID,SyncthingFolder>`, so the `id` variable from the `SyncthingFolder` class is a redundant information, but this is intended.
    
    This 
*/
class SyncthingFolder: Equatable, CustomStringConvertible {
    var id: String
    var path: NSURL
    var devices: [String]
    var idle: Bool = false
    var inSyncBytes: Int? = nil
    var outOfSyncBytes: Int? = nil
    var folderSize: Int? {
        if (inSyncBytes == nil)||(outOfSyncBytes == nil) {
            return nil
        } else {
            return inSyncBytes! + outOfSyncBytes!
        }
    }
    var syncRatio: Double? {
        if (inSyncBytes == nil)||(folderSize == nil) {
            return nil
        } else {
            return Double(inSyncBytes!)/Double(folderSize!)
        }
    }
    
    var syncPercentage: Double? {
        if (syncRatio == nil) {
            return nil
        } else {
            return syncRatio! * Double(100)
        }
    }
    
    var description: String {
        return "\(id)  (\(path)) - Devices: \(devices)"
    }
    
    init(id withId: String, forPathString: String, withDevices: [String]) {
        self.id = withId
        self.path = NSURL(fileURLWithPath: forPathString.stringByExpandingTildeInPath, isDirectory: true)
        self.devices = withDevices
    }
}

class File {
    var name: String
    var path: NSURL
    var synced: Bool? = nil
    
    init(withName: String, atPath: NSURL) {
        self.name = withName
        self.path = atPath
    }
}

class FileSystemItem: NSObject {
    var relativePath: String
    var parent: FileSystemItem?
    var children: [FileSystemItem]?
    
    static var initialized: Bool = false
    static var files_json: JSON!
    static var rootItem: FileSystemItem!
    
    init(path: String, parent: FileSystemItem?, isAFolder: Bool) {
        self.relativePath = path.lastPathComponent
        self.parent = parent
        if isAFolder {
            self.children = [FileSystemItem]()
        } else {
            self.children = nil
        }
    }
    
    /** Reads the JSON file tree using `files_json` and `rootItem` */
    class func readFileTree() -> () {
        print("File list has been pulled")
        print(files_json)
        // We suppose that `files_json` has been loaded and `rootItem` has been initialized
        for (key, subjson): (String, JSON) in files_json {
            rootItem.interpretTypeOfChild(name: key, json: subjson)
        }
        initialized = true
    }
    
    /** Interprets a JSON to build the FileSystemTree */
    private func interpretTypeOfChild(name name: String, json: JSON) {
        if let _ = json[1].int {
            // We have a size, so this is a file
            // Create item
            let file = FileSystemItem(path: name, parent: parent, isAFolder: false)
            // Add it to list of childrens of the parent folder
            self.children! += [file]
        } else {
            // We don't have a size, so this is a folder
            // Create item
            let file = FileSystemItem(path: name, parent: parent, isAFolder: true)
            // Add it to list of childrens of the parent folder
            self.children! += [file]
            // loop through childrens
            for (key, subjson): (String, JSON) in json {
                file.interpretTypeOfChild(name: key, json: subjson)
            }
        }
    }
    
    /** Returns the full path of an item by recursively appending its parents `relativePath`s */
    var fullPath: String {
        if parent == nil {
            return relativePath
        } else {
            return parent!.fullPath.stringByAppendingPathComponent(relativePath)
        }
    }
    
    func childAtIndex(n: Int) -> FileSystemItem {
        if !FileSystemItem.initialized {
            return FileSystemItem.rootItem
        }
        assert(self.children != nil, "`self.children` is nil. Looks like you're trying to access the childrens of a file")
        return self.children![n]
    }
    
    var numberOfChildren: Int? {
        if !FileSystemItem.initialized {
            print("File system not ready yet...")
            return nil
        }
        return (self.children == nil) ? nil : (self.children!.count)
    }
}

// MARK: Events

/** An enumeration of [Syncthing events](http://docs.syncthing.net/dev/events.html#events) types */
enum EventType {
    case ConfigSaved, DeviceConnected, DeviceDisconnected, DeviceDiscovered, DeviceRejected, DownloadProgress, FolderCompletion, FolderErrors, FolderRejected, FolderSummary, ItemFinished, ItemStarted, LocalIndexUpdated, Ping, RemoteIndexUpdated, Starting, StartupCompleted, StateChanged, Dummy
    static func getTypeFromString(string: String) -> EventType {
        switch string {
        case "ConfigSaved":
            return .ConfigSaved
        case "DeviceConnected":
            return .DeviceConnected
        case "DeviceDisconnected":
            return .DeviceDisconnected
        case "DeviceDiscovered":
            return .DeviceDiscovered
        case "DeviceRejected":
            return .DeviceRejected
        case "DownloadProgress":
            return .DownloadProgress
        case "FolderCompletion":
            return .FolderCompletion
        case "FolderErrors":
            return .FolderErrors
        case "FolderRejected":
            return .FolderRejected
        case "FolderSummary":
            return .FolderSummary
        case "ItemFinished":
            return .ItemFinished
        case "ItemStarted":
            return .ItemStarted
        case "LocalIndexUpdated":
            return .LocalIndexUpdated
        case "Ping":
            return .Ping
        case "RemoteIndexUpdated":
            return .RemoteIndexUpdated
        case "Starting":
            return .Starting
        case "StartupCompleted":
            return .StartupCompleted
        case "StateChanged":
            return .StateChanged
        default:
            return .Dummy
        }
    }
}

class SyncthingEvent: CustomStringConvertible {
    var id: Int
    var time: NSDate
    let type: EventType
    var data: [String: String]?
    var description: String {
        return "Event #\(id) - \(data)"
    }
    
    init(id: Int, time: NSDate, type: EventType, data: [String: String]?) {
        self.id = id
        self.time = time
        self.type = type
        self.data = data
    }
}

// MARK: Equatable global functions


func ==(lhs: Connection, rhs: Connection) -> Bool {
    return (lhs.deviceID == rhs.deviceID)
}
func ==(lhs: SyncthingError, rhs: SyncthingError) -> Bool {
    return (lhs.time == rhs.time) && (lhs.errorDescription == rhs.errorDescription)
}
func ==(lhs: SyncthingFolder, rhs: SyncthingFolder) -> Bool {
    return (lhs.id == rhs.id) && (lhs.path == rhs.path)
}

// MARK: Syncthing Object

class Syncthing: CustomStringConvertible {
    // Variables
    var system: SyncthingStatus?
    var foldersInSync = Dictionary<String,SyncthingFolder>()
    /** This variable stores all available folders */
    var foldersList: [String] { // If you have duplicate folders, here's the culprit
        var list = [String]()
        for (id, _): (String, SyncthingFolder) in self.foldersInSync {
            list += [id]
        }
        return list
    }
    var connections = [Connection]()
    var errors = [SyncthingError]()
    /** A `String` describing the newest version. If the system is up-to-date, this is a `nil` */
    var possibleUpgrade: String?
    var configInSync: Bool = false
    // For Printable:
    var description: String {
        let inSync: String = (configInSync) ? "In Sync":"Not In Sync"
        let updatable: String = (possibleUpgrade != nil) ? "An upgrade to \(possibleUpgrade) is available":"Syncthing is up-to-date"
        // connections
        var connectionsString = "{\n "
        for connection in connections {
            connectionsString += " \(connection)\n"
        }
        connectionsString += "}"
        // errors
        var errorsString = "{\n"
        for error in errors {
            errorsString += " [\(error)]\n"
        }
        errorsString += "}"
        // folders
        var foldersString = "{\n"
        for folder in foldersInSync {
            foldersString += " [\(folder)]\n"
        }
        foldersString += "}"
        return "System status: \(system)\n\(updatable)\n\(inSync)\nConnections :\(connectionsString)\nFolders: \(foldersString)\nErrors :\(errorsString)"
    }
    
    // Functions
    func revealFolder(id id: String) {
        if let fileToReveal: NSURL = self.foldersInSync[id]?.path {
            // http://stackoverflow.com/a/7658305/3997690
            print("Revealing file: \(fileToReveal)")
            NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs([fileToReveal] as [NSURL])
        } else {
            NSLog("Error revealing folder with ID '\(id)'")
        }
    }
}