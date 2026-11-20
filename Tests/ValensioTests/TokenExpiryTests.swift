//
//  TokenExpiryTests.swift
//  ValensioTests
//
//  Created by Ahmet Geymen on 19.11.2026.
//

import Testing
import Valensio
import Foundation

struct TokenExpiryTests {

    /// Builds a minimal JWT (`header.payload.signature`) carrying the given `exp` claim.
    private func makeJWT(exp: TimeInterval) -> String {
        func segment(_ object: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = segment(["alg": "none", "typ": "JWT"])
        let payload = segment(["exp": exp])
        return "\(header).\(payload).signature"
    }

    @Test
    func validJWTIsNotExpired() {
        let token = makeJWT(exp: Date().addingTimeInterval(3600).timeIntervalSince1970)
        #expect(TokenExpiry.isExpired(token, format: .jwt) == false)
    }

    @Test
    func expiredJWTIsExpired() {
        let token = makeJWT(exp: Date().addingTimeInterval(-3600).timeIntervalSince1970)
        #expect(TokenExpiry.isExpired(token, format: .jwt))
    }

    @Test
    func clockSkewBufferTreatsSoonToExpireAsExpired() {
        // Expires in 30s but default 60s skew buffer should consider it expired.
        let token = makeJWT(exp: Date().addingTimeInterval(30).timeIntervalSince1970)
        #expect(TokenExpiry.isExpired(token, format: .jwt))
    }

    @Test
    func malformedTokenIsTreatedAsExpired() {
        #expect(TokenExpiry.isExpired("not-a-token", format: .jwt))
        #expect(TokenExpiry.isExpired("not-a-token", format: .pasetoV4Public))
    }

    @Test
    func wrongPasetoHeaderIsTreatedAsExpired() {
        #expect(TokenExpiry.isExpired("v2.local.abc", format: .pasetoV4Public))
    }
}
