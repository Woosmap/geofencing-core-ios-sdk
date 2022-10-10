//
//  Visit.swift
//  WoosmapGeofencing

import RealmSwift
import Foundation
import CoreLocation

/// Visit Object
public class Visit: Object {
    
    /// Accuracy
    @objc public dynamic var accuracy: Double = 0.0
    
    /// Arrival Date
    @objc public dynamic var arrivalDate: Date?
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// Departure Date
    @objc public dynamic var departureDate: Date?
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    /// ID
    @objc public dynamic var visitId: String?
    
    /// New Visit object
    /// - Parameters:
    ///   - visitId:
    ///   - arrivalDate:
    ///   - departureDate:
    ///   - latitude:
    ///   - longitude:
    ///   - dateCaptured:
    ///   - accuracy:
    convenience public init(visitId: String, arrivalDate: Date? = nil, departureDate: Date? = nil, latitude: Double, longitude: Double, dateCaptured: Date? = nil, accuracy: Double) {
        self.init()
        self.visitId = visitId
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.accuracy = accuracy
    }
    
}

/// Visit Business object
public class Visits {
    
    /// Add new Visit informatin
    /// - Parameter visit: CLVisit
    /// - Returns: Visit
    public class func add(visit: CLVisit) -> Visit {
        do {
            let realm = try Realm()
            let calendar = Calendar.current
            let departureDate = calendar.component(.year, from: visit.departureDate) != 4001 ? visit.departureDate : nil
            let arrivalDate = calendar.component(.year, from: visit.arrivalDate) != 4001 ? visit.arrivalDate : nil
            if arrivalDate != nil && departureDate != nil {
                let entry = Visit(visitId: UUID().uuidString, arrivalDate: arrivalDate, departureDate: departureDate, latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude, dateCaptured: Date(), accuracy: visit.horizontalAccuracy)
                realm.beginWrite()
                realm.add(entry)
                try realm.commitWrite()
                if creationOfZOIEnable {
                    ZOIs.createZOIFromVisit(visit: entry)
                }
                return entry
            }
        } catch {
        }
        return Visit()
    }
    
    /// Add test visit information
    /// - Parameter visit: Visit
    public class func addTest(visit: Visit) {
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.add(visit)
            try realm.commitWrite()
        } catch {
        }
        ZOIs.createZOIFromVisit(visit: visit)
    }
    
    /// Get All visit information
    /// - Returns: List
    public class func getAll() -> [Visit] {
        do {
            let realm = try Realm()
            let visits = realm.objects(Visit.self)
            return Array(visits)
        } catch {
        }
        return []
    }
    
    /// Get Visit information by ID
    /// - Parameter id: ID
    /// - Returns: Visit
    public class func getVisitFromUUID(id: String) -> Visit? {
        do {
            let realm = try Realm()
            let predicate = NSPredicate(format: "visitId == %@", id)
            let fetchedResults = realm.objects(Visit.self).filter(predicate)
            if let aVisit = fetchedResults.first {
                return aVisit
            }
        } catch {
        }
        return nil
    }
    
    /// Delete All visit information
    public class func deleteAll() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(Visit.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
