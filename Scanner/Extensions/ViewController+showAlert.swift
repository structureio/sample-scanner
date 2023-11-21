/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import UIKit

extension UIViewController {
  func showAlert(title: String, message: String) {
    let alert = UIAlertController(title: title,
      message: message,
      preferredStyle: .alert)

    let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
    alert.addAction(defaultAction)
    present(alert, animated: true, completion: nil)
  }
}
