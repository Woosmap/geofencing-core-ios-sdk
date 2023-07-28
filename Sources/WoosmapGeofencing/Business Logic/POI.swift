//
//  POI.swift
//  WoosmapGeofencing
//
import Foundation

public class POI {
    
    /// JSON Data
    public var jsonData: Data?
    
    /// City
    public var city: String?
    
    /// Store ID
    public var idstore: String?
    
    /// Name
    public var name: String?
    
    /// Date
    public var date: Date?
    
    /// Distance
    public var distance: Double = 0.0
    
    /// Duration
    public var duration: String?
    
    /// Latitude
    public var latitude: Double = 0.0
    
    /// Location ID
    public var locationId: String?
    
    /// Longitude
    public var longitude: Double = 0.0
    
    /// Zip Code
    public var zipCode: String?
    
    /// Radius
    public var radius: Double = 0.0
    
    /// Address
    public var address: String?
    
    /// Open Now
    public var openNow: Bool = false
    
    /// Country Code
    public var countryCode: String?
    
    /// Tags
    public var tags: String?
    
    /// Types
    public var types: String?
    
    /// Contact
    public var contact: String?
    
    
    /// Create new entry in POI object
    /// - Parameters:
    ///   - locationId:
    ///   - city:
    ///   - zipCode:
    ///   - distance:
    ///   - latitude:
    ///   - longitude:
    ///   - dateCaptured:
    ///   - radius:
    ///   - address:
    ///   - tags:
    ///   - types:
    ///   - countryCode:
    ///   - contact:
    convenience public init(locationId: String? = nil, city: String? = nil, zipCode: String? = nil, distance: Double? = nil, latitude: Double? = nil, longitude: Double? = nil, dateCaptured: Date? = nil, radius: Double? = nil, address: String? = nil, tags: String? = nil, types: String? = nil, countryCode: String? = nil, contact: String? = nil) {
        self.init()
        self.locationId = locationId
        self.city = city
        self.zipCode = zipCode
        self.distance = distance!
        self.latitude = latitude!
        self.longitude = longitude!
        self.date = dateCaptured
        self.radius = radius!
        self.address = address
        self.countryCode = countryCode
        self.tags = tags
        self.types = types
        self.contact = contact
    }
    
    fileprivate convenience init(poiDB: POIDB) {
        self.init()
        self.locationId = poiDB.locationId
        self.city = poiDB.city
        self.zipCode = poiDB.zipCode
        self.distance = poiDB.distance
        self.duration = poiDB.duration
        self.latitude = poiDB.latitude
        self.longitude = poiDB.longitude
        self.date = poiDB.date
        self.radius = poiDB.radius
        self.address = poiDB.address
        self.countryCode = poiDB.countryCode
        self.tags = poiDB.tags
        self.types = poiDB.types
        self.contact = poiDB.contact
        self.jsonData = poiDB.jsonData
    }
}


/// POI business class
public class POIs {
    
    /// Capture JSON input and convert POI object
    /// - Parameters:
    ///   - searchAPIResponse: API response
    ///   - locationId: location
    /// - Returns: POI Object
    public class func addFromResponseJson(searchAPIResponse: Data, locationId: String) -> [POI] {
        do {
            let jsonStructure = try JSONDecoder().decode(JSONAny.self, from: searchAPIResponse)
            var aPOIs: [POIDB] = []
            if let value = jsonStructure.value as? [String: Any] {
                if let features = value["features"] as? [[String: Any]] {
                    for feature in features {
                        let poi = POIDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
                        poi.jsonData = searchAPIResponse
                        poi.locationId = locationId
                        poi.date = Date()
                        
                        if let properties = feature["properties"] as? [String: Any] {
                            poi.idstore = properties["store_id"] as? String ?? ""
                            poi.name = properties["name"] as? String ?? ""
                            poi.distance = properties["distance"] as? Double ?? 0.0
                            if let address = properties["address"] as? [String: Any] {
                                poi.city = address["city"] as? String ?? ""
                                poi.zipCode = address["zipcode"] as? String ?? ""
                                poi.countryCode = address["country_code"] as? String ?? ""
                                if let address = address["lines"] as? [String] {
                                    poi.address = address.joined(separator:" - ")
                                }
                            }
                            
                            if let open = properties["open"] as? [String: Any] {
                                poi.openNow = open["open_now"] as? Bool ?? false
                            }
                            
                            if let contact = properties["contact"] as? [String: String] {
                                for (key, value) in contact {
                                    poi.contact = (poi.contact ?? "") + key + "=" + value + "_"
                                }
                            } else {
                                poi.contact = "null"
                            }
                            
                            //Value by default
                            poi.radius = 300
                            
                            if let radius = poiRadius as? Double {
                                poi.radius = radius
                            } else if let radius = poiRadius as? Int {
                                poi.radius = Double(radius)
                            } else if let radius = poiRadius as? String{
                                if let userProperties = properties["user_properties"] as? [String: Any] {
                                    for (key, value) in userProperties {
                                        if(key == radius) {
                                            if let radius = value as? Int64 {
                                                poi.radius = Double(radius)
                                            } else if let radius = value as? String {
                                                poi.radius = Double(radius) ?? 300
                                            } else if let radius = value as? Double {
                                                poi.radius = radius
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if let tags = properties["tags"] as? [String] {
                                poi.tags = tags.joined(separator:" - ")
                            }
                            if let types = properties["types"] as? [String] {
                                poi.types = types.joined(separator:" - ")
                            }
                            
                        }
                        
                        if let geometry = feature["geometry"] as? [String: Any] {
                            let coord:Array<Double> = geometry["coordinates"] as! Array<Double>
                            poi.latitude = coord[1]
                            poi.longitude = coord[0]
                        }
                        
                        
                        aPOIs.append(poi)
                    }
                }
            }
//           let realm = try Realm()
//            realm.beginWrite()
//            realm.add(aPOIs)
//            try realm.commitWrite()
            try aPOIs.forEach { row in
                let _ = try WoosmapDataManager.connect.save(entity: row)
            }
            return aPOIs.map { poi in
                return POI(poiDB: poi)
            }
        } catch {
        }
        return []
    }
    
    
    /// Test POI (Add)
    /// - Parameter poi: POI List
    public class func addTest(poi: POI) {
        do {
//            let realm = try Realm()
//            realm.beginWrite()
//            realm.add(POIModel(poi:poi))
//            try realm.commitWrite()
            
            let newRec:POIDB = POIDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
            newRec.locationId = poi.locationId
            newRec.city = poi.city
            newRec.zipCode = poi.zipCode
            newRec.distance = poi.distance
            newRec.latitude = poi.latitude
            newRec.longitude = poi.longitude
            newRec.date = poi.date
            newRec.radius = poi.radius
            newRec.address = poi.address
            newRec.countryCode = poi.countryCode
            newRec.tags = poi.tags
            newRec.types = poi.types
            newRec.contact = poi.contact
            let _ = try WoosmapDataManager.connect.save(entity: newRec)
            
        } catch {
        }
    }
    
    /// Get All POI
    /// - Returns: POI List
    public class func getAll() -> [POI] {
        do {
            let pois = try WoosmapDataManager.connect.retrieve(entityClass: POIDB.self)
            return Array((pois).map({ poi in
                return POI(poiDB: poi)
            }))
        } catch {
        }
        return []
    }
    
    /// Get POI by LocationID
    /// - Parameter locationId: Location
    /// - Returns: POI Information
    public class func getPOIbyLocationID(locationId: String) -> POI? {
        if let poiModel = self._getPOIModelbyLocationID(locationId: locationId) {
            return POI(poiDB: poiModel)
        } else {
            return nil
        }
    }
    
    private class func _getPOIModelbyLocationID(locationId: String) -> POIDB? {
        do {
//            let realm = try Realm()
//            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
            
            let predicate = NSPredicate(format: "locationId == %@", locationId)
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: POIDB.self, predicate: predicate)
            if let aPOI = fetchedResults.first {
                return aPOI
            }
        
        } catch {
        }
        return nil
    }
    
    /// Last POI From Location
    /// - Parameter locationId: Location
    /// - Returns: POI Information
    public class func getLastPOIsFromLocationID(locationId: String) -> [POI] {
        do {
            let predicate = NSPredicate(format: "locationId == %@", locationId)
//            let realm = try Realm()
//            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
//            if fetchedResults.first != nil {
//                var poiArray:[POI] = []
//                for poi in fetchedResults {
//                    poiArray.append(POI(poiModel: poi))
//                }
//                return poiArray
//            }
            
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: POIDB.self, predicate: predicate)
            if fetchedResults.first != nil {
                var poiArray:[POI] = []
                for poi in fetchedResults {
                    poiArray.append(POI(poiDB: poi))
                }
                return poiArray
            }
            
        } catch {
        }
        return []
    }
    
    /// POI by store ID
    /// - Parameter idstore: store
    /// - Returns: POI Information
    public class func getPOIbyIdStore(idstore: String) -> POI? {
        do {
            let predicate = NSPredicate(format: "idstore == %@", idstore)
//            let realm = try Realm()
//            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
//            if let aPOI = fetchedResults.first {
//                return POI(poiModel: aPOI)
//            }
            
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: POIDB.self, predicate: predicate)
            if let aPOI = fetchedResults.first {
                return POI(poiDB: aPOI)
            }
            
        } catch {
        }
        return nil
    }
    
    /// Change POI distance/duration for Location
    /// - Parameters:
    ///   - distance: distance
    ///   - duration: duration
    ///   - locationId: Location
    /// - Returns: Updated POI information
    public class func updatePOIWithDistance(distance: Double, duration: String, locationId: String) -> POI {
        do {
//            let realm = try Realm()

            if let poiToUpdate = POIs._getPOIModelbyLocationID(locationId: locationId) {
//                realm.beginWrite()
                poiToUpdate.distance = distance
                poiToUpdate.duration = duration
//                realm.add(poiToUpdate)
//                try realm.commitWrite()
                _ = try WoosmapDataManager.connect.save(entity: poiToUpdate)
                return POI(poiDB: poiToUpdate)
            }
        } catch {
        }
        return POI()
    }
    
    
    /// Delete all POI and clean offline database
    public class func deleteAll() {
        do {
//            let realm = try Realm()
//            try realm.write {
//                realm.delete(realm.objects(POIModel.self))
//            }
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: POIDB.self)
        } catch let error as NSError {
            print(error)
        }
    }
}
