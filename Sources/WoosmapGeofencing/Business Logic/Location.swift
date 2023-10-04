//
//  Location.swift
//  WoosmapGeofencing
//

import Foundation
import CoreLocation
import os
/// Location object
public class Location  {
    /// Date
    public var date: Date? = nil
    
    /// Latitude
    public var latitude: Double = 0.0
    
    /// Description
    public var locationDescription: String?
    
    /// ID
    public var locationId: String? = nil
    
    /// Longitude
    public var longitude: Double = 0.0

    public init() {
        
    }
    
    public convenience init(locationId: String, latitude: Double, longitude: Double, dateCaptured: Date, descriptionToSave: String) {
        self.init()
        self.locationId = locationId
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.locationDescription = descriptionToSave
    }
    
    fileprivate init(locationDB: LocationDB) {
        self.date = locationDB.date
        self.latitude = locationDB.latitude
        self.locationDescription = locationDB.locationDescription
        self.locationId = locationDB.locationId
        self.longitude = locationDB.longitude
    }
    
    fileprivate func dbEntity() -> LocationDB {
        let newRec:LocationDB = LocationDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
        newRec.date = self.date
        newRec.latitude = self.latitude
        newRec.locationDescription = self.locationDescription
        newRec.locationId = self.locationId
        newRec.longitude = self.longitude
        return newRec
    }
}

/// Location business object
public class Locations {
    
    /// Create new location form CLLocation
    /// - Parameter locations: CLLocation
    /// - Returns: Locations
    public class func add(locations: [CLLocation]) -> Location {
        do {
            
            let location = locations.last!
            // create Location ID
            let locationId = UUID().uuidString
            
            let entry = Location(locationId: locationId, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, dateCaptured: Date(), descriptionToSave: "description")
            //Save in Core DB
            let newRec:LocationDB = entry.dbEntity()
            let _ = try WoosmapDataManager.connect.save(entity: newRec)
            return Location(locationDB: newRec)
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
        return Location()
    }
    
    /// Test Location
    /// - Parameter location: Location
    public class func addTest(location: Location) {
        
        guard let locationId = location.locationId else {
            return
        }
        
        guard let date = location.date else {
            return
        }
        
        guard let description = location.locationDescription else {
            return
        }
        
        let locationModel = Location(locationId: locationId, latitude: location.latitude, longitude: location.longitude, dateCaptured: date, descriptionToSave: description)
        do {
            //Save in Core DB
            let newRec:LocationDB = locationModel.dbEntity()
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
    
    /// List all saved locations
    /// - Returns: Locations
    public class func getAll() -> [Location] {
        do {
            //Core DB
            let locations = try WoosmapDataManager.connect.retrieve(entityClass: LocationDB.self)
            return Array((locations).map({ location in
                return Location(locationDB: location)
            }))
            
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
        return []
    }
    
    /// Get Location From Id
    /// - Parameter locationId: ID
    /// - Returns: Location
    @available(*, deprecated, message: "Use getLocationFromId:id instead")
    private class func getLocationByLocationID(locationId: String) -> Location? {
        do {
            let predicate = NSPredicate(format: "locationId == %@", locationId)
            //Core DB
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: LocationDB.self, predicate: predicate)
            if let aLocation = fetchedResults.last {
                return Location(locationDB: aLocation)
            }
            
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
        return nil
    }
    
    /// Get Location From Id
    /// - Parameter id: ID
    /// - Returns: Location
    public class func getLocationFromId(id: String) -> Location? {
        do {

            let predicate = NSPredicate(format: "locationId == %@", id)
            //Core DB
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: LocationDB.self, predicate: predicate)
            if let aLocation = fetchedResults.last {
                return Location(locationDB: aLocation)
            }
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
        return nil
    }
    
    /// Delete all locatons
    public class func deleteAll() {
        do {
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: LocationDB.self)
        } catch let error as NSError {
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
