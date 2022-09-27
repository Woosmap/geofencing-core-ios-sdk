//
//  Location.swift
//  WoosmapGeofencing
//

import Foundation
import RealmSwift
import CoreLocation

/// Location Object
public class Location: Object {
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Description
    @objc public dynamic var locationDescription: String?
    
    /// ID
    @objc public dynamic var locationId: String?
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    /// Create new Location object
    /// - Parameters:
    ///   - locationId:
    ///   - latitude:
    ///   - longitude:
    ///   - dateCaptured:
    ///   - descriptionToSave:
    convenience public init(locationId: String, latitude: Double, longitude: Double, dateCaptured: Date, descriptionToSave: String) {
        self.init()
        self.locationId = locationId
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.locationDescription = descriptionToSave
    }
    
}

/// Location business object
public class Locations {
    
    /// Create new location form CLLocation
    /// - Parameter locations: CLLocation
    /// - Returns: Locations
    public class func add(locations: [CLLocation]) -> Location {
        do {
            let realm = try Realm()
            let location = locations.last!
            // create Location ID
            let locationId = UUID().uuidString
            let entry = Location(locationId: locationId, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, dateCaptured: Date(), descriptionToSave: "description")
            realm.beginWrite()
            realm.add(entry)
            try realm.commitWrite()
            return entry
        } catch {
        }
        return Location()
    }
    
    /// Test Location
    /// - Parameter location: Location
    public class func addTest(location: Location) {
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.add(location)
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// List all saved locations
    /// - Returns: Locations
    public class func getAll() -> [Location] {
        do {
            let realm = try Realm()
            let locations = realm.objects(Location.self)
            return Array(locations)
        } catch {
        }
        return []
    }
    
    /// Get Location From Id
    /// - Parameter locationId: ID
    /// - Returns: Location
    @available(*, deprecated, message: "Use getLocationFromId:id instead")
    private class func getLocationByLocationID(locationId: String) -> Location? {
        do {
            let realm = try Realm()
            let predicate = NSPredicate(format: "locationId == %@", locationId)
            let fetchedResults = realm.objects(Location.self).filter(predicate)
            if let aLocation = fetchedResults.first {
                return aLocation
            }
        } catch {
        }
        return nil
    }
    
    /// Get Location From Id
    /// - Parameter id: ID
    /// - Returns: Location
    public class func getLocationFromId(id: String) -> Location? {
        do {
            let realm = try Realm()
            let predicate = NSPredicate(format: "locationId == %@", id)
            let fetchedResults = realm.objects(Location.self).filter(predicate)
            if let aLocation = fetchedResults.last {
                return aLocation
            }
        } catch {
        }
        return nil
    }
    
    /// Delete all locatons
    public class func deleteAll() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(Location.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
