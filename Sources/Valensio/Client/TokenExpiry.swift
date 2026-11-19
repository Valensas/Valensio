//
//  TokenExpiry.swift
//  Valensio
//
//  Created by Ahmet Geymen on 19.11.2026.
//

import Foundation

/// Supported token formats for client-side expiration checking.
public enum TokenFormat: Sendable {
    /// PASETO `v4.public` tokens: `v4.public.<payload || 64-byte Ed25519 signature>`.
    case pasetoV4Public
    /// JSON Web Tokens: `header.payload.signature`.
    case jwt
}

/// Stateless, reusable inspector for deciding whether a bearer token has expired
/// based on its `exp` claim, without verifying the signature.
///
/// This is a *proactive* check (e.g. at app launch). Reactive 401 handling is done
/// by ``RefreshTokenInterceptor``.
public enum TokenExpiry {

    /// Evaluates whether a token has expired based on its `exp` claim.
    /// - Parameters:
    ///   - token: The raw token string (PASETO or JWT).
    ///   - format: The format guiding how segments and payload are parsed.
    ///   - clockSkew: Safety buffer (seconds) applied against clock skew. Defaults to 60.
    /// - Returns: `true` if the token is expired, malformed, or unparseable; `false` otherwise.
    public static func isExpired(
        _ token: String,
        format: TokenFormat,
        clockSkew: TimeInterval = 60
    ) -> Bool {
        let segments = token.components(separatedBy: ".")

        // 1. Basic segment count validation based on token type
        let payloadSegmentIndex: Int
        switch format {
        case .pasetoV4Public:
            // v4.public format: v4.public.<payload_and_sig> (3 segments expected)
            guard segments.count >= 3, segments[0] == "v4", segments[1] == "public" else { return true }
            payloadSegmentIndex = 2
        case .jwt:
            // JWT format: header.payload.signature (3 segments expected)
            guard segments.count >= 3 else { return true }
            payloadSegmentIndex = 1
        }

        let base64URL = segments[payloadSegmentIndex]

        // 2. Convert Base64URL to standard Base64 characters and apply padding
        var base64 =
            base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder == 1 {
            return true  // Invalid Base64 length
        } else if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let decodedData = Data(base64Encoded: base64) else {
            return true
        }

        // 3. Extract JSON payload data depending on token type architecture
        let jsonData: Data
        switch format {
        case .pasetoV4Public:
            // PASETO v4.public appends a 64-byte Ed25519 signature at the end of the decoded segment
            let signatureLength = 64
            guard decodedData.count > signatureLength else { return true }
            jsonData = decodedData.subdata(in: 0..<(decodedData.count - signatureLength))
        case .jwt:
            // JWT payload segment consists directly of pure JSON data
            jsonData = decodedData
        }

        // 4. Parse JSON claims dictionary and extract 'exp'
        guard
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let exp = json["exp"]
        else {
            return true
        }

        let expirationDate: Date
        if let timestamp = exp as? NSNumber {
            expirationDate = Date(timeIntervalSince1970: timestamp.doubleValue)
        } else if let timestampDouble = exp as? Double {
            expirationDate = Date(timeIntervalSince1970: timestampDouble)
        } else if let timestampInt = exp as? Int {
            expirationDate = Date(timeIntervalSince1970: Double(timestampInt))
        } else if let dateString = exp as? String {
            let formatter = ISO8601DateFormatter()
            guard let date = formatter.date(from: dateString) else { return true }
            expirationDate = date
        } else {
            return true
        }

        // Apply the clock-skew safety buffer
        return Date() >= expirationDate.addingTimeInterval(-clockSkew)
    }
}
