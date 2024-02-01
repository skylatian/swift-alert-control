//
//  AppDelegate.swift
//  alert control
//
//  Created by sky on 9/11/23.
//

import Cocoa

import LaunchAtLogin

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    var updateVolumeTask: DispatchWorkItem?

    var preferencesWindowController: NSWindowController?
    
    @objc func toggleStartAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
        if let startAtLoginItem = statusItem.menu?.item(withTitle: "Start at Login") {
            startAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    
    var alertsMuted: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "alertsMuted")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "alertsMuted")
        }
    }
    var oldVolume: Int {
        get {
            return UserDefaults.standard.integer(forKey: "oldVolume")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "oldVolume")
        }
    }
    var newVolume: Int {
        get {
            return UserDefaults.standard.integer(forKey: "newVolume")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "newVolume")
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //statusItem.isVisible = true //not necesarry?
        updateStatusItemIcon()
        
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        
        //if let window = NSApplication.shared.windows.first {
          //  window.orderOut(self) }
    }

    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type.rawValue == 4 { //right click
            // Handle right click
            print(event.type.rawValue)
            
            let menu = NSMenu()
            
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            if let menuDropdownView = storyboard.instantiateController(withIdentifier: "menuDropdownView") as? NSViewController {
                let customView = menuDropdownView.view
                let customMenuItem = NSMenuItem()
                customMenuItem.view = customView
                menu.addItem(customMenuItem)
                
                let startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
                startAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
                menu.addItem(startAtLoginItem)

                
                if let storyboardSlider = customView.subviews.first(where: { $0 is NSSlider }) as? NSSlider {
                    storyboardSlider.target = self
                    storyboardSlider.action = #selector(sliderValueChanged(sender:))
                    if alertsMuted != true {
                        storyboardSlider.integerValue = getCurrentAlertVolume()
                        print("unmuted, slider value changed")
                    }
                    else if alertsMuted == true {
                        print("slider not changed, alerts muted")
                    }

                    
                }
                
            }
            
            menu.addItem(NSMenuItem.separator()) //adds a line
            
            let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(openPreferencesWindow), keyEquivalent: ",")
            menu.addItem(preferencesItem)
            
            menu.addItem(withTitle: "Quit", action:#selector(NSApplication.terminate), keyEquivalent: "q")
            
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Handle left click
            toggleAlertVolume()
            updateStatusItemIcon()
        }
    }
    
    @objc func openPreferencesWindow() {
        if preferencesWindowController == nil {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            preferencesWindowController = storyboard.instantiateController(withIdentifier: "PreferencesWindowController") as? NSWindowController
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func sliderValueChanged(sender: NSSlider) {
        updateVolumeTask?.cancel()
        
        let task = DispatchWorkItem {
            let volumeValue = sender.integerValue
            self.setAlertVolume(volumeValue)
            print("volume set to: ", volumeValue)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
        updateVolumeTask = task
    }

    func getCurrentAlertVolume() -> Int {
        return Int(shell("osascript -e 'alert volume of (get volume settings)'")) ?? 0
    }

    func setAlertVolume(_ volume: Int) {
        shell("osascript -e 'set volume alert volume \(volume)'")
    }

    func toggleAlertVolume() {
        if alertsMuted {
            setAlertVolume(oldVolume)
            print("unmuted", oldVolume)
            alertsMuted = false
        } else {
            oldVolume = getCurrentAlertVolume()
            if oldVolume == 0 {
                oldVolume = 75 //default volume
            }
            setAlertVolume(0)
            newVolume = getCurrentAlertVolume()
            print("muted", newVolume)
            alertsMuted = true
        }
    }

    func updateStatusItemIcon() {
        if let button = statusItem.button {
            if alertsMuted {
                //button.title = "🔕" // Crossed out bell
                button.image = NSImage(systemSymbolName: "bell.slash", accessibilityDescription: nil)
            } else {
                //button.title = "🔔" // Bell
                button.image = NSImage(systemSymbolName: "bell", accessibilityDescription: nil)
            }
        }
    }

    func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
