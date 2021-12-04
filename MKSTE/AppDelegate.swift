//
//  AppDelegate.swift
//  MechKey
//
//  Created by Bogdan Ryabyshchuk on 9/5/18.
//  Copyright © 2021 Kai Azim. All rights reserved.
//

import Cocoa
import AVFoundation
import Darwin
import AppKit
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: App Wide Variables and Settings
    
    // Player Arrays and Sound Profiles    
    var profile: Int = 0
    
    let soundFiles: [[Int: (String, String)]] = [[0: ("cream-large-down", "cream-large-up"),   // normal
                                                  1: ("cream-large-down", "cream-large-up"),
                                                  2: ("cream-large-down", "cream-large-up")]]
    
    var players: [Int: ([AVAudioPlayer?], [AVAudioPlayer?])] = [:]
    var playersCurrentPlayer: [Int: (Int, Int)] = [:]
    var playersMax: Int = 15
    
    // App Settings
    var volumeLevel:Float = 1.0
    var volumeMuted:Bool = false
    
    var modKeysMuted:Bool = false
    
    var keyUpSound = true
   
    // Other Variables
    var menuItem:NSStatusItem? = nil
    
    
    var keyRandomize = true
    
    // Debugging Messages
    var debugging = false
    
    // MARK: Start and Exit Functions
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load Settings
        volumeLoad()
        profileLoad()
        volumeUpdate()
        keyRandomizeLoad()
        // Create the Menu
        menuCreate()
        
        // Check for Permissions
        checkPrivecyAccess()
        
        // Add Key Listeners
        loadKeyListeners()
    }
    
    // MARK: Event Listeners
    
    func loadKeyListeners() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: { (event) -> Void in
            self.keyPressDown(event: event)
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.keyUp, handler: { (event) -> Void in
            self.keyPressUp(event: event)
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: { (event) -> Void in
            self.keyPressMod(event: event)
        })
    }
    
    // MARK: Mouse Functions
    var mousePrevDown: NSDate = NSDate()
    var mousePrevUp: NSDate = NSDate()
    
    // MARK: Key Functions
    // Key Press Function for Normal Keys
    func keyPressDown(event:NSEvent){
        if !volumeMuted {
            if !event.isARepeat {
                playSoundForKey(key: Int(event.keyCode), keyIsDown: true)
                systemMenuMessage(message: "\(event.keyCode)")
            }
        }
        
        // Some Hot Key Processing Code
        if modKeysPrevMask == modKeyMask["keyFunction"]! {
            if !event.isARepeat {
                // Fn+Esc Mute Keys
                if event.keyCode == 53 {
                    if volumeMuted {
                        volumeSet(vol: self.volumeLevel, muted: false)
                    } else {
                        volumeSet(vol: self.volumeLevel, muted: true)
                    }
                }
            }
        }
    }
    
    func keyPressUp(event:NSEvent){
        if !volumeMuted {
            if !event.isARepeat {
                playSoundForKey(key: Int(event.keyCode), keyIsDown: false)
            }
        }
    }
    
    
    // Key Press Functions for Mod Keys
    var modKeysPrev: [String: Bool] = ["keyShiftRight":  false,
                                       "keyShiftLeft":   false,
                                       "keyAltLeft":     false,
                                       "keyAltRight":    false,
                                       "keyCMDLeft":     false,
                                       "keyCMDRight":    false,
                                       "keyControl":     false,
                                       "keyFunction":    false]
    var modKeysPrevMask: UInt = 0
    
    let modKeyMask: [String: UInt] = ["keyShiftRight":  0b000000100000000100000100,
                                      "keyShiftLeft":   0b000000100000000100000010,
                                      "keyAltLeft":     0b000010000000000100100000,
                                      "keyAltRight":    0b000010000000000101000000,
                                      "keyCMDLeft":     0b000100000000000100001000,
                                      "keyCMDRight":    0b000100000000000100010000,
                                      "keyControl":     0b000001000000000100000001,
                                      "keyFunction":    0b100000000000000100000000]
    
    var modKeysPrevEvent: NSDate = NSDate()
    
    func keyPressMod(event:NSEvent){
        // Record Event Time Interval Since Last
        let timeSinceLastModKeyEvent = modKeysPrevEvent.timeIntervalSinceNow
        self.modKeysPrevEvent = NSDate()
        
        let prevEventTooClose: Bool = (timeSinceLastModKeyEvent <= -0.045)
        if self.debugging {
            if prevEventTooClose {
                systemMenuMessage(message: "Too Close")
            } else {
                systemMenuMessage(message: "Not Too Close")
            }
        }
        
        // Grab the Current Mod Key Mask
        let bitmask = event.modifierFlags.rawValue
        
        // Key Maps for the Keys
        let modKeysCodes: [String: Int] = ["keyShiftRight":  60,
                                           "keyShiftLeft":   57,
                                           "keyAltLeft":     58,
                                           "keyAltRight":    61,
                                           "keyCMDLeft":     55,
                                           "keyCMDRight":    555, // Not the actual Key code. Used to Diff left from right.
                                           "keyControl":     59,
                                           "keyFunction":    63]
        
        // Create New Key Press Array
        var modKeysCurrent: [String: Bool] = ["keyShiftRight":  false,
                                              "keyShiftLeft":   false,
                                              "keyAltLeft":     false,
                                              "keyAltRight":    false,
                                              "keyCMDLeft":     false,
                                              "keyCMDRight":    false,
                                              "keyControl":     false,
                                              "keyFunction":    false]
        
        // Create New Mod Key Array and See Which Key was Pressed or Released
        for (key, _) in self.modKeysPrev {
            modKeysCurrent[key] = (bitmask & modKeyMask[key]! == modKeyMask[key])
            if modKeysCurrent[key] != self.modKeysPrev[key] && !self.modKeysMuted && !self.volumeMuted && prevEventTooClose {
                if let keyWasDown = self.modKeysPrev[key] {
                    if keyWasDown {
                        // Key was Released
                        playSoundForKey(key: modKeysCodes[key]!, keyIsDown: false)
                        systemMenuMessage(message: "\(key) Up")
                    } else {
                        // Key was Pressed
                        playSoundForKey(key: modKeysCodes[key]!, keyIsDown: true)
                        systemMenuMessage(message: "\(key) Down")
                    }
                }
            }
        }
        
        // Now Let's Update the Stored Key Mask
        self.modKeysPrev = modKeysCurrent
        self.modKeysPrevMask = bitmask
    }
    
    // MARK: Key Sound Function
    
    // The Map of All the Keys with Location and Sound to Play.
    // [key: [location, sound]]
    // The key is the numarical key, location is 0-10, 0 is left 10 is right, 5 is middle
    // Sounds are 0, 1, or 2 with 0 being normal key sounds, 1 being larger keys,
    // and all of the mod keys are 3, for a shifting like sound that I may add in the future
    
    let keyMap: [Int: Array<Int>] =  [1000:  [5,3], // Mouse Key
                                      53:  [0,0],
                                      50:  [0,0],
                                      48:  [0,1],
                                      57:  [0,2],
                                      63:  [0,2],
                                      122: [1,0],
                                      18:  [1,0],
                                      19:  [1,0],
                                      12:  [1,0],
                                      0:   [1,0],
                                      59:  [1,2],
                                      120: [2,0],
                                      99:  [2,0],
                                      20:  [2,0],
                                      13:  [2,0],
                                      1:   [2,0],
                                      6:   [2,0],
                                      7:   [2,0],
                                      58:  [2,2],
                                      118: [3,0],
                                      21:  [3,0],
                                      14:  [3,0],
                                      15:  [3,0],
                                      2:   [3,0],
                                      8:   [3,0],
                                      55:  [3,2],
                                      96:  [4,0],
                                      23:  [4,0],
                                      22:  [4,0],
                                      17:  [4,0],
                                      3:   [4,0],
                                      5:   [4,0],
                                      9:   [4,0],
                                      97:  [5,0],
                                      26:  [5,0],
                                      16:  [5,0],
                                      4:   [5,0],
                                      11:  [5,0],
                                      45:  [5,0],
                                      49:  [5,1],
                                      98:  [6,0],
                                      28:  [6,0],
                                      32:  [6,0],
                                      34:  [6,0],
                                      38:  [6,0],
                                      40:  [6,0],
                                      46:  [6,0],
                                      100: [7,0],
                                      25:  [7,0],
                                      29:  [7,0],
                                      31:  [7,0],
                                      37:  [7,0],
                                      43:  [7,0],
                                      555: [7,2],
                                      101: [8,0],
                                      109: [8,0],
                                      27:  [8,0],
                                      35:  [8,0],
                                      41:  [8,0],
                                      47:  [8,0],
                                      44:  [8,0],
                                      61:  [8,2],
                                      103: [9,0],
                                      24:  [9,0],
                                      33:  [9,0],
                                      30:  [9,0],
                                      39:  [9,0],
                                      123: [9,1],
                                      111: [10,0],
                                      51:  [10,1],
                                      42:  [10,0],
                                      76:  [10,1],
                                      36:  [10,1],
                                      60:  [10,2],
                                      126: [10,1],
                                      125: [10,1],
                                      124: [10,1]]
    
    // Load an Array of Sound Players
    
    func loadSounds() {
        for (sound, files) in soundFiles[self.profile] {
            var downFiles: [AVAudioPlayer?] = []
            if let soundURL = Bundle.main.url(forResource: files.0, withExtension: "wav"){
                for _ in 0...self.playersMax {
                    do {
                        try downFiles.append( AVAudioPlayer(contentsOf: soundURL) )
                    } catch {
                        print("Failed to load \(files.0)")
                    }
                }
            }else{
                print("Can't Find Sound Files \(files.0)")
            }
            var upFiles: [AVAudioPlayer?] = []
            if let soundURL = Bundle.main.url(forResource: files.1, withExtension: "wav"){
                for _ in 0...self.playersMax {
                    do {
                        try upFiles.append( AVAudioPlayer(contentsOf: soundURL) )
                    } catch {
                        print("Failed to load \(files.1)")
                    }
                }
            }else{
                print("Can't Find Sound Files \(files.1)")
            }
            
            self.players[sound] = (downFiles, upFiles)
            self.playersCurrentPlayer[sound] = (0, 0)
        }
        
        // Set the Sound Level to the Settings Level
        volumeUpdate()
    }
    
    func playSoundForKey(key: Int, keyIsDown down: Bool){
        
        var keyLocation: Float = 0
        var keySound: Int = 0
        
        if let keySetings = keyMap[key] {
            keyLocation = (Float(keySetings[0]) - 5) / 5 * 0.2  // 0.2 is the stereo default sensitivity
            keySound = keySetings[1]
        }
        
        func play(player: AVAudioPlayer, keyLocation: Float){
            if !player.isPlaying {
                if self.keyRandomize {
                    // Randomize Pitch
                    player.enableRate = true
                    player.rate = Float.random(in: 1.0 ... 1.2 )
                    
                    // Randomize Volume
                    player.volume = self.volumeLevel * Float.random(in: 0.95 ... 1.0 )
                }
                player.pan = keyLocation
                player.play()
            }
        }
        
        if down {
            if let player = self.players[keySound]?.0[(self.playersCurrentPlayer[keySound]?.0)!]{
                play(player: player, keyLocation: keyLocation)
            }
            self.playersCurrentPlayer[keySound]?.0 += 1
            if (self.playersCurrentPlayer[keySound]?.0)! >= self.playersMax {
                self.playersCurrentPlayer[keySound]?.0 = 0
            }
        } else if self.keyUpSound {
            if let player = self.players[keySound]?.1[(self.playersCurrentPlayer[keySound]?.1)!]{
                play(player: player, keyLocation: keyLocation)
            }
            self.playersCurrentPlayer[keySound]?.1 += 1
            if (self.playersCurrentPlayer[keySound]?.1)! >= self.playersMax {
                self.playersCurrentPlayer[keySound]?.1 = 0
            }
        }
    }
    
    // MARK: System Menu Setup
    let menuItemVolumeMute = NSMenuItem(title: "Mute Keys", action: #selector(menuSetVolMute), keyEquivalent: "")
    let menuItemVolume10 = NSMenuItem(title: "10% Volume", action: #selector(menuSetVol0), keyEquivalent: "")
    let menuItemVolume25 = NSMenuItem(title: "25% Volume", action: #selector(menuSetVol1), keyEquivalent: "")
    let menuItemVolume50 = NSMenuItem(title: "50% Volume", action: #selector(menuSetVol2), keyEquivalent: "")
    let menuItemVolume75 = NSMenuItem(title: "75% Volume", action: #selector(menuSetVol3), keyEquivalent: "")
    let menuItemVolume100 = NSMenuItem(title: "100% Volume", action: #selector(menuSetVol4), keyEquivalent: "")
    
    let menuItemAbout = NSMenuItem(title: "About MKSTE", action: #selector(menuAbout), keyEquivalent: "")
    let menuItemQuit = NSMenuItem(title: "Quit", action: #selector(menuQuit), keyEquivalent: "")
    
    func menuCreate(){
        self.menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        self.menuItem?.highlightMode = true

        if let imgURL = Bundle.main.url(forResource: "sysmenuicon", withExtension: "png"){
            let image = NSImage(byReferencing: imgURL)
            image.isTemplate = true
            image.size.width = 18
            image.size.height = 18
            self.menuItem?.image = image
        } else {
            self.menuItem?.title = "MechKey"
        }
        
        let menu = NSMenu()
        menu.addItem(self.menuItemVolumeMute)
        menu.addItem(self.menuItemVolume10)
        menu.addItem(self.menuItemVolume25)
        menu.addItem(self.menuItemVolume50)
        menu.addItem(self.menuItemVolume75)
        menu.addItem(self.menuItemVolume100)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(self.menuItemAbout)
        menu.addItem(self.menuItemQuit)
        
        self.menuItem?.menu = menu
    }
    
    @objc func menuSetVolMute(){
        volumeSet(vol: self.volumeLevel, muted: true)
    }
    
    @objc func menuSetVol0(){
        volumeSet(vol: 0.10, muted: false)
    }
    
    @objc func menuSetVol1(){
        volumeSet(vol: 0.25, muted: false)
    }
    
    @objc func menuSetVol2(){
        volumeSet(vol: 0.50, muted: false)
    }
    
    @objc func menuSetVol3(){
        volumeSet(vol: 0.75, muted: false)
    }
    
    @objc func menuSetVol4(){
        volumeSet(vol: 1.00, muted: false)
    }
    
    @objc func menuProfile0(){
        profileSet(profile: 0)
    }
    
    @objc func menuProfile1(){
        profileSet(profile: 1)
    }
    
    @objc func menuProfile2(){
        profileSet(profile: 2)
    }
    
    @objc func menuAbout(){
        NSWorkspace.shared.open(NSURL(string: "https://github.com/MrKai77/MKSTE")! as URL)
    }
    
    @objc func menuQuit(){
        NSApp.terminate(nil)
    }
    
    // MARK: Volume Settings
    func volumeLoad(){
        if UserDefaults.standard.object(forKey: "VolumeLevel") != nil {
            self.volumeLevel = UserDefaults.standard.float(forKey: "VolumeLevel")
        }
        if UserDefaults.standard.object(forKey: "VolumeMuted") != nil {
            self.volumeMuted = UserDefaults.standard.bool(forKey: "VolumeMuted")
        }
    }
    
    func volumeSave(){
        UserDefaults.standard.set(self.volumeLevel, forKey: "VolumeLevel")
        UserDefaults.standard.set(self.volumeMuted, forKey: "VolumeMuted")
        UserDefaults.standard.synchronize()
    }
    
    func volumeSet(vol: Float, muted: Bool){
        self.volumeMuted = muted
        self.volumeLevel = vol
        
        volumeUpdate()
        volumeSave()
        playSoundForKey(key: 0, keyIsDown: true)
    }
    
    func volumeUpdate(){
        for (_, players) in self.players{
            for player in players.0 {
                player?.volume = self.volumeLevel
                player?.enableRate = false
                player?.rate = 1
            }
            for player in players.1 {
                player?.volume = self.volumeLevel
                player?.enableRate = false
                player?.rate = 1
            }
        }
        
        // Update Menu to Match the Setting
        self.menuItemVolumeMute.state = NSControl.StateValue.off
        self.menuItemVolume10.state = NSControl.StateValue.off
        self.menuItemVolume25.state = NSControl.StateValue.off
        self.menuItemVolume50.state = NSControl.StateValue.off
        self.menuItemVolume75.state = NSControl.StateValue.off
        self.menuItemVolume100.state = NSControl.StateValue.off
        
        if self.volumeMuted {
            self.menuItemVolumeMute.state = NSControl.StateValue.on
        } else if self.volumeLevel == 0.10 {
            self.menuItemVolume10.state = NSControl.StateValue.on
        } else if self.volumeLevel == 0.25 {
            self.menuItemVolume25.state = NSControl.StateValue.on
        } else if self.volumeLevel == 0.50 {
            self.menuItemVolume50.state = NSControl.StateValue.on
        } else if self.volumeLevel == 0.75 {
            self.menuItemVolume75.state = NSControl.StateValue.on
        } else if self.volumeLevel == 1 {
            self.menuItemVolume100.state = NSControl.StateValue.on
        }
    }
    // MARK: Profile Settings
    
    func profileLoad(){
        if UserDefaults.standard.object(forKey: "profile") != nil {
            self.profile = UserDefaults.standard.integer(forKey: "profile")
        }
        profileUpdate()
    }
    func profileSet(profile: Int) {
        self.profile = profile
        UserDefaults.standard.set(self.profile, forKey: "profile")
        UserDefaults.standard.synchronize()
        profileUpdate()
    }
    func profileUpdate(){
        self.players = [:]
        self.playersCurrentPlayer = [:]
        loadSounds()
    }

    // MARK: Randomize Sound Setting

    func keyRandomizeLoad() {
        if UserDefaults.standard.object(forKey: "keyRandomize") != nil {
            self.keyRandomize = UserDefaults.standard.bool(forKey: "keyRandomize")
        }
    }
    
    // MARK: Permissions Request
    func checkPrivecyAccess(){
        //get the value for accesibility
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        //set the options: false means it wont ask
        //true means it will popup and ask
        let options = [checkOptPrompt: true]
        //translate into boolean value
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "MKSTE Needs Permissions"
            alert.informativeText = "MKSTE needs accessibility permissions. To do this, do the following: \n\nOpen System Preferences > Security & Privacy > Privacy > Accessibility, click on the Padlock in the bottom lefthand corner, and drag the MKS app into the list. \n\nHitting OK will close MKS. After you have done this, restart the app."
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
    
    // MARK: Debugging Functions
    
    func systemMenuMessage(message: String){
        if self.debugging {
            self.menuItem?.title = message
        }
    }
}
