//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 17/10/2024.
//

import HTML
import HTMLEmail
import IdentitiesTypes
import ServerFoundation

package enum PasswordEmail {
  case reset(PasswordEmail.Reset)
  case change(PasswordEmail.Change)
}

extension PasswordEmail {
  package enum Reset {
    case request(PasswordEmail.Reset.Request)
    case confirmation(PasswordEmail.Reset.Confirmation)
  }

  package enum Change {
    case notification(PasswordEmail.Change.Notification)
  }
}

extension PasswordEmail.Reset {
  package struct Request: Sendable {
    package let resetUrl: URL
    package let userName: String?
    package let userEmail: EmailAddress

    package init(resetUrl: URL, userName: String?, userEmail: EmailAddress) {
      self.resetUrl = resetUrl
      self.userName = userName
      self.userEmail = userEmail
    }
  }

  package struct Confirmation: Sendable {
    package let userName: String?
    package let userEmail: EmailAddress

    package init(userName: String?, userEmail: EmailAddress) {
      self.userName = userName
      self.userEmail = userEmail
    }
  }
}

extension PasswordEmail.Change {
  package struct Notification: Sendable {
    package let userName: String?
    package let userEmail: EmailAddress

    package init(userName: String?, userEmail: EmailAddress) {
      self.userName = userName
      self.userEmail = userEmail
    }
  }
}
