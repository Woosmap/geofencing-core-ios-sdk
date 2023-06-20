//
//  Location.swift
//  WoosmapGeofencing
//

import Foundation
@_implementationOnly import RealmSwift
import CoreLocation

/// Location Object
class LocationModel: Object {
    
    /// Date
    @objc public dynamic var date: Date? = nil
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Description
    @objc public dynamic var locationDescription: String?
    
    /// ID
    @objc public dynamic var locationId: String? = nil
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    public override init() {
        
    }
    
    /// Create new Location object
    /// - Parameters:
    ///   - locationId:
    ///   - latitude:
    ///   - longitude:
    ///   - dateCaptured:
    ///   - descriptionToSave:
    public init(locationId: String, latitude: Double, longitude: Double, dateCaptured: Date, descriptionToSave: String) {
        self.locationId = locationId
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.locationDescription = descriptionToSave
    }
    
}

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

    fileprivate init(locationModel: LocationModel) {
        self.date = locationModel.date
        self.latitude = locationModel.latitude
        self.locationDescription = locationModel.locationDescription
        self.locationId = locationModel.locationId
        self.longitude = locationModel.longitude
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
            let entry = LocationModel(locationId: locationId, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, dateCaptured: Date(), descriptionToSave: "description")
            realm.beginWrite()
            realm.add(entry)
            try realm.commitWrite()
            return Location(locationModel: entry)
        } catch {
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
        
        let locationModel = LocationModel(locationId: locationId, latitude: location.latitude, longitude: location.longitude, dateCaptured: date, descriptionToSave: description)
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.add(locationModel)
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// List all saved locations
    /// - Returns: Locations
    public class func getAll() -> [Location] {
        do {
            let realm = try Realm()
            let locations = realm.objects(LocationModel.self)
            return Array(locations).map { location in
                return Location(locationModel: location)
            }
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
            let fetchedResults = realm.objects(LocationModel.self).filter(predicate)
            if let aLocation = fetchedResults.first {
                return Location(locationModel: aLocation)
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
            let fetchedResults = realm.objects(LocationModel.self).filter(predicate)
            if let aLocation = fetchedResults.last {
                return Location(locationModel: aLocation)
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
                realm.delete(realm.objects(LocationModel.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
