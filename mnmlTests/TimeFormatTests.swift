//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Testing

@testable import mnml

struct TimeFormatTests {
    @Test func fmtUnderAnHour() {
        #expect(TimeFormat.fmt(249) == "4:09")
        #expect(TimeFormat.fmt(0) == "0:00")
        #expect(TimeFormat.fmt(5) == "0:05")
    }

    @Test func fmtOverAnHour() {
        #expect(TimeFormat.fmt(3862) == "1:04:22")
    }

    @Test func fmtClampsNegative() {
        #expect(TimeFormat.fmt(-10) == "0:00")
    }

    @Test func fmtLongHoursAndMinutes() {
        #expect(TimeFormat.fmtLong(15120) == "4h 12m")
        #expect(TimeFormat.fmtLong(2280) == "38m")
        #expect(TimeFormat.fmtLong(0) == "0m")
    }

    @Test func fmtStatRoundsToWholeHours() {
        #expect(TimeFormat.fmtStat(0) == "0m")
        #expect(TimeFormat.fmtStat(38 * 60) == "38m")
        #expect(TimeFormat.fmtStat(60 * 60) == "1h")
        #expect(TimeFormat.fmtStat(86 * 3600 + 24 * 60) == "86h")
        #expect(TimeFormat.fmtStat(218 * 3600) == "218h")
    }
}
