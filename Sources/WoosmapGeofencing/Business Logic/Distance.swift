//
//  TrafficDistance.swift
//  WoosmapGeofencing
//
//

import Foundation
import RealmSwift
import CoreLocation

/// Distance Object
public class Distance: Object {
    
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

/// Distance Object
public class Distances {
    
    /// Create new distance object from JSON response
    /// - Parameters:
    ///   - APIResponse:
    ///   - locationId:
    ///   - origin:
    ///   - destination:
    ///   - distanceProvider:
    ///   - distanceMode:
    ///   - distanceUnits:
    ///   - distanceLanguage:
    ///   - trafficDistanceRouting:
    /// - Returns: Distance
    public class func addFromResponseJson(APIResponse: Data,
                                          locationId: String,
                                          origin: CLLocation,
                                          destination: [(Double, Double)],
                                          distanceProvider : DistanceProvider = distanceProvider,
                                          distanceMode: DistanceMode = distanceMode,
                                          distanceUnits: DistanceUnits = distanceUnits,
                                          distanceLanguage: String = distanceLanguage,
                                          trafficDistanceRouting: TrafficDistanceRouting = trafficDistanceRouting) -> [Distance] {
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
                        distance.routing = trafficDistanceRouting.rawValue
                        distance.mode = distanceMode.rawValue
                        distance.originLatitude = origin.coordinate.latitude
                        distance.originLongitude = origin.coordinate.longitude
                        let dest = destination[indexElement]
                        distance.destinationLatitude = dest.0
                        distance.destinationLongitude = dest.1
                        let distanceValue = element.distance?.value
                        let distanceText = element.distance?.text
                        var durationValue = 0
                        var durationText = ""
                        if(distanceProvider == DistanceProvider.woosmapTraffic) {
                            durationValue = element.duration_with_traffic?.value ?? 0
                            durationText = element.duration_with_traffic?.text ?? ""
                        } else {
                            durationValue = element.duration?.value ?? 0
                            durationText = element.duration?.text ?? ""
                        }
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
            return distanceArray
            
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
            let distances = realm.objects(Distance.self)
            return Array(distances)
        } catch {
        }
        return []
    }
    
    /// Delete all 
    public class func deleteAll() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(Distance.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
