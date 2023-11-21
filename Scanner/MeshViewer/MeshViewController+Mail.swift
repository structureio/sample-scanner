/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Foundation
import MessageUI

extension MeshViewController: MFMailComposeViewControllerDelegate {

  public func createEmailUrl(recipient: String, subject: String, body: String) -> URL? {
    let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

    let gmailUrl = URL(string: "googlegmail://co?to=\(recipient)&subject=\(subjectEncoded)&body=\(bodyEncoded)")
    let outlookUrl = URL(string: "ms-outlook://compose?to=\(recipient)&subject=\(subjectEncoded)")
    let yahooMail = URL(string: "ymail://mail/compose?to=\(recipient)&subject=\(subjectEncoded)&body=\(bodyEncoded)")
    let sparkUrl = URL(string: "readdle-spark://compose?recipient=\(recipient)&subject=\(subjectEncoded)&body=\(bodyEncoded)")
    let airMail = URL(string: "airmail://compose?to=\(recipient)&subject=\(subjectEncoded)&plainBody=\(bodyEncoded)")
    let protonMail = URL(string: "protonmail://mailto?:=\(recipient)&subject=\(subjectEncoded)&body=\(bodyEncoded)")
    let fastMail = URL(string: "fastmail://mail/compose?to=\(recipient)&subject=\(subjectEncoded)&body=\(bodyEncoded)")
    let dispatchMail = URL(string: "x-dispatch://compose?to=\(recipient)&subject=\(subjectEncoded)&body=\(bodyEncoded)")
    let defaultUrl = URL(string: "mailto:\(recipient)?subject=\(subjectEncoded)&body=\(bodyEncoded)")

    if let gmailUrl = gmailUrl, UIApplication.shared.canOpenURL(gmailUrl) {
      return gmailUrl
    } else if let outlookUrl = outlookUrl, UIApplication.shared.canOpenURL(outlookUrl) {
      return outlookUrl
    } else if let yahooMail = yahooMail, UIApplication.shared.canOpenURL(yahooMail) {
      return yahooMail
    } else if let sparkUrl = sparkUrl, UIApplication.shared.canOpenURL(sparkUrl) {
      return sparkUrl
    } else if let airMail = airMail, UIApplication.shared.canOpenURL(airMail) {
      return airMail
    } else if let protonMail = protonMail, UIApplication.shared.canOpenURL(protonMail) {
      return protonMail
    } else if let fastMail = fastMail, UIApplication.shared.canOpenURL(fastMail) {
      return fastMail
    } else if let dispatchMail = dispatchMail, UIApplication.shared.canOpenURL(dispatchMail) {
      return dispatchMail
    }

    return defaultUrl
  }

  public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    mailViewController?.dismiss(animated: true)
  }

}
