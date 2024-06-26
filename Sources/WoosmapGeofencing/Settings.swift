//
//  settings.swift
//  WoosmapGeofencing
//
//

import Foundation
import os

// Tracking
public var trackingEnable = false

// Woosmap SearchAPI Key
private var _WoosmapAPIKey: String = ""
public var WoosmapAPIKey: String {
    get{
        return _WoosmapAPIKey
    }
    set {
        if _WoosmapAPIKey != newValue {
            if(WoosLog.isValidLevel(level: .info)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.info("\(LogEvent.i.rawValue) Woosmap API: \(newValue, privacy: .private)")
                } else {
                    WoosLog.info("Woosmap API: \(newValue)")
                }
            }
        }
        _WoosmapAPIKey = newValue
    }
}

public var searchWoosmapAPI = "https://api.woosmap.com/stores/search/?private_key=\(WoosmapAPIKey)&lat=%@&lng=%@&stores_by_page=5"

// Woosmap Distance provider
@available(*, deprecated, message: "This feature was disabled; use the distanceWithTraffic flag")
public enum DistanceProvider: String {
  case woosmapTraffic
  case woosmapDistance
}
public var distanceWithTraffic:Bool = false

// Woosmap Distance mode
public enum DistanceMode: String {
  case driving
  case cycling
  case walking
  case truck
}

public var distanceMode = DistanceMode.driving // cycling,walking

//public var distanceWoosmapAPI = "https://api.woosmap.com/distance/distancematrix/json?mode=%@&units=%@&language=%@&origins=%@,%@&destinations=%@&private_key=\(WoosmapAPIKey)&elements=duration_distance"

public var distanceWoosmapAPI = "https://api.woosmap.com/distance/distancematrix/json"

@available(*, deprecated, message: "This feature was disabled; use the DistanceMethod")
public enum TrafficDistanceRouting: String {
  case fastest
  case balanced
}

public enum DistanceMethod: String {
  case time
  case distance
}


public enum DistanceUnits: String {
  case metric
  case imperial
}

public var distanceMethod = DistanceMethod.time


public var distanceUnits = DistanceUnits.metric
public var distanceLanguage = "en"

//Distance filters
public var distanceMaxAirDistanceFilter = 1000000
public var distanceTimeFilter = 0

// Location filters
public var currentLocationDistanceFilter = 0.0
public var currentLocationTimeFilter = 0
public var modeHighfrequencyLocation = false

// Search API filters
public var searchAPIRequestEnable = false
public var searchAPIDistanceFilter = 0.0
public var searchAPITimeFilter = 0
public var searchAPIRefreshDelayDay = 1
public var searchAPICreationRegionEnable = false
public var searchAPILastRequestTimeStamp = 0.0

// Distance API filters
public var distanceAPIRequestEnable = false

// Active visit
public var visitEnable = false
public var accuracyVisitFilter = 50.0

// Active creation of ZOI
public var creationOfZOIEnable = false

// Active Classification
public var classificationEnable = false
public var radiusDetectionClassifiedZOI = 100.0

// Delay of Duration data
public var dataDurationDelay = 30// number of day

// delay for obsolote notification
public var outOfTimeDelay = 300

// Google Map Static Key
public var GoogleStaticMapKey = ""

// Google Map static API
public let GoogleMapStaticAPIBaseURL = "http://maps.google.com/maps/api/staticmap"
public let GoogleMapStaticAPIOneMark = GoogleMapStaticAPIBaseURL + "?markers=color:blue|%@,%@&zoom=15&size=400x400&sensor=true&key=\(GoogleStaticMapKey)"
public let GoogleMapStaticAPITwoMark = GoogleMapStaticAPIBaseURL + "?markers=color:red|%@,%@&markers=color:blue|%@,%@&zoom=14&size=400x400&sensor=true&key=\(GoogleStaticMapKey)"

// Parameter for SearchAPI request
public var searchAPIParameters : [String: String] = [:]

// filter for user_properties data
public var userPropertiesFilter : [String] = []

public var poiRadius:Any = "radius"

/// Enum which maps an appropiate symbol which added as prefix for each log message
public enum WosmapLogEvent: Int {
    case none = 0
    case error = 1 // error
    case warn = 2// warn
    case info = 3// info
    case debug = 4 // debug
    case trace = 5 // trace
}


internal var logLevelSDK:WosmapLogEvent = WosmapLogEvent.info
