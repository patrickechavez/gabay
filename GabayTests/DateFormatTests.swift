//
//  DateFormatTests.swift
//  GabayTests
//

import SwiftUI
import Testing
@testable import Gabay

struct DateFormatTests {

    @Test func aDateOnlyFormatAsksForADatePicker() {
        #expect(DateFormat.monthDayYear.components == .date)
        #expect(DateFormat.abbreviated.components == .date)
    }

    @Test func aTimeOnlyFormatAsksForATimePicker() {
        #expect(DateFormat.time12.components == .hourAndMinute)
        #expect(DateFormat.time24.components == .hourAndMinute)
    }

    @Test func aCombinedFormatAsksForBoth() {
        #expect(DateFormat.monthDayYearTime12.components == [.date, .hourAndMinute])
        #expect(DateFormat.isoDateTime.components == [.date, .hourAndMinute])
    }

    @Test func aCustomPatternIsReadToDecideThePicker() {
        #expect(DateFormat.custom("yyyy-MM-dd").components == .date)
        #expect(DateFormat.custom("HH:mm").components == .hourAndMinute)
        #expect(DateFormat.custom("yyyy-MM-dd HH:mm").components == [.date, .hourAndMinute])
    }

    @Test func quotedTextInACustomPatternIsNotReadAsAField() {
        // The "T" and the "at" are literal text, not hour or minute fields.
        #expect(DateFormat.custom("yyyy-MM-dd'T'").components == .date)
        #expect(DateFormat.custom("MMMM d 'at' h:mm a").components == [.date, .hourAndMinute])
    }

    @Test func aCustomPatternCarriesItsOwnPattern() {
        #expect(DateFormat.custom("dd/MM").pattern == "dd/MM")
    }

    @Test func theBuiltInPatternsAreTheDocumentedOnes() {
        #expect(DateFormat.monthDayYear.pattern == "MM/dd/yyyy")
        #expect(DateFormat.iso.pattern == "yyyy-MM-dd")
        #expect(DateFormat.monthDayYearTime12.pattern == "MM/dd/yyyy h:mm a")
    }
}
