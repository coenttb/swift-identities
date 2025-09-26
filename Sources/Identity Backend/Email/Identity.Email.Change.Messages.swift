//
//  File.swift
//  coenttb-identities
//
//  Created by Coen ten Thije Boonkkamp on 10/10/2024.
//

import IdentitiesTypes
import HTMLEmail
import HTML
import ServerFoundation

// MARK: - Email Change Messages Namespace

extension Identity.Email.Change {
    /// Namespace for email messages/templates related to email changes
    package enum Messages {}
}

// MARK: - Message Types

extension Identity.Email.Change.Messages {
    /// Top-level email change message types
    package enum Message {
        case request(Request)
        case confirmation(Confirmation)
    }
    
    /// Email messages related to email change requests
    package enum Request {
        case notification(Notification)
        
        package struct Notification: Sendable {
            package let currentEmail: EmailAddress
            package let newEmail: EmailAddress
            package let userName: String?
            
            package init(
                currentEmail: EmailAddress,
                newEmail: EmailAddress,
                userName: String?
            ) {
                self.currentEmail = currentEmail
                self.newEmail = newEmail
                self.userName = userName
            }
        }
    }
    
    /// Email messages related to email change confirmations
    package enum Confirmation {
        case request(Request)
        case notification(Notification)
        
        package struct Request: Sendable {
            package let verificationURL: URL
            package let currentEmail: EmailAddress
            package let newEmail: EmailAddress
            package let userName: String?
            
            package init(
                verificationURL: URL,
                currentEmail: EmailAddress,
                newEmail: EmailAddress,
                userName: String?
            ) {
                self.verificationURL = verificationURL
                self.currentEmail = currentEmail
                self.newEmail = newEmail
                self.userName = userName
            }
        }
        
        package enum Notification: Sendable {
            case currentEmail(Payload)
            case newEmail(Payload)
            
            package struct Payload: Sendable {
                package let currentEmail: EmailAddress
                package let newEmail: EmailAddress
                package let userName: String?
                
                package init(
                    currentEmail: EmailAddress,
                    newEmail: EmailAddress,
                    userName: String?
                ) {
                    self.currentEmail = currentEmail
                    self.newEmail = newEmail
                    self.userName = userName
                }
            }
        }
    }
}
