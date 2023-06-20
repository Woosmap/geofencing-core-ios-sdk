//
//  LogSearchAPI.swift
//  WoosmapGeofencing
//

import Foundation
@_implementationOnly import RealmSwift
import CoreLocation

/// Log Search API
class LogSearchAPIModel: Object {
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    /// last Search Location Latitude
    @objc public dynamic var lastSearchLocationLatitude: Double = 0.0
    
    /// last Search Location Longitude
    @objc public dynamic var lastSearchLocationLongitude: Double = 0.0
    
    /// last POI distance
    @objc public dynamic var lastPOI_distance: String?
    
    /// distance Limit
    @objc public dynamic var distanceLimit: String?
    
    /// location Description
    @objc public dynamic var locationDescription: String?
    
    /// distance Traveled
    @objc public dynamic var distanceTraveled: String?
    
    /// distance To Furthest Monitored POI
    @objc public dynamic var distanceToFurthestMonitoredPOI: String?
    
    /// distance Traveled Last Refresh POI Region
    @objc public dynamic var distanceTraveledLastRefreshPOIRegion: String?
    
    /// search API Last Request TimeStamp Value
    @objc public dynamic var searchAPILastRequestTimeStampValue = 0.0
    
    /// send Search API Request
    @objc public dynamic var sendSearchAPIRequest: Bool = false
    
    /// Woosmap API Key
    @objc public dynamic var woosmapAPIKey: String?
    
    /// Search API Request Enable
    @objc public dynamic var searchAPIRequestEnable: Bool = false
    
    override init() {
        
    }
    
    init(logSearchApi: LogSearchAPI) {
        self.date = logSearchApi.date
        self.latitude = logSearchApi.latitude
        self.longitude = logSearchApi.longitude
        self.lastSearchLocationLatitude = logSearchApi.lastSearchLocationLatitude
        self.lastSearchLocationLongitude = logSearchApi.lastSearchLocationLongitude
        self.lastPOI_distance = logSearchApi.lastPOI_distance
        self.distanceLimit = logSearchApi.distanceLimit
        self.locationDescription = logSearchApi.locationDescription
        self.distanceTraveled = logSearchApi.distanceTraveled
        self.distanceToFurthestMonitoredPOI = logSearchApi.distanceToFurthestMonitoredPOI
        self.distanceTraveledLastRefreshPOIRegion = logSearchApi.distanceTraveledLastRefreshPOIRegion
        self.searchAPILastRequestTimeStampValue = logSearchApi.searchAPILastRequestTimeStampValue
        self.sendSearchAPIRequest = logSearchApi.sendSearchAPIRequest
        self.woosmapAPIKey = logSearchApi.woosmapAPIKey
        self.searchAPIRequestEnable = logSearchApi.searchAPIRequestEnable
    }
}


public class LogSearchAPI {
    /// Date
     var date: Date?
    
    /// Latitude
     var latitude: Double = 0.0
    
    /// Longitude
    var longitude: Double = 0.0
    
    /// last Search Location Latitude
    var lastSearchLocationLatitude: Double = 0.0
    
    /// last Search Location Longitude
    var lastSearchLocationLongitude: Double = 0.0
    
    /// last POI distance
    var lastPOI_distance: String?
    
    /// distance Limit
    var distanceLimit: String?
    
    /// location Description
    var locationDescription: String?
    
    /// distance Traveled
    var distanceTraveled: String?
    
    /// distance To Furthest Monitored POI
    var distanceToFurthestMonitoredPOI: String?
    
    /// distance Traveled Last Refresh POI Region
    var distanceTraveledLastRefreshPOIRegion: String?
    
    /// search API Last Request TimeStamp Value
    var searchAPILastRequestTimeStampValue = 0.0
    
    /// send Search API Request
    var sendSearchAPIRequest: Bool = false
    
    /// Woosmap API Key
    var woosmapAPIKey: String?
    
    /// Search API Request Enable
    var searchAPIRequestEnable: Bool = false
}

/// Object : LogSearchAPIs
public class LogSearchAPIs {
    
    /// Add new log in DB
    /// - Parameter log: Log
    public class func add(log: LogSearchAPI) {
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.add(LogSearchAPIModel(logSearchApi: log))
            try realm.commitWrite()
        } catch {
        }
    }
    
    
}
