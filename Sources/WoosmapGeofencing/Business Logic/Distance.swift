//
//  TrafficDistance.swift
//  WoosmapGeofencing
//
//

import Foundation
import CoreLocation
/// Distance object
public class Distance {
    /// Date
    var date: Date?
    
    /// origin Latitude
    var originLatitude: Double = 0.0
    
    /// origin Longitude
    var originLongitude: Double = 0.0
    
    /// Destination Latitude
    var destinationLatitude: Double = 0.0
    
    /// Destination Longitude
    var destinationLongitude: Double = 0.0
    
    /// Distance
    var distance: Int = 0
    
    /// Distance Text
    var distanceText: String?
    
    /// Duration
    var duration: Int = 0
    
    /// Duration Text
    var durationText: String?
    
    /// mode
    var mode: String?
    
    /// Units
    var units: String?
    
    /// Routing
    var routing: String?
    
    /// Status
    var status: String?
    
    /// Location Id
    var locationId: String?
    
    convenience fileprivate init(distanceDB: DistanceDB) {
        self.init()
        self.date = distanceDB.date
        self.originLatitude = distanceDB.originLatitude
        self.originLongitude = distanceDB.originLongitude
        self.destinationLatitude = distanceDB.destinationLatitude
        self.destinationLongitude = distanceDB.destinationLongitude
        self.distance = Int(distanceDB.distance)
        self.distanceText = distanceDB.distanceText
        self.duration = Int(distanceDB.duration)
        self.durationText = distanceDB.durationText
        self.mode = distanceDB.mode
        self.units = distanceDB.units
        self.routing = distanceDB.routing
        self.status = distanceDB.status
        self.locationId = distanceDB.locationId
    }
    
    fileprivate func dbEntity() -> DistanceDB {
        let newRec:DistanceDB = DistanceDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
        newRec.date = self.date
        newRec.originLatitude = self.originLatitude
        newRec.originLongitude = self.originLongitude
        newRec.destinationLatitude = self.destinationLatitude
        newRec.destinationLongitude = self.destinationLongitude
        newRec.distance = Int32(self.distance)
        newRec.distanceText = self.distanceText
        newRec.duration = Int32(self.duration)
        newRec.durationText = self.durationText
        newRec.mode = self.mode
        newRec.units = self.units
        newRec.routing = self.routing
        newRec.status = self.status
        newRec.locationId = self.locationId
        return newRec
    }
}

/// Distance Object
public class Distances {
    
    /// Create new distance object from JSON response
    /// - Parameters:
    ///   - APIResponse:
    ///   - locationId:
    ///   - origin:
    ///   - destination:
    ///   - distanceMode:
    ///   - distanceUnits:
    ///   - distanceLanguage:
    ///   - distanceMethod:
    /// - Returns: Distance
    public class func addFromResponseJson(APIResponse: Data,
                                          locationId: String,
                                          origin: CLLocation,
                                          destination: [(Double, Double)],
                                          distanceMode: DistanceMode = distanceMode,
                                          distanceUnits: DistanceUnits = distanceUnits,
                                          distanceLanguage: String = distanceLanguage,
                                          distanceMethod: DistanceMethod = distanceMethod) -> [Distance] {
        do {
            var distanceArray: [Distance] = []
            let jsonStructure = try JSONDecoder().decode(DistanceAPIData.self, from: APIResponse)
            if jsonStructure.status == "OK" {
                for row in jsonStructure.rows! {
                    var indexElement = 0
                    for element in row.elements! {
                        let distance = Distance()
                        distance.units = distanceUnits.rawValue
                        distance.date = Date()
                        distance.routing = distanceMethod.rawValue
                        distance.mode = distanceMode.rawValue
                        distance.originLatitude = origin.coordinate.latitude
                        distance.originLongitude = origin.coordinate.longitude
                        let dest = destination[indexElement]
                        distance.destinationLatitude = dest.0
                        distance.destinationLongitude = dest.1
                        let distanceValue = element.distance?.value
                        let distanceText = element.distance?.text
                        let durationValue = element.duration?.value ?? 0
                        let durationText = element.duration?.text ?? ""
                        distance.distance = Int(distanceValue ?? 0)
                        distance.distanceText = distanceText
                        distance.duration = Int(durationValue)
                        distance.durationText = durationText
                        distance.status = element.status
                        distance.locationId = locationId
                        distanceArray.append(distance)
                        indexElement+=1
                    }
                }
            } else {
                print("WoosmapGeofencing.DistanceAPIData " + jsonStructure.status!)
            }
            
//            let realm = try Realm()
//            realm.beginWrite()
//            realm.add(distanceArray)
//            try realm.commitWrite()
            try distanceArray.forEach { row in
                let _ = try WoosmapDataManager.connect.save(entity: row.dbEntity())
            }
            
            return distanceArray
            
        } catch let error as NSError {
            print(error)
        }
        
        return []
    }
    
    
    /// Get all distance object
    /// - Returns: return all distance
    private class func getAll() -> [Distance] {
        do {
//            let realm = try Realm()
//            let distances = realm.objects(DistanceModel.self)
//            return Distances.toDistance(distanceModels: Array(distances))
            
            let distances = try WoosmapDataManager.connect.retrieve(entityClass: DistanceDB.self)
            return Array((distances).map({ distance in
                return Distance(distanceDB: distance)
            }))
            
        } catch {
        }
        return []
    }
    
    /// Delete all 
    private class func deleteAll() {
        do {
//            let realm = try Realm()
//            try realm.write {
//                realm.delete(realm.objects(DistanceModel.self))
//            }
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: DistanceDB.self)
        } catch let error as NSError {
            print(error)
        }
    }
}



