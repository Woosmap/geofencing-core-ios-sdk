//
//  OpeningHoursChecker.swift
//  WoosmapGeofencingCore
//
//  Created by Woosmap on 28/07/25.
//  Copyright © 2025 Woosmap. All rights reserved.



import Foundation

/// A store's opening hours: weekly usual periods, date-specific special periods,
/// temporary closures, and the timezone all times are expressed in.
///
/// `usual` and `special` are keyed by day: usual days use ISO 8601 keys
/// (`"1"` = Monday … `"7"` = Sunday) plus an optional `"default"` fallback,
/// while special days are keyed by calendar date (`"yyyy-MM-dd"`).
struct OpeningHours: Codable {
    var usual: [String: [OpeningPeriod]]
    let special: [String: [OpeningPeriod]]
    let temporaryClosure: [ClosuerPeriod]
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case usual, special, timezone
        case temporaryClosure = "temporary_closure"
    }

    /// Builds an ``OpeningHours`` value from a loosely-typed dictionary (e.g. a
    /// parsed JSON payload), defaulting missing `special` / `temporary_closure`
    /// entries to empty before decoding.
    ///
    /// - Parameter input: The raw `opening_hours` dictionary.
    /// - Returns: The decoded value, or `nil` if decoding fails.
    static func openingHoursFrom(dictionary input: [String: Any]) -> OpeningHours? {
        do {
            var dictionary = input
            if dictionary["special"] == nil{
                dictionary["special"] = [:]
            }
            if dictionary["temporary_closure"] == nil{
                dictionary["temporary_closure"] = []
            }
            
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            let decoder = JSONDecoder()
            return try decoder.decode(OpeningHours.self, from: data)
        } catch {
            print("Failed to decode OpeningHoursData: \(error)")
            return nil
        }
    }
}

/// A single opening slot within a day. Times are `"HH:mm"` strings; a slot whose
/// `end` is earlier than its `start` (e.g. `22:00 → 02:00`) runs overnight into
/// the next day. `allDay == true` marks the store open for the whole day.
struct OpeningPeriod: Codable {
    let start: String?
    let end: String?
    let allDay: Bool?

    enum CodingKeys: String, CodingKey {
        case start, end
        case allDay = "all-day"
    }
}

/// A temporary closure spanning the inclusive date range `start ... end`
/// (`"yyyy-MM-dd"`). A single-day closure has `start == end`.
struct ClosuerPeriod: Codable {
    let start: String
    let end: String

    enum CodingKeys: String, CodingKey {
        case start, end
    }
}

/// A store's weekly opening schedule keyed by ISO 8601 day (`"1"`…`"7"`),
/// decoded from a dynamic-key JSON object alongside its `timezone`.
struct WeeklyOpening: Codable {
    let days: [String: DayOpening]
    let timezone: String
    enum CodingKeys: String, CodingKey {
        case timezone
    }

    /// Decodes `timezone` and every day entry whose key is `"1"`…`"7"`,
    /// ignoring any other keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timezone = try container.decode(String.self, forKey: .timezone)

        // decode all day keys ("1"..."7")
        let dynamicContainer = try decoder.container(keyedBy: DynamicKey.self)
        var tempDays: [String: DayOpening] = [:]
        for key in dynamicContainer.allKeys {
            if let intKey = Int(key.stringValue), (1...7).contains(intKey) {
                let dayOpening = try dynamicContainer.decode(DayOpening.self, forKey: key)
                tempDays[key.stringValue] = dayOpening
            }
        }
        days = tempDays
    }

    /// A coding key that accepts any string, used to decode the arbitrary
    /// day-number keys of the weekly schedule.
    struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return Int(stringValue) }
        init?(intValue: Int) { self.stringValue = "\(intValue)" }
    }

    /// Builds a ``WeeklyOpening`` from a loosely-typed dictionary (e.g. parsed JSON).
    ///
    /// - Parameter dictionary: The raw `weekly_opening` dictionary.
    /// - Returns: The decoded value, or `nil` if decoding fails.
    static func weeklyOpeningFrom(dictionary: [String: Any]) -> WeeklyOpening? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            let decoder = JSONDecoder()
            return try decoder.decode(WeeklyOpening.self, from: data)
        } catch {
            print("Failed to decode WeeklyOpening: \(error)")
            return nil
        }
    }
}

/// The opening periods for one day of the week, and whether they represent
/// special (date-specific) hours rather than the usual weekly schedule.
struct DayOpening: Codable {
    let hours: [OpeningPeriod]
    let isSpecial: Bool
}


/// The result of an opening-hours check: whether the store is currently open and,
/// when closed, a human-readable description of the next opening time.
struct OpeningStatus {
    public let isOpen: Bool
    public let nextOpening: String?
}

/// Evaluates a store's ``OpeningHours`` to decide whether it is open at a given
/// instant, accounting for special days, temporary closures, and slots that run
/// past midnight. Stateless — all entry points are `static`.
class OpeningHoursChecker {

    /// Determines whether a store is open at a given moment from its opening hours.
    ///
    /// Evaluation happens in the store's own timezone and, in order, considers:
    /// special (date-specific) hours, temporary closures, the current day's usual
    /// hours, and the previous day's overnight hours (slots whose end time is
    /// earlier than their start, e.g. `22:00 → 02:00`) that spill past midnight.
    /// Day keys are ISO 8601 (`"1"` = Monday … `"7"` = Sunday); a `"default"`
    /// entry in `usual` is applied to any day without its own hours.
    ///
    /// - Parameters:
    ///   - inputs: The store's opening hours, including timezone, usual and
    ///     special periods, and temporary closures.
    ///   - validateFor: The instant to evaluate. Defaults to now.
    /// - Returns: An ``OpeningStatus`` whose `isOpen` reports the state at
    ///   `validateFor`, and whose `nextOpening` describes the next opening time
    ///   when closed (`nil` when open or when no upcoming time is known).
    public static func check(openingHours inputs: OpeningHours, validateFor:Date = Date()) -> OpeningStatus {
        
        func datesBetween(start: String, end: String, formatter: DateFormatter) -> [String] {
            guard let startDate = formatter.date(from: start),
                  let endDate = formatter.date(from: end) else {
                return []
            }

            var currentDate = startDate
            var dates: [String] = []

            while currentDate <= endDate {
                let formattedDate = formatter.string(from: currentDate)
                dates.append(formattedDate)

                guard let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }

            return dates
        }
        var openingHours: OpeningHours = inputs
        guard let timeZone = TimeZone(identifier: openingHours.timezone) else {
            return OpeningStatus(isOpen: false, nextOpening: nil)
        }

        let now = validateFor
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = timeZone

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = timeZone

        let todayString = dateFormatter.string(from: now)
        let nowTimeString = timeFormatter.string(from: now)
        guard let nowTime = timeFormatter.date(from: nowTimeString) else {
            return OpeningStatus(isOpen: false, nextOpening: nil)
        }
        for week in 1...7 {
            openingHours.usual[String(week)] = openingHours.usual[String(week)] ?? openingHours.usual["default"]
        }
        // 🔒 Temporary Closure
        var temporaryClosureDays: [String] = []
        
        openingHours.temporaryClosure.forEach { (item) in
            if (item.start != item.end){
                // Calculate days between it
                let datelist = datesBetween(start: item.start,end: item.end, formatter: dateFormatter)
                datelist.forEach { closeDay in
                    temporaryClosureDays.append(closeDay)
                }
            }
            else{
                temporaryClosureDays.append(item.start)
            }
            
        }
            
        if temporaryClosureDays.contains(todayString) {
            return OpeningStatus(isOpen: false, nextOpening: nil)
        }

        // 📅 Get day keys
        let weekday = calendar.component(.weekday, from: now) // Sunday = 1
        let todayInt = weekday == 1 ? 7 : weekday - 1           // ISO: Mon=1 … Sun=7
        let todayKey = String(todayInt) // 1=Monday, ..., 7=Sunday

//        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
//        let yesterdayString = dateFormatter.string(from: yesterday)
        let yesterdayKey = String(todayInt == 1 ? 7 : todayInt - 1)   // wrap Mon → Sun

        // 🟨 1. Check Special for Today
        if let specialToday = openingHours.special[todayString] {
            if let status = checkPeriods(specialToday, nowTime: nowTime, formatter: timeFormatter) {
                return status
            }
            else {
                return OpeningStatus(isOpen: false, nextOpening: "Next Day Opening") //Close today due to special opening time
            }
        }

        // 🟩 2. Check Usual for Today
        if let usualToday = openingHours.usual[todayKey]{
            if let status = checkPeriods(usualToday, nowTime: nowTime, formatter: timeFormatter) {
                return status
            }
        }

        // 🟧 3. Check Yesterday for Overnight Hours
        if let usualYesterday = openingHours.usual[yesterdayKey]{
            for period in usualYesterday {
                guard let startStr = period.start, let endStr = period.end,
                      let start = timeFormatter.date(from: startStr),
                      let end = timeFormatter.date(from: endStr),
                      start > end // Indicates overnight
                else { continue }

                if nowTime <= end {
                    return OpeningStatus(isOpen: true, nextOpening: nil)
                }
            }
        }

        // 🕐 4. Fallback – Return next opening time (first future start today)
        if let next = openingHours.special[todayString]?.compactMap({ $0.start }).first ??
                      openingHours.usual[todayKey]?.compactMap({ $0.start }).first {
            return OpeningStatus(isOpen: false, nextOpening: "Opens at \(next) today")
        }

        return OpeningStatus(isOpen: false, nextOpening: nil)
    }

    /// Returns an open status if `nowTime` falls within any of the given periods.
    ///
    /// Handles all-day periods, normal periods (`start <= end`), and overnight
    /// periods (`start > end`) that wrap past midnight.
    ///
    /// - Parameters:
    ///   - periods: The candidate opening periods for the day.
    ///   - nowTime: The time-of-day to test, as a `"HH:mm"` `Date`.
    ///   - formatter: The `"HH:mm"` formatter used to parse period bounds.
    /// - Returns: An open ``OpeningStatus`` if a matching period is found,
    ///   otherwise `nil`.
    private static func checkPeriods(
        _ periods: [OpeningPeriod],
        nowTime: Date,
        formatter: DateFormatter
    ) -> OpeningStatus? {
        for period in periods {
            if period.allDay == true {
                return OpeningStatus(isOpen: true, nextOpening: nil)
            }

            guard let startStr = period.start, let endStr = period.end,
                  let start = formatter.date(from: startStr),
                  let end = formatter.date(from: endStr) else {
                continue
            }

            if start <= end {
                // Normal period
                if nowTime >= start && nowTime <= end {
                    return OpeningStatus(isOpen: true, nextOpening: nil)
                }
            } else {
                // Overnight period
                if nowTime >= start || nowTime <= end {
                    return OpeningStatus(isOpen: true, nextOpening: nil)
                }
            }
        }
        return nil
    }
}
