//
//  Visit.swift
//  WoosmapGeofencing
import Foundation
import CoreLocation
public class Visit {
    
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
    
    convenience  init(visitDB: VisitDB) {
        self.init()
        self.visitId = visitDB.visitId
        self.arrivalDate = visitDB.arrivalDate
        self.departureDate = visitDB.departureDate
        self.latitude = visitDB.latitude
        self.longitude = visitDB.longitude
        self.date = visitDB.date
        self.accuracy = visitDB.accuracy
    }
}


/// Visit Business object
public class Visits {
    
    /// Add new Visit informatin
    /// - Parameter visit: CLVisit
    /// - Returns: Visit
    public class func add(visit: CLVisit) -> Visit {
        do {
            let calendar = Calendar.current
            let departureDate = calendar.component(.year, from: visit.departureDate) != 4001 ? visit.departureDate : nil
            let arrivalDate = calendar.component(.year, from: visit.arrivalDate) != 4001 ? visit.arrivalDate : nil
            if arrivalDate != nil && departureDate != nil {
                
                
            let entry = VisitDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
                
                //Visit(visitId: UUID().uuidString, arrivalDate: arrivalDate, departureDate: departureDate, latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude, dateCaptured: Date(), accuracy: visit.horizontalAccuracy)
                
                entry.visitId = UUID().uuidString
                entry.arrivalDate = arrivalDate
                entry.departureDate = departureDate
                entry.latitude = visit.coordinate.latitude
                entry.longitude = visit.coordinate.longitude
                entry.date = Date()
                entry.accuracy = visit.horizontalAccuracy
                let _ = try WoosmapDataManager.connect.save(entity: entry)
                
//                let realm = try Realm()
//                realm.beginWrite()
//                realm.add(VisitModel(visit: entry))
//                try realm.commitWrite()
                let newRec = Visit(visitDB: entry)
                if creationOfZOIEnable {
                    ZOIs.createZOIFromVisit(visit: newRec)
                }
                return newRec
            }
        } catch {
        }
        return Visit()
    }
    
    /// Add test visit information
    /// - Parameter visit: Visit
    public class func addTest(visit: Visit) {
        do {
            let entry = VisitDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
            entry.visitId = visit.visitId
            entry.arrivalDate = visit.arrivalDate
            entry.departureDate = visit.departureDate
            entry.latitude = visit.latitude
            entry.longitude = visit.longitude
            entry.date = visit.date
            entry.accuracy = visit.accuracy
            let _ = try WoosmapDataManager.connect.save(entity: entry)
//            let realm = try Realm()
//            realm.beginWrite()
//            realm.add(VisitModel(visit: visit))
//            try realm.commitWrite()
            
        } catch {
        }
        ZOIs.createZOIFromVisit(visit: visit)
    }
    
    /// Get All visit information
    /// - Returns: List
    public class func getAll() -> [Visit] {
        
        do {
            let visits = try WoosmapDataManager.connect.retrieve(entityClass: VisitDB.self)
            return Array((visits).map({ visit in
                return Visit(visitDB: visit)
            }))
        } catch {
        }
        return []
    }
    
    /// Get Visit information by ID
    /// - Parameter id: ID
    /// - Returns: Visit
    public class func getVisitFromUUID(id: String) -> Visit? {
        do {
            
            let predicate = NSPredicate(format: "visitId == %@", id)
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: VisitDB.self, predicate: predicate)
            if let aVisit = fetchedResults.first {
                return Visit(visitDB: aVisit)
            }
//            let realm = try Realm()
//            let predicate = NSPredicate(format: "visitId == %@", id)
//            let fetchedResults = realm.objects(VisitModel.self).filter(predicate)
//            if let aVisit = fetchedResults.first {
//                return Visit(visitModel: aVisit)
//            }
        } catch {
        }
        return nil
    }
    
    /// Delete All visit information
    public class func deleteAll() {
        do {
//            let realm = try Realm()
//            try realm.write {
//                realm.delete(realm.objects(VisitModel.self))
//            }
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: VisitDB.self)
        } catch let error as NSError {
            print(error)
        }
    }
}
