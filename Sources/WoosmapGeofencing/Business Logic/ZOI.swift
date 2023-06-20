//
//  ZOI.swift
//  WoosmapGeofencing
//

@_implementationOnly import RealmSwift
import Foundation

public class ZOI {
    /// Accumulator
    public var accumulator: Double = 0
    
    /// Age
    public var age: Double = 0
    
    /// Covariance_det
    public var covariance_det: Double = 0
    
    /// Duration
    public var duration: Int64 = 0
    
    /// End Time
    public var endTime: Date? = nil
    
    /// Visit ID
    public var idVisits: [String] = []
    
    /// LatMean
    public var latMean: Double = 0.0
    
    /// LngMean
    public var lngMean: Double = 0.0
    
    /// Period
    public var period: String? = nil
    
    /// Prior Probability
    public var prior_probability: Double = 0.0
    
    /// Start Time
    public var startTime: Date? = nil
    
    /// Weekly Density
    public var weekly_density: [Double] = []
    
    /// wktPolygon
    public var wktPolygon: String? = nil
    
    /// x00Covariance_matrix_inverse
    public var x00Covariance_matrix_inverse: Double = 0.0
    
    /// x01Covariance_matrix_inverse
    public var x01Covariance_matrix_inverse: Double = 0.0
    
    /// x10Covariance_matrix_inverse
    public var x10Covariance_matrix_inverse: Double = 0.0
    
    /// x11Covariance_matrix_inverse
    public var x11Covariance_matrix_inverse: Double = 0.0
    
    /// ID
    public var zoiId: String?
    public init() {
        
    }

    fileprivate init(zoiModel: ZOIModel) {
        self.accumulator = zoiModel.accumulator
        self.age =  zoiModel.age
        self.covariance_det =  zoiModel.covariance_det
        self.duration =  zoiModel.duration
        self.endTime =  zoiModel.endTime
        self.idVisits =  Array(zoiModel.idVisits)
        self.latMean =  zoiModel.latMean
        self.lngMean =  zoiModel.lngMean
        self.period =  zoiModel.period
        self.prior_probability =  zoiModel.prior_probability
        self.startTime =  zoiModel.startTime
        self.weekly_density =  Array(zoiModel.weekly_density)
        self.wktPolygon =  zoiModel.wktPolygon
        self.x00Covariance_matrix_inverse =  zoiModel.x00Covariance_matrix_inverse
        self.x01Covariance_matrix_inverse =  zoiModel.x01Covariance_matrix_inverse
        self.x10Covariance_matrix_inverse =  zoiModel.x10Covariance_matrix_inverse
        self.x11Covariance_matrix_inverse =  zoiModel.x11Covariance_matrix_inverse
        self.zoiId =  zoiModel.zoiId
    }
}

/// Zone of Intrest Object
class ZOIModel: Object {
    
    /// Accumulator
    @Persisted var accumulator: Double = 0.0
    
    /// Age
    @Persisted var age: Double = 0.0
    
    /// Covariance_det
    @Persisted var covariance_det: Double = 0.0
    
    /// Duration
    @Persisted var duration: Int64 = 0
    
    /// End Time
    @Persisted var endTime: Date?
    
    /// Visit ID
    @Persisted var idVisits = List<String>()
    
    /// LatMean
    @Persisted var latMean: Double = 0.0
    
    /// LngMean
    @Persisted var lngMean: Double = 0.0
    
    /// Period
    @Persisted var period: String?
    
    /// Prior Probability
    @Persisted var prior_probability: Double = 0.0
    
    /// Start Time
    @Persisted var startTime: Date?
    
    /// Weekly Density
    @Persisted var weekly_density = List<Double>()
    
    /// wktPolygon
    @Persisted var wktPolygon: String?
    
    /// x00Covariance_matrix_inverse
    @Persisted var x00Covariance_matrix_inverse: Double = 0.0
    
    /// x01Covariance_matrix_inverse
    @Persisted var x01Covariance_matrix_inverse: Double = 0.0
    
    /// x10Covariance_matrix_inverse
    @Persisted var x10Covariance_matrix_inverse: Double = 0.0
    
    /// x11Covariance_matrix_inverse
    @Persisted var x11Covariance_matrix_inverse: Double = 0.0
    
    /// ID
    @Persisted(primaryKey: true) var zoiId: String?
}

/// ZOI business class
public class ZOIs {
    
    /// New ZOI form from row detail
    /// - Parameter zoi: Raw information
    public class func createZOIFrom(zoi: [String: Any]) {
        do {
            let realm = try Realm()
            let newZOI = ZOIModel()
            newZOI.zoiId = UUID().uuidString
            newZOI.idVisits = zoi["idVisits"] as! List<String>
            var visitArrivalDate = [Date]()
            var visitDepartureDate = [Date]()
            var duration = 0
            var startTime = Date()
            var endTime = Date()
            if !(zoi["idVisits"] as! [String]).isEmpty {
                for id in zoi["idVisits"] as! [String] {
                    let visit = Visits.getVisitFromUUID(id: id)
                    if visit != nil {
                        visitArrivalDate.append(visit!.arrivalDate!)
                        visitDepartureDate.append(visit!.departureDate!)
                        duration += visit!.departureDate!.seconds(from: visit!.arrivalDate!)
                    }
                }
                startTime = visitArrivalDate.reduce(visitArrivalDate[0], { $0.timeIntervalSince1970 < $1.timeIntervalSince1970 ? $0 : $1 })
                endTime = visitDepartureDate.reduce(visitDepartureDate[0], { $0.timeIntervalSince1970 > $1.timeIntervalSince1970 ? $0 : $1 })
            }
            newZOI.setValue(startTime, forKey: "startTime")
            newZOI.setValue(endTime, forKey: "endTime")
            newZOI.setValue(duration, forKey: "duration")
            newZOI.setValue(zoi["weekly_density"], forKey: "weekly_density")
            newZOI.setValue(zoi["period"], forKey: "period")
            newZOI.setValue((zoi["mean"] as! [Any])[0] as! Double, forKey: "latMean")
            newZOI.setValue((zoi["mean"] as! [Any])[1] as! Double, forKey: "lngMean")
            newZOI.setValue(zoi["age"], forKey: "age")
            newZOI.setValue(zoi["accumulator"], forKey: "accumulator")
            newZOI.setValue(zoi["covariance_det"], forKey: "covariance_det")
            newZOI.setValue(zoi["prior_probability"], forKey: "prior_probability")
            newZOI.setValue(zoi["x00Covariance_matrix_inverse"], forKey: "x00Covariance_matrix_inverse")
            newZOI.setValue(zoi["x01Covariance_matrix_inverse"], forKey: "x01Covariance_matrix_inverse")
            newZOI.setValue(zoi["x10Covariance_matrix_inverse"], forKey: "x10Covariance_matrix_inverse")
            newZOI.setValue(zoi["x11Covariance_matrix_inverse"], forKey: "x11Covariance_matrix_inverse")
            newZOI.setValue(zoi["WktPolygon"], forKey: "wktPolygon")
            
            realm.beginWrite()
            realm.add(newZOI)
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// Save ZPI in local database
    /// - Parameter zois: Raw information
    public class func saveZoisInDB(zois: [[String: Any]]) {
        var zoisToDB: [ZOIModel] = []
        for zoi in zois {
            let newZOi = ZOIModel()
            newZOi.setValue(UUID().uuidString, forKey: "zoiId")
            newZOi.setValue(zoi["idVisits"], forKey: "idVisits")
            var visitArrivalDate = [Date]()
            var visitDepartureDate = [Date]()
            var duration = 0
            var startTime = Date()
            var endTime = Date()
            var arrayIdVisits: [String] = [String]()
            if let list = zoi["idVisits"] as? [String] {
                arrayIdVisits = list
            } else {
                arrayIdVisits = Array((zoi["idVisits"] as! List<String>).elements)
            }
            if arrayIdVisits.count != 0 {
                for id in arrayIdVisits {
                    let visit = Visits.getVisitFromUUID(id: id)
                    if visit != nil {
                        visitArrivalDate.append(visit!.arrivalDate!)
                        visitDepartureDate.append(visit!.departureDate!)
                        duration += visit!.departureDate!.seconds(from: visit!.arrivalDate!)
                    }
                }
                startTime = visitArrivalDate.reduce(visitArrivalDate[0], { $0.timeIntervalSince1970 < $1.timeIntervalSince1970 ? $0 : $1 })
                endTime = visitDepartureDate.reduce(visitDepartureDate[0], { $0.timeIntervalSince1970 > $1.timeIntervalSince1970 ? $0 : $1 })
            }
            newZOi.setValue(startTime, forKey: "startTime")
            newZOi.setValue(endTime, forKey: "endTime")
            newZOi.setValue(duration, forKey: "duration")
            newZOi.setValue(zoi["weekly_density"], forKey: "weekly_density")
            newZOi.setValue(zoi["period"], forKey: "period")
            newZOi.setValue((zoi["mean"] as! [Any])[0] as! Double, forKey: "latMean")
            newZOi.setValue((zoi["mean"] as! [Any])[1] as! Double, forKey: "lngMean")
            newZOi.setValue(zoi["age"], forKey: "age")
            newZOi.setValue(zoi["accumulator"], forKey: "accumulator")
            newZOi.setValue(zoi["covariance_det"], forKey: "covariance_det")
            newZOi.setValue(zoi["prior_probability"], forKey: "prior_probability")
            newZOi.setValue(zoi["x00Covariance_matrix_inverse"], forKey: "x00Covariance_matrix_inverse")
            newZOi.setValue(zoi["x01Covariance_matrix_inverse"], forKey: "x01Covariance_matrix_inverse")
            newZOi.setValue(zoi["x10Covariance_matrix_inverse"], forKey: "x10Covariance_matrix_inverse")
            newZOi.setValue(zoi["x11Covariance_matrix_inverse"], forKey: "x11Covariance_matrix_inverse")
            newZOi.setValue(zoi["WktPolygon"], forKey: "wktPolygon")
            zoisToDB.append(newZOi)
        }
        
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.delete(realm.objects(ZOIModel.self))
            realm.add(zoisToDB)
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// Create new ZOI form visit log
    /// - Parameter visit: Visit Log
    public class func createZOIFromVisit(visit: Visit) {
        let sMercator = SphericalMercator()
        var zoisFromDB: [[String: Any]] = []
        
        for zoiFromDB in ZOIs.getAll() {
            var zoiToAdd = [String: Any]()
            zoiToAdd["prior_probability"] = zoiFromDB.prior_probability
            zoiToAdd["mean"] = [zoiFromDB.latMean, zoiFromDB.lngMean]
            zoiToAdd["age"] = zoiFromDB.age
            zoiToAdd["accumulator"] = zoiFromDB.accumulator
            zoiToAdd["idVisits"] = zoiFromDB.idVisits
            var listVisit: [LoadedVisit] = []
            for id in zoiFromDB.idVisits {
                let visitFromId = Visits.getVisitFromUUID(id: id)
                if visitFromId != nil {
                    let point: LoadedVisit = LoadedVisit(x: visitFromId!.latitude, y: visitFromId!.longitude, accuracy: visitFromId!.accuracy, id: visitFromId!.visitId!, startTime: visitFromId!.arrivalDate!, endTime: visitFromId!.departureDate!)
                    listVisit.append(point)
                }
            }
            zoiToAdd["visitPoint"] = listVisit
            zoiToAdd["startTime"] = zoiFromDB.startTime
            zoiToAdd["endTime"] = zoiFromDB.endTime
            zoiToAdd["duration"] = zoiFromDB.duration
            zoiToAdd["weekly_density"] = zoiFromDB.weekly_density
            zoiToAdd["weeks_on_zoi"] = []
            zoiToAdd["period"] = zoiFromDB.period
            zoiToAdd["covariance_det"] = zoiFromDB.covariance_det
            zoiToAdd["x00Covariance_matrix_inverse"] = zoiFromDB.x00Covariance_matrix_inverse
            zoiToAdd["x01Covariance_matrix_inverse"] = zoiFromDB.x01Covariance_matrix_inverse
            zoiToAdd["x10Covariance_matrix_inverse"] = zoiFromDB.x10Covariance_matrix_inverse
            zoiToAdd["x11Covariance_matrix_inverse"] = zoiFromDB.x11Covariance_matrix_inverse
            zoisFromDB.append(zoiToAdd)
            
        }
        
        setListZOIsFromDB(zoiFromDB: zoisFromDB)
        
        let list_zoi = figmmForVisit(newVisitPoint: LoadedVisit(x: sMercator.lon2x(aLong: visit.longitude), y: sMercator.lat2y(aLat: visit.latitude), accuracy: visit.accuracy, id: visit.visitId!, startTime: visit.arrivalDate!, endTime: visit.departureDate!))
        
        saveZoisInDB(zois: list_zoi)
    }
    
    /// Create new ZOI info from Location information
    /// - Parameter visit: Location information
    public class func createZOIFromLocation(visit: Location) {
        let sMercator = SphericalMercator()
        var zoisFromDB: [[String: Any]] = []
        for zoiFromDB in ZOIs.getAll() {
            var zoiToAdd = [String: Any]()
            zoiToAdd["prior_probability"] = zoiFromDB.prior_probability
            zoiToAdd["mean"] = [zoiFromDB.latMean, zoiFromDB.lngMean]
            zoiToAdd["age"] = zoiFromDB.age
            zoiToAdd["accumulator"] = zoiFromDB.accumulator
            zoiToAdd["idVisits"] = zoiFromDB.idVisits
            var listVisit: [LoadedVisit] = []
            for id in zoiFromDB.idVisits {
                let visit = Visits.getVisitFromUUID(id: id)
                if visit != nil {
                    let point: LoadedVisit = LoadedVisit(x: visit!.latitude, y: visit!.longitude, accuracy: visit!.accuracy, id: visit!.visitId!, startTime: visit!.arrivalDate!, endTime: visit!.departureDate!)
                    listVisit.append(point)
                }
            }
            zoiToAdd["startTime"] = zoiFromDB.startTime
            zoiToAdd["endTime"] = zoiFromDB.endTime
            zoiToAdd["duration"] = zoiFromDB.duration
            zoiToAdd["weekly_density"] = zoiFromDB.weekly_density
            zoiToAdd["period"] = zoiFromDB.period
            zoiToAdd["weeks_on_zoi"] = []
            zoiToAdd["covariance_det"] = zoiFromDB.covariance_det
            zoiToAdd["x00Covariance_matrix_inverse"] = zoiFromDB.x00Covariance_matrix_inverse
            zoiToAdd["x01Covariance_matrix_inverse"] = zoiFromDB.x01Covariance_matrix_inverse
            zoiToAdd["x10Covariance_matrix_inverse"] = zoiFromDB.x10Covariance_matrix_inverse
            zoiToAdd["x11Covariance_matrix_inverse"] = zoiFromDB.x11Covariance_matrix_inverse
            zoisFromDB.append(zoiToAdd)
            
        }
        
        setListZOIsFromDB(zoiFromDB: zoisFromDB)
        
        let list_zoi = figmmForVisit(newVisitPoint: LoadedVisit(x: sMercator.lon2x(aLong: visit.longitude), y: sMercator.lat2y(aLat: visit.latitude), accuracy: 20.0, id: visit.locationId!, startTime: Date(), endTime: Date().addingTimeInterval(100)))
        
        ZOIs.deleteAll()
        
        for zoi in list_zoi {
            createZOIFrom(zoi: zoi)
        }
        
    }
    
    /// Update ZOI information
    /// - Parameter visits: Visit Info
    public class func updateZOI(visits: [Visit]) {
        let sMercator = SphericalMercator()
        var zoisFromDB: [[String: Any]] = []
        
        for zoiFromDB in ZOIs.getAll() {
            var zoiToAdd = [String: Any]()
            zoiToAdd["prior_probability"] = zoiFromDB.prior_probability
            zoiToAdd["mean"] = [zoiFromDB.latMean, zoiFromDB.lngMean]
            zoiToAdd["age"] = zoiFromDB.age
            zoiToAdd["accumulator"] = zoiFromDB.accumulator
            zoiToAdd["idVisits"] = zoiFromDB.idVisits
            var listVisit: [LoadedVisit] = []
            for id in zoiFromDB.idVisits {
                let visitFromId = Visits.getVisitFromUUID(id: id)
                if visitFromId != nil {
                    let point: LoadedVisit = LoadedVisit(x: visitFromId!.latitude, y: visitFromId!.longitude, accuracy: visitFromId!.accuracy, id: visitFromId!.visitId!, startTime: visitFromId!.arrivalDate!, endTime: visitFromId!.departureDate!)
                    listVisit.append(point)
                }
            }
            zoiToAdd["visitPoint"] = listVisit
            zoiToAdd["startTime"] = zoiFromDB.startTime
            zoiToAdd["endTime"] = zoiFromDB.endTime
            zoiToAdd["duration"] = zoiFromDB.duration
            zoiToAdd["weekly_density"] = zoiFromDB.weekly_density
            zoiToAdd["weeks_on_zoi"] = []
            zoiToAdd["period"] = zoiFromDB.period
            zoiToAdd["covariance_det"] = zoiFromDB.covariance_det
            zoiToAdd["x00Covariance_matrix_inverse"] = zoiFromDB.x00Covariance_matrix_inverse
            zoiToAdd["x01Covariance_matrix_inverse"] = zoiFromDB.x01Covariance_matrix_inverse
            zoiToAdd["x10Covariance_matrix_inverse"] = zoiFromDB.x10Covariance_matrix_inverse
            zoiToAdd["x11Covariance_matrix_inverse"] = zoiFromDB.x11Covariance_matrix_inverse
            zoisFromDB.append(zoiToAdd)
        }
        
        setListZOIsFromDB(zoiFromDB: zoisFromDB)
        
        var list_zoi: [[String: Any]] = []
        for visit in visits {
            list_zoi = deleteVisitOnZoi(visitsToDelete: LoadedVisit(x: sMercator.lon2x(aLong: visit.longitude), y: sMercator.lat2y(aLat: visit.latitude), accuracy: visit.accuracy, id: visit.visitId!, startTime: visit.arrivalDate!, endTime: visit.departureDate!))
        }
        
        ZOIs.saveZoisInDB(zois: list_zoi)
    }
    
    /// Get All ZOI
    /// - Returns: ZOIs
    public class func getAll() -> [ZOI] {
        do {
            let realm = try Realm()
            let zois = realm.objects(ZOIModel.self)
            
            var externalZois: [ZOI] = []
            
            for zoi in zois {
                externalZois.append(ZOI(zoiModel: zoi))
            }
            
            return externalZois
        } catch {
        }
        return []
    }
    
    /// Delete All ZOI information
    public class func deleteAll() {
        do {
            let realm = try Realm()
            realm.beginWrite()
            realm.delete(realm.objects(ZOIModel.self))
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// Work Home ZOI
    /// - Returns: Work/Home ZOI
    public class func getWorkHomeZOI() -> [ZOI] {
        do {
            let realm = try Realm()
            let predicate = NSPredicate(format: "period == %@ OR period == %@", "WORK_PERIOD", "HOME_PERIOD")
            let fetchedResults = realm.objects(ZOIModel.self).filter(predicate)
            return toZOI(zoiModels: Array(fetchedResults))
        } catch {
        }
        return []
    }
}


private func toZOI(zoiModels: [ZOIModel]) -> [ZOI] {
    var externalZois: [ZOI] = []
    
    for zoi in zoiModels {
        externalZois.append(ZOI(zoiModel: zoi))
    }
    return externalZois
}
