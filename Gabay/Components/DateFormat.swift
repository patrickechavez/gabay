//
//  DateFormat.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Patterns DateField can render; use .custom for anything not listed.
enum DateFormat: Hashable, Sendable {

    // Numeric dates
    case monthDayYear           // 04/23/1998
    case dayMonthYear           // 23/04/1998
    case yearMonthDay           // 1998/04/23
    case dotted                 // 23.04.1998
    case iso                    // 1998-04-23
    case shortMonthDayYear      // 04/23/98

    // Written dates
    case abbreviated            // Apr 23, 1998
    case full                   // April 23, 1998
    case dayFirstAbbreviated    // 23 Apr 1998
    case withWeekday            // Thu, Apr 23, 1998
    case fullWithWeekday        // Thursday, April 23, 1998
    case monthYear              // April 1998

    // Date and time
    case monthDayYearTime12     // 04/23/1998 5:30 PM
    case monthDayYearTime24     // 04/23/1998 17:30
    case isoDateTime            // 1998-04-23 17:30
    case iso8601                // 1998-04-23T17:30:00+0000

    // Time only
    case time12                 // 5:30 PM
    case time24                 // 17:30
    case time24WithSeconds      // 17:30:45

    case custom(String)

    var pattern: String {
        switch self {
        case .monthDayYear: "MM/dd/yyyy"
        case .dayMonthYear: "dd/MM/yyyy"
        case .yearMonthDay: "yyyy/MM/dd"
        case .dotted: "dd.MM.yyyy"
        case .iso: "yyyy-MM-dd"
        case .shortMonthDayYear: "MM/dd/yy"
        case .abbreviated: "MMM d, yyyy"
        case .full: "MMMM d, yyyy"
        case .dayFirstAbbreviated: "d MMM yyyy"
        case .withWeekday: "EEE, MMM d, yyyy"
        case .fullWithWeekday: "EEEE, MMMM d, yyyy"
        case .monthYear: "MMMM yyyy"
        case .monthDayYearTime12: "MM/dd/yyyy h:mm a"
        case .monthDayYearTime24: "MM/dd/yyyy HH:mm"
        case .isoDateTime: "yyyy-MM-dd HH:mm"
        case .iso8601: "yyyy-MM-dd'T'HH:mm:ssZ"
        case .time12: "h:mm a"
        case .time24: "HH:mm"
        case .time24WithSeconds: "HH:mm:ss"
        case let .custom(pattern): pattern
        }
    }

    // A format that prints a time has to let the user choose one.
    var components: DatePicker.Components {
        switch self {
        case .time12, .time24, .time24WithSeconds:
            .hourAndMinute
        case .monthDayYearTime12, .monthDayYearTime24, .isoDateTime, .iso8601:
            [.date, .hourAndMinute]
        case let .custom(pattern):
            Self.components(inferredFrom: pattern)
        default:
            .date
        }
    }

    // A custom pattern has to be read to know which picker to show.
    private static func components(inferredFrom pattern: String) -> DatePicker.Components {
        // Anything inside quotes is literal text, not a field.
        let fields = pattern.split(separator: "'", omittingEmptySubsequences: false)
            .enumerated()
            .filter { $0.offset.isMultiple(of: 2) }
            .map(\.element)
            .joined()

        let hasDate = fields.contains { "yYMdDEL".contains($0) }
        let hasTime = fields.contains { "hHmsa".contains($0) }

        return switch (hasDate, hasTime) {
        case (true, true): [.date, .hourAndMinute]
        case (false, true): .hourAndMinute
        default: .date
        }
    }
}
