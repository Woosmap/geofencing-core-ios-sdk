//
//  TrafficDistance.swift
//  WoosmapGeofencing
//
//

import Foundation
@_implementationOnly import RealmSwift
import CoreLocation

/// Distance Object
class DistanceModel: Object {
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// origin Latitude
    @objc public dynamic var originLatitude: Double = 0.0
    
    /// origin Longitude
    @objc public dynamic var originLongitude: Double = 0.0
    
    /// Destination Latitude
    @objc public dynamic var destinationLatitude: Double = 0.0
    
    /// Destination Longitude
    @objc public dynamic var destinationLongitude: Double = 0.0
    
    /// Distance
    @objc public dynamic var distance: Int = 0
    
    /// Distance Text
    @objc public dynamic var distanceText: String?
    
    /// Duration
    @objc public dynamic var duration: Int = 0
    
    /// Duration Text
    @objc public dynamic var durationText: String?
    
    /// mode
    @objc public dynamic var mode: String?
    
    /// Units
    @objc public dynamic var units: String?
    
    /// Routing
    @objc public dynamic var routing: String?
    
    /// Status
    @objc public dynamic var status: String?
    
    /// Location Id
    @objc public dynamic var locationId: String?
    
    
    /// Create new distance object
    /// - Parameters:
    ///   - originLatitude:
    ///   - originLongitude:
    ///   - destinationLatitude:
    ///   - destinationLongitude:
    ///   - dateCaptured:
    ///   - distance:
    ///   - duration:
    ///   - mode:
    ///   - units:
    ///   - routing:
    ///   - status:
    ///   - locationId:
    convenience public init(originLatitude: Double,
                            originLongitude: Double,
                            destinationLatitude: Double,
                            destinationLongitude: Double,
                            dateCaptured: Date,
                            distance: Int,
                            duration: Int,
                            mode: String,
                            units: String,
                            routing: String,
                            status: String,
                            locationId: String) {
        self.init()
        self.originLatitude = originLatitude
        self.originLongitude = originLongitude
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.date = dateCaptured
        self.distance = distance
        self.duration = duration
        self.mode = mode
        self.units = units
        self.routing = routing
        self.status = status
        self.locationId = locationId
    }
    
}

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
    
    fileprivate init(distanceModel: DistanceModel) {
        self.date = distanceModel.date
        self.originLatitude = distanceModel.originLatitude
        self.originLongitude = distanceModel.originLongitude
        self.destinationLatitude = distanceModel.destinationLatitude
        self.destinationLongitude = distanceModel.destinationLongitude
        self.distance = distanceModel.distance
        self.distanceText = distanceModel.distanceText
        self.duration = distanceModel.duration
        self.durationText = distanceModel.durationText
        self.mode = distanceModel.mode
        self.units = distanceModel.units
        self.routing = distanceModel.routing
        self.status = distanceModel.status
        self.locationId = distanceModel.locationId
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
            var distanceArray: [DistanceModel] = []
            let jsonStructure = try JSONDecoder().decode(DistanceAPIData.self, from: APIResponse)
            if jsonStructure.status == "OK" {
                for row in jsonStructure.rows! {
                    var indexElement = 0
                    for element in row.elements! {
                        let distance = DistanceModel()
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
                        distance.distance = distanceValue ?? 0
                        distance.distanceText = distanceText
                        distance.duration = durationValue
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
            
            let realm = try Realm()
            realm.beginWrite()
            realm.add(distanceArray)
            try realm.commitWrite()
            return toDistance(distanceModels: distanceArray)
            
        } catch let error as NSError {
            print(error)
        }
        
        return []
    }
    
    
    /// Get all distance object
    /// - Returns: return all distance
    public class func getAll() -> [Distance] {
        do {
            let realm = try Realm()
            let distances = realm.objects(DistanceModel.self)
            return toDistance(distanceModels: Array(distances))
        } catch {
        }
        return []
    }
    
    /// Delete all 
    public class func deleteAll() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(DistanceModel.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}


private func toDistance(distanceModels: [DistanceModel]) -> [Distance] {
    var distances : [Distance] = []
    for distanceModel in distanceModels {
        distances.append(Distance(distanceModel:distanceModel))
    }
    return distances
}
