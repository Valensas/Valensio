//
//  BearerCredential.swift
//  Valensio
//
//  Created by Ahmet Geymen on 19.11.2026.
//

import Foundation

/// A credential that can authorize a request via the `Authorization: Bearer` scheme.
///
/// Abstracting the bearer value (and its refresh token) lets the auth interceptors
/// work with any token model — OIDC `Token`, PASETO, or a custom app credential —
/// instead of a single concrete type.
public protocol BearerCredential: Sendable {
    /// The value placed after `Bearer ` in the `Authorization` header.
    var bearerToken: String { get }

    /// The refresh token used to obtain a new credential, if any.
    var refreshToken: String? { get }
}

extension Token: BearerCredential {
    /// OIDC resource servers expect the ID token as the bearer value.
    public var bearerToken: String { idToken }
}
