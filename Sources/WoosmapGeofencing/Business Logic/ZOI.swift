//
//  ZOI.swift
//  WoosmapGeofencing
//
import Foundation
import os
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
    
    fileprivate init(zoiDB: ZOIDB) {
        self.accumulator = zoiDB.accumulator
        self.age =  zoiDB.age
        self.covariance_det =  zoiDB.covariance_det
        self.duration =  zoiDB.duration
        self.endTime =  zoiDB.endTime
        self.idVisits = zoiDB.idVisits ?? []
        self.latMean =  zoiDB.latMean
        self.lngMean =  zoiDB.lngMean
        self.period =  zoiDB.period
        self.prior_probability =  zoiDB.prior_probability
        self.startTime =  zoiDB.startTime
        self.weekly_density =  zoiDB.weekly_density ?? []
        self.wktPolygon =  zoiDB.wktPolygon
        self.x00Covariance_matrix_inverse =  zoiDB.x00Covariance_matrix_inverse
        self.x01Covariance_matrix_inverse =  zoiDB.x01Covariance_matrix_inverse
        self.x10Covariance_matrix_inverse =  zoiDB.x10Covariance_matrix_inverse
        self.x11Covariance_matrix_inverse =  zoiDB.x11Covariance_matrix_inverse
        self.zoiId =  zoiDB.zoiId
    }
    
    fileprivate func dbEntity() throws-> ZOIDB{
        if(WoosmapDataManager.connect.isDBMissing == true){
            throw WoosmapGeofenceError.dbMissing
        }
        
        let newRec:ZOIDB = ZOIDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
        newRec.accumulator = self.accumulator
        newRec.age = self.age
        newRec.covariance_det = self.covariance_det
        newRec.duration = self.duration
        newRec.endTime = self.endTime
        newRec.idVisits = self.idVisits
        newRec.latMean = self.latMean
        newRec.lngMean = self.lngMean
        newRec.period = self.period
        newRec.prior_probability = self.prior_probability
        newRec.startTime = self.startTime
        newRec.weekly_density = self.weekly_density
        newRec.wktPolygon = self.wktPolygon
        newRec.x00Covariance_matrix_inverse = self.x00Covariance_matrix_inverse
        newRec.x01Covariance_matrix_inverse = self.x01Covariance_matrix_inverse
        newRec.x10Covariance_matrix_inverse = self.x10Covariance_matrix_inverse
        newRec.x11Covariance_matrix_inverse = self.x11Covariance_matrix_inverse
        newRec.zoiId = self.zoiId
        
        return newRec
    }
    
}
/// ZOI business class
public class ZOIs {
    
    /// New ZOI form from row detail
    /// - Parameter zoi: Raw information
    public class func createZOIFrom(zoi: [String: Any]) {
        do {
            
            let newZOI = ZOI()
            newZOI.zoiId = UUID().uuidString
            newZOI.idVisits = zoi["idVisits"] as! [String]
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
            
            newZOI.startTime = startTime // .setValue(startTime, forKey: "startTime")
            newZOI.endTime = endTime//setValue(endTime, forKey: "endTime")
            newZOI.duration = Int64(duration)//setValue(duration, forKey: "duration")
            newZOI.weekly_density = zoi["weekly_density"] as! [Double] //setValue(, forKey: "weekly_density")
            newZOI.period = zoi["period"] as? String //(zoi["period"], forKey: "period")
            newZOI.latMean = (zoi["mean"] as! [Any])[0] as! Double
            newZOI.lngMean = (zoi["mean"] as! [Any])[1] as! Double
            newZOI.age = zoi["age"] as! Double
            newZOI.accumulator = zoi["accumulator"] as! Double
            newZOI.covariance_det = zoi["covariance_det"] as! Double
            newZOI.prior_probability = zoi["prior_probability"] as! Double
            
            newZOI.x00Covariance_matrix_inverse = zoi["x00Covariance_matrix_inverse"] as! Double
            newZOI.x01Covariance_matrix_inverse = zoi["x01Covariance_matrix_inverse"] as! Double
            newZOI.x10Covariance_matrix_inverse = zoi["x10Covariance_matrix_inverse"] as! Double
            newZOI.x11Covariance_matrix_inverse = zoi["x11Covariance_matrix_inverse"] as! Double
            newZOI.wktPolygon = zoi["WktPolygon"] as? String
            let _ = try WoosmapDataManager.connect.save(entity: newZOI.dbEntity())
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
    }
    
    /// Save ZPI in local database
    /// - Parameter zois: Raw information
    public class func saveZoisInDB(zois: [[String: Any]]) {
        var zoiArray: [ZOI] = []
        for zoi in zois {
            let newZOi = ZOI()
            newZOi.zoiId  = UUID().uuidString
            newZOi.idVisits = zoi["idVisits"] as! [String]
            var visitArrivalDate = [Date]()
            var visitDepartureDate = [Date]()
            var duration = 0
            var startTime = Date()
            var endTime = Date()
            var arrayIdVisits: [String] = []
            if let list = zoi["idVisits"] as? [String] {
                arrayIdVisits = list
            } else {
                // TODO: validate this
                //arrayIdVisits = Array((zoi["idVisits"] as! List<String>).elements)
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
            newZOi.startTime = startTime
            newZOi.endTime = endTime
            newZOi.duration = Int64(duration)
            newZOi.weekly_density = zoi["weekly_density"] as! [Double]
            newZOi.period = zoi["period"] as? String
            newZOi.latMean = (zoi["mean"] as! [Any])[0] as! Double
            newZOi.lngMean = (zoi["mean"] as! [Any])[1] as! Double
            newZOi.age = zoi["age"] as! Double
            newZOi.accumulator = zoi["accumulator"] as! Double
            newZOi.covariance_det = zoi["covariance_det"] as! Double
            newZOi.prior_probability = zoi["prior_probability"] as! Double
            newZOi.x00Covariance_matrix_inverse = zoi["x00Covariance_matrix_inverse"] as! Double
            newZOi.x01Covariance_matrix_inverse = zoi["x01Covariance_matrix_inverse"] as! Double
            newZOi.x10Covariance_matrix_inverse = zoi["x10Covariance_matrix_inverse"] as! Double
            newZOi.x11Covariance_matrix_inverse = zoi["x11Covariance_matrix_inverse"] as! Double
            newZOi.wktPolygon = zoi["WktPolygon"] as? String
            zoiArray.append(newZOi)
        }
        
        do {
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: ZOIDB.self)
            try zoiArray.forEach { row in
                let newRec:ZOIDB = try row.dbEntity()
                let _ = try WoosmapDataManager.connect.save(entity: newRec)
            }
            
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
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
            zoiToAdd["weeks_on_zoi"] = [] as [Double]
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
            zoiToAdd["weeks_on_zoi"] = [] as [Double]
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
            zoiToAdd["weeks_on_zoi"] = [] as [Double]
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
            let zois = try WoosmapDataManager.connect.retrieve(entityClass: ZOIDB.self)
            
            var externalZois: [ZOI] = []
            
            for zoi in zois {
                externalZois.append(ZOI(zoiDB: zoi))
            }
            
            return externalZois
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
        return []
    }
    
    /// Delete All ZOI information
    public class func deleteAll() {
        do {
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: ZOIDB.self)
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
    }
    
    /// Work Home ZOI
    /// - Returns: Work/Home ZOI
    public class func getWorkHomeZOI() -> [ZOI] {
        do {
            let predicate = NSPredicate(format: "period == %@ OR period == %@", "WORK_PERIOD", "HOME_PERIOD")
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: ZOIDB.self, predicate: predicate)
            return fetchedResults.map { zoi in
                return ZOI(zoiDB: zoi)
            }
        } catch {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
                } else {
                    WoosLog.error("\(#function) error: \(error)")
                }
            }
        }
        return []
    }
}

