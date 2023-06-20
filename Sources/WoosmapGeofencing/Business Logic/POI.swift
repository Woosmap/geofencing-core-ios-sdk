//
//  POI.swift
//  WoosmapGeofencing
//
@_implementationOnly import Realm
@_implementationOnly import RealmSwift
import Foundation

/// Point of Intrest DB Object
class POIModel: Object {
    
    /// JSON Data
    @Persisted public var jsonData: Data?
    
    /// City
    @Persisted public var city: String?
    
    /// Store ID
    @Persisted public var idstore: String?
    
    /// Name
    @Persisted public var name: String?
    
    /// Date
    @Persisted public var date: Date?
    
    /// Distance
    @Persisted public var distance: Double = 0.0
    
    /// Duration
    @Persisted public var duration: String?
    
    /// Latitude
    @Persisted public var latitude: Double = 0.0
    
    /// Location ID
    @Persisted public var locationId: String?
    
    /// Longitude
    @Persisted public var longitude: Double = 0.0
    
    /// Zip Code
    @Persisted public var zipCode: String?
    
    /// Radius
    @Persisted public var radius: Double = 0.0
    
    /// Address
    @Persisted public var address: String?
    
    /// Open Now
    @Persisted public var openNow: Bool = false
    
    /// Country Code
    @Persisted public var countryCode: String?
    
    /// Tags
    @Persisted public var tags: String?
    
    /// Types
    @Persisted public var types: String?
    
    /// Contact
    @Persisted public var contact: String?
    
    
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
    
    fileprivate convenience init(poi: POI) {
        self.init()
        self.locationId = poi.locationId
        self.city = poi.city
        self.zipCode = poi.zipCode
        self.distance = poi.distance
        self.latitude = poi.latitude
        self.longitude = poi.longitude
        self.date = poi.date
        self.radius = poi.radius
        self.address = poi.address
        self.countryCode = poi.countryCode
        self.tags = poi.tags
        self.types = poi.types
        self.contact = poi.contact
    }
}

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
    
    fileprivate convenience init(poiModel: POIModel) {
        self.init()
        self.locationId = poiModel.locationId
        self.city = poiModel.city
        self.zipCode = poiModel.zipCode
        self.distance = poiModel.distance
        self.duration = poiModel.duration
        self.latitude = poiModel.latitude
        self.longitude = poiModel.longitude
        self.date = poiModel.date
        self.radius = poiModel.radius
        self.address = poiModel.address
        self.countryCode = poiModel.countryCode
        self.tags = poiModel.tags
        self.types = poiModel.types
        self.contact = poiModel.contact
        self.jsonData = poiModel.jsonData
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
            let realm = try Realm()
            var aPOIs: [POIModel] = []
            if let value = jsonStructure.value as? [String: Any] {
                if let features = value["features"] as? [[String: Any]] {
                    for feature in features {
                        let poi = POIModel()
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
            
            realm.beginWrite()
            realm.add(aPOIs)
            try realm.commitWrite()
            return aPOIs.map { poiModel in
                return POI(poiModel: poiModel)
            }
        } catch {
        }
        return []
    }
    
    
    /// Test POI (Add)
    /// - Parameter poi: POI List
    public class func addTest(poi: POI) {
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.add(POIModel(poi:poi))
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// Get All POI
    /// - Returns: POI List
    public class func getAll() -> [POI] {
        do {
            let realm = try Realm()
            let pois = realm.objects(POIModel.self)
            return Array(pois).map { poiModel in
                return POI(poiModel: poiModel)
            }
        } catch {
        }
        return []
    }
    
    /// Get POI by LocationID
    /// - Parameter locationId: Location
    /// - Returns: POI Information
    public class func getPOIbyLocationID(locationId: String) -> POI? {
        if let poiModel = self._getPOIModelbyLocationID(locationId: locationId) {
            return POI(poiModel: poiModel)
        } else {
            return nil
        }
    }
    
    private class func _getPOIModelbyLocationID(locationId: String) -> POIModel? {
        do {
            let realm = try Realm()
            let predicate = NSPredicate(format: "locationId == %@", locationId)
            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
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
            let realm = try Realm()
            let predicate = NSPredicate(format: "locationId == %@", locationId)
            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
            if fetchedResults.first != nil {
                var poiArray:[POI] = []
                for poi in fetchedResults {
                    poiArray.append(POI(poiModel: poi))
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
            let realm = try Realm()
            let predicate = NSPredicate(format: "idstore == %@", idstore)
            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
            if let aPOI = fetchedResults.first {
                return POI(poiModel: aPOI)
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
            let realm = try Realm()

            if let poiToUpdate = POIs._getPOIModelbyLocationID(locationId: locationId) {
                realm.beginWrite()
                poiToUpdate.distance = distance
                poiToUpdate.duration = duration
                realm.add(poiToUpdate)
                try realm.commitWrite()
                return POI(poiModel: poiToUpdate)
            }
        } catch {
        }
        return POI()
    }
    
    
    /// Delete all POI and clean offline database
    public class func deleteAll() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(POIModel.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
