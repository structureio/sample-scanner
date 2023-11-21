/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import UIKit

extension UserDefaults {
  // check for is first launch - only true on first invocation after app install, false on all further invocations
  var hasConnectedSensorBefore: Bool {
    get {
      return self.bool(forKey: "hasConnectedSensorBefore")
    }
    set {
      self.set(newValue, forKey: "hasConnectedSensorBefore")
      self.synchronize()
    }
  }
}
