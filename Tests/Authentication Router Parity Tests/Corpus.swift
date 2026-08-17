// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-authentication open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-authentication
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// The wire-shape parity corpus, keyed by fixture basename.
///
/// Generated from the former `__Corpus__/<name>.txt` fixtures; each
/// document is byte-identical to the file it replaced.
enum Corpus {}

extension Corpus {
    /// The document stored under `name`, if any.
    static subscript(_ name: String) -> String? {
        documents[name]
    }
}

extension Corpus {
    fileprivate static let documents: [String: String] = [
        "KNOWN-NON-ROUNDTRIP-identity-api-router": ##########"""
        authenticate.token.access: parse(print(route)) != route
        authenticate.token.refresh: parse(print(route)) != route
        """########## + "\n",
        "basic-auth-router": ##########"""
        == basic.fixed-credentials ==
        method: <nil>
        path: /
        header: authorization: Basic cGFyaXR5QGV4YW1wbGUuY29tOmNvcnJlY3QgaG9yc2UgYmF0dGVyeSBzdGFwbGU=
        body: <nil>
        """########## + "\n",
        "bearer-auth-router": ##########"""
        == bearer.fixed-token ==
        method: <nil>
        path: /
        header: authorization: Bearer fixed-token-0123456789abcdef
        body: <nil>
        """########## + "\n",
        "identity-api-router-baseurl": ##########"""
        == authenticate.credentials ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /authenticate
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple&username=parity%40example.com

        == authenticate.token.access ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /authenticate/access
        header: cookie: access_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDA6cGFyaXR5QGV4YW1wbGUuY29tIn0."
        body: <nil>

        == authenticate.token.refresh ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /authenticate/refresh
        header: content-type: application/json
        body(utf8): "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDA6cGFyaXR5QGV4YW1wbGUuY29tIn0."

        == authenticate.apiKey ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /authenticate/api-key
        header: authorization: Bearer fixed-token-0123456789abcdef
        body: <nil>

        == reauthorize ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reauthorize
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple

        == create.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /create/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com&password=correct+horse+battery+staple

        == create.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /create/verify
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com&token=fixed-token-0123456789abcdef

        == delete.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /delete/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): reauthToken=fixed-reauth-token

        == delete.cancel ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /delete/cancel
        body: <nil>

        == delete.confirm ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /delete/confirm
        body: <nil>

        == logout.current ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /logout
        body: <nil>

        == logout.all ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /logout/all
        body: <nil>

        == email.change.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /email/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newEmail=parity-new%40example.com

        == email.change.confirm ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /email/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): token=fixed-token-0123456789abcdef

        == password.reset.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /password/reset/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com

        == password.reset.confirm ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /password/reset/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newPassword=correct+horse+battery+staple&token=fixed-token-0123456789abcdef

        == password.change.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /password/change/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): currentPassword=correct+horse+battery+staple&newPassword=correct+horse+battery+staple

        == mfa.totp.setup ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/totp/setup
        body: <nil>

        == mfa.totp.confirmSetup ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/totp/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): code=123456

        == mfa.totp.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/totp/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.totp.disable ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/totp/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.sms.setup ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/sms/setup
        header: content-type: application/json
        body(utf8/sorted-keys): {"phoneNumber":"+31612345678"}

        == mfa.sms.requestCode ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/sms/request
        body: <nil>

        == mfa.sms.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/sms/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.sms.updatePhoneNumber ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/sms/update
        header: content-type: application/json
        body(utf8/sorted-keys): {"phoneNumber":"+31612345678","reauthorizationToken":"fixed-reauth-token"}

        == mfa.sms.disable ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/sms/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.email.setup ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/email/setup
        header: content-type: application/json
        body(utf8/sorted-keys): {"email":"parity@example.com"}

        == mfa.email.requestCode ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/email/request
        body: <nil>

        == mfa.email.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/email/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.email.updateEmail ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/email/update
        header: content-type: application/json
        body(utf8/sorted-keys): {"email":"parity-new@example.com","reauthorizationToken":"fixed-reauth-token"}

        == mfa.email.disable ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/email/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.webauthn.beginRegistration ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/register/begin
        body: <nil>

        == mfa.webauthn.finishRegistration ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/register/finish
        header: content-type: application/json
        body(utf8/sorted-keys): {"credentialName":"parity-key","response":"{\"fixed\":true}"}

        == mfa.webauthn.beginAuthentication ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/authenticate/begin
        body: <nil>

        == mfa.webauthn.finishAuthentication ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/authenticate/finish
        header: content-type: application/json
        body(utf8/sorted-keys): {"response":"{\"fixed\":true}","sessionToken":"fixed-session-token"}

        == mfa.webauthn.listCredentials ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/credentials
        body: <nil>

        == mfa.webauthn.removeCredential ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/credentials/remove
        header: content-type: application/json
        body(utf8/sorted-keys): {"credentialId":"fixed-credential-id","reauthorizationToken":"fixed-reauth-token"}

        == mfa.webauthn.disable ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/webauthn/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.backupCodes.regenerate ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/backup-codes/regenerate
        body: <nil>

        == mfa.backupCodes.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/backup-codes/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.backupCodes.remaining ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/backup-codes/remaining
        body: <nil>

        == mfa.status.get ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/status
        body: <nil>

        == mfa.status.challenge ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/status/challenge
        body: <nil>

        == mfa.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /reset/verify
        header: content-type: application/x-www-form-urlencoded
        body(utf8): code=123456&method=totp&sessionToken=fixed-session-token

        == oauth.providers ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/providers
        body: <nil>

        == oauth.authorize ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/authorize/github
        body: <nil>

        == oauth.callback ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/callback
        query: code=123456
        query: state=fixed-state
        body: <nil>

        == oauth.connections ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /reset/connections
        body: <nil>

        == oauth.disconnect ==
        method: DELETE
        scheme: https
        host: identity.example.com
        path: /reset/disconnect/github
        body: <nil>
        """########## + "\n",
        "identity-api-router": ##########"""
        == authenticate.credentials ==
        method: POST
        path: /authenticate
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple&username=parity%40example.com

        == authenticate.token.access ==
        method: POST
        path: /authenticate/access
        header: cookie: access_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDA6cGFyaXR5QGV4YW1wbGUuY29tIn0."
        body: <nil>

        == authenticate.token.refresh ==
        method: POST
        path: /authenticate/refresh
        header: content-type: application/json
        body(utf8): "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDA6cGFyaXR5QGV4YW1wbGUuY29tIn0."

        == authenticate.apiKey ==
        method: <nil>
        path: /authenticate/api-key
        header: authorization: Bearer fixed-token-0123456789abcdef
        body: <nil>

        == reauthorize ==
        method: POST
        path: /reauthorize
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple

        == create.request ==
        method: POST
        path: /create/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com&password=correct+horse+battery+staple

        == create.verify ==
        method: POST
        path: /create/verify
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com&token=fixed-token-0123456789abcdef

        == delete.request ==
        method: POST
        path: /delete/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): reauthToken=fixed-reauth-token

        == delete.cancel ==
        method: POST
        path: /delete/cancel
        body: <nil>

        == delete.confirm ==
        method: POST
        path: /delete/confirm
        body: <nil>

        == logout.current ==
        method: POST
        path: /logout
        body: <nil>

        == logout.all ==
        method: POST
        path: /logout/all
        body: <nil>

        == email.change.request ==
        method: POST
        path: /email/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newEmail=parity-new%40example.com

        == email.change.confirm ==
        method: POST
        path: /email/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): token=fixed-token-0123456789abcdef

        == password.reset.request ==
        method: POST
        path: /password/reset/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com

        == password.reset.confirm ==
        method: POST
        path: /password/reset/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newPassword=correct+horse+battery+staple&token=fixed-token-0123456789abcdef

        == password.change.request ==
        method: POST
        path: /password/change/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): currentPassword=correct+horse+battery+staple&newPassword=correct+horse+battery+staple

        == mfa.totp.setup ==
        method: POST
        path: /reset/totp/setup
        body: <nil>

        == mfa.totp.confirmSetup ==
        method: POST
        path: /reset/totp/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): code=123456

        == mfa.totp.verify ==
        method: POST
        path: /reset/totp/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.totp.disable ==
        method: POST
        path: /reset/totp/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.sms.setup ==
        method: POST
        path: /reset/sms/setup
        header: content-type: application/json
        body(utf8/sorted-keys): {"phoneNumber":"+31612345678"}

        == mfa.sms.requestCode ==
        method: POST
        path: /reset/sms/request
        body: <nil>

        == mfa.sms.verify ==
        method: POST
        path: /reset/sms/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.sms.updatePhoneNumber ==
        method: POST
        path: /reset/sms/update
        header: content-type: application/json
        body(utf8/sorted-keys): {"phoneNumber":"+31612345678","reauthorizationToken":"fixed-reauth-token"}

        == mfa.sms.disable ==
        method: POST
        path: /reset/sms/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.email.setup ==
        method: POST
        path: /reset/email/setup
        header: content-type: application/json
        body(utf8/sorted-keys): {"email":"parity@example.com"}

        == mfa.email.requestCode ==
        method: POST
        path: /reset/email/request
        body: <nil>

        == mfa.email.verify ==
        method: POST
        path: /reset/email/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.email.updateEmail ==
        method: POST
        path: /reset/email/update
        header: content-type: application/json
        body(utf8/sorted-keys): {"email":"parity-new@example.com","reauthorizationToken":"fixed-reauth-token"}

        == mfa.email.disable ==
        method: POST
        path: /reset/email/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.webauthn.beginRegistration ==
        method: POST
        path: /reset/webauthn/register/begin
        body: <nil>

        == mfa.webauthn.finishRegistration ==
        method: POST
        path: /reset/webauthn/register/finish
        header: content-type: application/json
        body(utf8/sorted-keys): {"credentialName":"parity-key","response":"{\"fixed\":true}"}

        == mfa.webauthn.beginAuthentication ==
        method: POST
        path: /reset/webauthn/authenticate/begin
        body: <nil>

        == mfa.webauthn.finishAuthentication ==
        method: POST
        path: /reset/webauthn/authenticate/finish
        header: content-type: application/json
        body(utf8/sorted-keys): {"response":"{\"fixed\":true}","sessionToken":"fixed-session-token"}

        == mfa.webauthn.listCredentials ==
        method: GET
        path: /reset/webauthn/credentials
        body: <nil>

        == mfa.webauthn.removeCredential ==
        method: POST
        path: /reset/webauthn/credentials/remove
        header: content-type: application/json
        body(utf8/sorted-keys): {"credentialId":"fixed-credential-id","reauthorizationToken":"fixed-reauth-token"}

        == mfa.webauthn.disable ==
        method: POST
        path: /reset/webauthn/disable
        header: content-type: application/json
        body(utf8/sorted-keys): {"reauthorizationToken":"fixed-reauth-token"}

        == mfa.backupCodes.regenerate ==
        method: POST
        path: /reset/backup-codes/regenerate
        body: <nil>

        == mfa.backupCodes.verify ==
        method: POST
        path: /reset/backup-codes/verify
        header: content-type: application/json
        body(utf8/sorted-keys): {"code":"123456","sessionToken":"fixed-session-token"}

        == mfa.backupCodes.remaining ==
        method: GET
        path: /reset/backup-codes/remaining
        body: <nil>

        == mfa.status.get ==
        method: GET
        path: /reset/status
        body: <nil>

        == mfa.status.challenge ==
        method: GET
        path: /reset/status/challenge
        body: <nil>

        == mfa.verify ==
        method: POST
        path: /reset/verify
        header: content-type: application/x-www-form-urlencoded
        body(utf8): code=123456&method=totp&sessionToken=fixed-session-token

        == oauth.providers ==
        method: GET
        path: /reset/providers
        body: <nil>

        == oauth.authorize ==
        method: GET
        path: /reset/authorize/github
        body: <nil>

        == oauth.callback ==
        method: GET
        path: /reset/callback
        query: code=123456
        query: state=fixed-state
        body: <nil>

        == oauth.connections ==
        method: GET
        path: /reset/connections
        body: <nil>

        == oauth.disconnect ==
        method: DELETE
        path: /reset/disconnect/github
        body: <nil>
        """########## + "\n",
        "identity-route-router-baseurl": ##########"""
        == api.authenticate.credentials ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/authenticate
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple&username=parity%40example.com

        == api.create.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/create/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com&password=correct+horse+battery+staple

        == api.delete.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/delete/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): reauthToken=fixed-reauth-token

        == api.email.change.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/email/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newEmail=parity-new%40example.com

        == api.password.reset.request ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/password/reset/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com

        == api.mfa.verify ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/mfa/verify
        header: content-type: application/x-www-form-urlencoded
        body(utf8): code=123456&method=totp&sessionToken=fixed-session-token

        == api.logout.current ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /logout
        body: <nil>

        == api.reauthorize ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /api/reauthorize
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple

        == api.oauth.providers ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /api/oauth/providers
        body: <nil>

        == view.authenticate.credentials ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /login
        body: <nil>

        == view.create.request ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /create/request
        body: <nil>

        == view.create.verify ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /create/verify
        query: token=fixed-token-0123456789abcdef
        query: email=parity@example.com
        body: <nil>

        == view.delete.request ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /delete
        body: <nil>

        == view.logout ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /logout
        body: <nil>

        == view.email.change.request ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /email/change/request
        body: <nil>

        == view.email.change.confirm ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /email/change/confirm/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): token=fixed-token-0123456789abcdef

        == view.email.change.reauthorization ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /email/change
        body: <nil>

        == view.password.reset.request ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /password/reset/request
        body: <nil>

        == view.password.reset.confirm ==
        method: POST
        scheme: https
        host: identity.example.com
        path: /password/reset/confirm/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newPassword=correct+horse+battery+staple&token=fixed-token-0123456789abcdef

        == view.password.change.request ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /password/change/request
        body: <nil>

        == view.mfa.verify ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/verify
        query: sessionToken=fixed-session-token
        body: <nil>

        == view.mfa.manage ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/manage
        body: <nil>

        == view.mfa.totp.setup ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/totp/setup
        body: <nil>

        == view.mfa.totp.confirmSetup ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/totp/confirm-setup
        body: <nil>

        == view.mfa.totp.manage ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/totp/manage
        body: <nil>

        == view.mfa.backupCodes.display ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/backup-codes/display
        body: <nil>

        == view.mfa.backupCodes.verify ==
        method: <nil>
        scheme: https
        host: identity.example.com
        path: /mfa/backup-codes/verify
        query: sessionToken=fixed-session-token
        body: <nil>

        == view.oauth.login ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /oauth/login
        body: <nil>

        == view.oauth.callback ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /oauth/callback
        query: code=123456
        query: state=fixed-state
        body: <nil>

        == view.oauth.connections ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /oauth/connections
        body: <nil>

        == view.oauth.error ==
        method: GET
        scheme: https
        host: identity.example.com
        path: /oauth/error
        query: message=access_denied
        body: <nil>
        """########## + "\n",
        "identity-route-router": ##########"""
        == api.authenticate.credentials ==
        method: POST
        path: /api/authenticate
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple&username=parity%40example.com

        == api.create.request ==
        method: POST
        path: /api/create/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com&password=correct+horse+battery+staple

        == api.delete.request ==
        method: POST
        path: /api/delete/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): reauthToken=fixed-reauth-token

        == api.email.change.request ==
        method: POST
        path: /api/email/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newEmail=parity-new%40example.com

        == api.password.reset.request ==
        method: POST
        path: /api/password/reset/request
        header: content-type: application/x-www-form-urlencoded
        body(utf8): email=parity%40example.com

        == api.mfa.verify ==
        method: POST
        path: /api/mfa/verify
        header: content-type: application/x-www-form-urlencoded
        body(utf8): code=123456&method=totp&sessionToken=fixed-session-token

        == api.logout.current ==
        method: POST
        path: /logout
        body: <nil>

        == api.reauthorize ==
        method: POST
        path: /api/reauthorize
        header: content-type: application/x-www-form-urlencoded
        body(utf8): password=correct+horse+battery+staple

        == api.oauth.providers ==
        method: GET
        path: /api/oauth/providers
        body: <nil>

        == view.authenticate.credentials ==
        method: <nil>
        path: /login
        body: <nil>

        == view.create.request ==
        method: <nil>
        path: /create/request
        body: <nil>

        == view.create.verify ==
        method: <nil>
        path: /create/verify
        query: token=fixed-token-0123456789abcdef
        query: email=parity@example.com
        body: <nil>

        == view.delete.request ==
        method: <nil>
        path: /delete
        body: <nil>

        == view.logout ==
        method: <nil>
        path: /logout
        body: <nil>

        == view.email.change.request ==
        method: <nil>
        path: /email/change/request
        body: <nil>

        == view.email.change.confirm ==
        method: POST
        path: /email/change/confirm/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): token=fixed-token-0123456789abcdef

        == view.email.change.reauthorization ==
        method: <nil>
        path: /email/change
        body: <nil>

        == view.password.reset.request ==
        method: <nil>
        path: /password/reset/request
        body: <nil>

        == view.password.reset.confirm ==
        method: POST
        path: /password/reset/confirm/confirm
        header: content-type: application/x-www-form-urlencoded
        body(utf8): newPassword=correct+horse+battery+staple&token=fixed-token-0123456789abcdef

        == view.password.change.request ==
        method: <nil>
        path: /password/change/request
        body: <nil>

        == view.mfa.verify ==
        method: <nil>
        path: /mfa/verify
        query: sessionToken=fixed-session-token
        body: <nil>

        == view.mfa.manage ==
        method: <nil>
        path: /mfa/manage
        body: <nil>

        == view.mfa.totp.setup ==
        method: <nil>
        path: /mfa/totp/setup
        body: <nil>

        == view.mfa.totp.confirmSetup ==
        method: <nil>
        path: /mfa/totp/confirm-setup
        body: <nil>

        == view.mfa.totp.manage ==
        method: <nil>
        path: /mfa/totp/manage
        body: <nil>

        == view.mfa.backupCodes.display ==
        method: <nil>
        path: /mfa/backup-codes/display
        body: <nil>

        == view.mfa.backupCodes.verify ==
        method: <nil>
        path: /mfa/backup-codes/verify
        query: sessionToken=fixed-session-token
        body: <nil>

        == view.oauth.login ==
        method: GET
        path: /oauth/login
        body: <nil>

        == view.oauth.callback ==
        method: GET
        path: /oauth/callback
        query: code=123456
        query: state=fixed-state
        body: <nil>

        == view.oauth.connections ==
        method: GET
        path: /oauth/connections
        body: <nil>

        == view.oauth.error ==
        method: GET
        path: /oauth/error
        query: message=access_denied
        body: <nil>
        """########## + "\n",
        "identity-shared-set-bearer-auth": ##########"""
        == logout.current+bearer ==
        method: POST
        path: /logout
        header: authorization: Bearer fixed-token-0123456789abcdef
        body: <nil>

        == delete.confirm+bearer ==
        method: POST
        path: /delete/confirm
        header: authorization: Bearer fixed-token-0123456789abcdef
        body: <nil>
        """########## + "\n",
        "identity-shared-set-reauthorization-token": ##########"""
        == reauthorize+token ==
        method: POST
        path: /reauthorize
        header: content-type: application/x-www-form-urlencoded
        header: authorization: Bearer fixed-reauth-token
        body(utf8): password=correct+horse+battery+staple
        """########## + "\n",
    ]
}
