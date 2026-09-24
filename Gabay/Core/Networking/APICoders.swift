//
//  APICoders.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

extension JSONEncoder {

    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {

    // No snake_case conversion: the backend's JSON already matches Swift's camelCase, and converting would mangle a field like `feePHP` into `fee_p_h_p`.
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601Tolerant
        return decoder
    }
}

private extension JSONDecoder.DateDecodingStrategy {

    static var iso8601Tolerant: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]

            if let date = withFractional.date(from: string) ?? standard.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO 8601 date, got \"\(string)\""
            )
        }
    }
}
