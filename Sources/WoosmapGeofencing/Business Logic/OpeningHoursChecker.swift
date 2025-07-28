//
//  OpeningHoursChecker.swift
//  WoosmapGeofencingCore
//
//  Created by Woosmap on 28/07/25.
//  Copyright © 2025 Woosmap. All rights reserved.



import Foundation
struct OpeningHours: Codable {
    var usual: [String: [OpeningPeriod]]
    let special: [String: [OpeningPeriod]]
    let temporaryClosure: [ClosuerPeriod]
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case usual, special, timezone
        case temporaryClosure = "temporary_closure"
    }
    
    static func openingHoursFrom(dictionary: [String: Any]) -> OpeningHours? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            let decoder = JSONDecoder()
            return try decoder.decode(OpeningHours.self, from: data)
        } catch {
            print("Failed to decode OpeningHoursData: \(error)")
            return nil
        }
    }
}

struct OpeningPeriod: Codable {
    let start: String?
    let end: String?
    let allDay: Bool?

    enum CodingKeys: String, CodingKey {
        case start, end
        case allDay = "all-day"
    }
}

struct ClosuerPeriod: Codable {
    let start: String
    let end: String
   
    enum CodingKeys: String, CodingKey {
        case start, end
    }
}

struct WeeklyOpening: Codable {
    let days: [String: DayOpening]
    let timezone: String
    enum CodingKeys: String, CodingKey {
        case timezone
    }
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

    struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return Int(stringValue) }
        init?(intValue: Int) { self.stringValue = "\(intValue)" }
    }
    
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

struct DayOpening: Codable {
    let hours: [OpeningPeriod]
    let isSpecial: Bool
}


struct OpeningStatus {
    public let isOpen: Bool
    public let nextOpening: String?
}

class OpeningHoursChecker {
    
    
    
    public static func check(openingHours: OpeningHours, validateFor:Date = Date()) -> OpeningStatus {
        
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
        
        guard let timeZone = TimeZone(identifier: openingHours.timezone) else {
            return OpeningStatus(isOpen: false, nextOpening: nil)
        }

        let now = validateFor
        var calendar = Calendar.current
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
        let todayKey = String(weekday == 1 ? 7 : weekday - 1) // 1=Monday, ..., 7=Sunday

//        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
//        let yesterdayString = dateFormatter.string(from: yesterday)
        let yesterdayKey = String((weekday == 2 ? 7 : weekday - 2 == 0 ? 7 : weekday - 2))

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
        if let usualToday = openingHours.usual[todayKey] {
            if let status = checkPeriods(usualToday, nowTime: nowTime, formatter: timeFormatter) {
                return status
            }
        }

        // 🟧 3. Check Yesterday for Overnight Hours
        if let usualYesterday = openingHours.usual[yesterdayKey] {
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
