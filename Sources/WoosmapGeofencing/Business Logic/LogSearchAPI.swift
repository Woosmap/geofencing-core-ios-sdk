//
//  LogSearchAPI.swift
//  WoosmapGeofencing
//

import Foundation
import RealmSwift
import CoreLocation

/// Log Search API
public class LogSearchAPI: Object {
    
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
}

/// Object : LogSearchAPIs
public class LogSearchAPIs {
    
    /// Add new log in DB
    /// - Parameter log: Log
    public class func add(log: LogSearchAPI) {
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.add(log)
            try realm.commitWrite()
        } catch {
        }
    }
    
    
}
