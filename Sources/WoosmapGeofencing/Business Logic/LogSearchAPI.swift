//
//  LogSearchAPI.swift
//  WoosmapGeofencing
//

import Foundation
import CoreLocation
import os
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
            //Save in Core DB
            let newRec:LogSearchAPIDB = LogSearchAPIDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
            newRec.date = log.date
            newRec.latitude = log.latitude
            newRec.longitude = log.longitude
            newRec.lastSearchLocationLatitude = log.lastSearchLocationLatitude
            newRec.lastSearchLocationLongitude = log.lastSearchLocationLongitude
            newRec.lastPOI_distance = log.lastPOI_distance
            newRec.distanceLimit = log.distanceLimit
            newRec.locationDescription = log.locationDescription
            newRec.distanceTraveled = log.distanceTraveled
            newRec.distanceToFurthestMonitoredPOI = log.distanceToFurthestMonitoredPOI
            newRec.distanceTraveledLastRefreshPOIRegion = log.distanceTraveledLastRefreshPOIRegion
            newRec.searchAPILastRequestTimeStampValue = log.searchAPILastRequestTimeStampValue
            newRec.sendSearchAPIRequest = log.sendSearchAPIRequest
            newRec.woosmapAPIKey = log.woosmapAPIKey
            newRec.searchAPIRequestEnable = log.searchAPIRequestEnable
            let _ = try WoosmapDataManager.connect.save(entity: newRec)
            
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
    }
    
    
}
