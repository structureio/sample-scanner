//
//  AppDelegate.swift
//  SwiftScanner
//
//      _ ______________________________________________________________
//     /|______________________________________________________________|\
//    / /##############################################################\ \
//   / /###::########  #######################################  ########\ \
//   | |###::######      ###|@@@@@|#########################      ######| |
//   | |###::######      ###|@@@@@|#########################      ######| |
//   \ \###::########  #######################################  ########/ /
//     \\##############################################################//
//      +--------------------------------------------------------------+
//
//  Created by Christopher Worley on 07/11/23.
//  Copyright © 2023 Ruthless Research, LLC. All rights reserved.
//

import UIKit
import AVFoundation
import Structure

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var STWirelessLogEnabled: Bool = false

    func registerDefaultsFromSettingsBundle() {

        // this function writes default settings as settings
        if let settingsBundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle"),
           let settings = NSDictionary(contentsOfFile: "\(settingsBundlePath)/Root.plist"),
           let preferences = settings.object(forKey: "PreferenceSpecifiers") as? [NSDictionary] {
            var defaultsToRegister = [String: Any]()
            for preference in preferences {
                if let key = preference.object(forKey: "Key") as? String {
                    defaultsToRegister[key] = preference.object(forKey: "DefaultValue")
                    guard let defaultVal = preference.object(forKey: "DefaultValue")! as? CVarArg else { return }
                    print(String(format: "writing as default %@ to the key %@", defaultVal, key))
                }
            }
            UserDefaults.standard.register(defaults: defaultsToRegister)
        }
    }

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.

        if STWirelessLogEnabled {
            // STWirelessLog is very helpful for debugging while your Structure Sensor is plugged in.
            // See SDK documentation for how to start a listener on your computer.

            var error: NSError?
            let remoteLogHost = "192.168.1.1"

            STWirelessLog.broadcastLogsToWirelessConsole(atAddress: remoteLogHost, usingPort: 49999, error: &error)

            if error != nil {
                NSLog("Oh no! Can't start wireless log: %@", error!.localizedDescription)
            }
        }

        registerDefaultsFromSettingsBundle()

        return true
    }

	func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
		return .landscapeRight
	}

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		// Saves changes in the application's managed object context before the application terminates.
	}

}
