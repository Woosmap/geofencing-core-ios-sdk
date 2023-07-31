//
//  Region.swift
//  WoosmapGeofencing
//

import Foundation
import CoreLocation

public class Region {
    /// date
     public dynamic var date: Date = Date()
    
    /// didEnter
     public dynamic var didEnter: Bool = false
    
    /// identifier
     public dynamic var identifier: String = ""
    
    /// latitude
     public dynamic var latitude: Double = 0.0
    
    /// longitude
     public dynamic var longitude: Double = 0.0
    
    /// radius
     public dynamic var radius: Double = 0.0
    
    /// fromPositionDetection
     public dynamic var fromPositionDetection: Bool = false
    
    /// distance
     public dynamic var distance = 0;
    
    /// distanceText
     public dynamic var distanceText = "";
    
    /// duration
     public dynamic var duration = 0;
    
    /// durationText
     public dynamic var durationText = "";
    
    /// type
     public dynamic var type = "circle";
    
    /// origin
     public dynamic var origin = "";
    
    /// eventName
     public dynamic var eventName: String = "";
    
    /// spentTime
     public dynamic var spentTime: Double = 0;
    
    convenience public init(latitude: Double, longitude: Double, radius: Double, dateCaptured: Date, identifier: String, didEnter: Bool, fromPositionDetection: Bool, eventName: String) {
        self.init()
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.didEnter = didEnter
        self.identifier = identifier
        self.radius = radius
        self.fromPositionDetection = fromPositionDetection
        self.eventName = eventName
    }
    
    fileprivate convenience init(regionDB: RegionDB) {
        self.init()
        self.date = regionDB.date ?? Date()
        self.didEnter = regionDB.didEnter
        self.identifier = regionDB.identifier ?? ""
        self.latitude = regionDB.latitude
        self.longitude = regionDB.longitude
        self.radius = regionDB.radius
        self.fromPositionDetection = regionDB.fromPositionDetection
        self.distance = Int(regionDB.distance)
        self.distanceText = regionDB.distanceText ?? ""
        self.duration = Int(regionDB.duration)
        self.durationText = regionDB.durationText ?? ""
        self.type = regionDB.type ?? ""
        self.origin = regionDB.origin ?? ""
        self.eventName = regionDB.eventName ?? ""
        self.spentTime = regionDB.spentTime
    }
    
    fileprivate func dbEntity() -> RegionDB {
        let newRec:RegionDB = RegionDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
        newRec.date = self.date
        newRec.didEnter = self.didEnter
        newRec.identifier = self.identifier
        newRec.latitude = self.latitude
        newRec.longitude = self.longitude
        newRec.radius = self.radius
        newRec.fromPositionDetection = self.fromPositionDetection
        newRec.distance = Double (self.distance)
        newRec.distanceText = self.distanceText
        newRec.duration = Double(self.duration)
        newRec.durationText = self.durationText
        newRec.type  = self.type
        newRec.origin = self.origin
        newRec.eventName = self.eventName
        newRec.spentTime = self.spentTime
        return newRec
    }
}


public class DurationLog {
    
    /// identifier
    public dynamic var identifier: String = ""
    
    /// entryTime
    public dynamic var entryTime: Date = Date()
    
    /// exitTime
    public dynamic var exitTime: Date?
    
    fileprivate convenience init(durationLogDB: DurationLogDB) {
        self.init()
        self.identifier = durationLogDB.identifier ?? ""
        self.entryTime = durationLogDB.entryTime ?? Date()
        self.exitTime = durationLogDB.exitTime
    }
    
    fileprivate func dbEntity() -> DurationLogDB {
        let newRec:DurationLogDB = DurationLogDB(context: WoosmapDataManager.connect.woosmapDB.viewContext)
        newRec.identifier = self.identifier
        newRec.entryTime = self.entryTime
        newRec.exitTime = self.exitTime
        return newRec
    }
}

/// Duration Logs Controller
public class DurationLogs {
    
    /// Add new entry log in DurationLog
    ///
    ///Sample Code:
    ///```swift
    ///DurationLogs.addEntryLog(identifier: "test1")
    ///```
    /// - Parameter identifier: ID
    public static func addEntryLog(identifier: String){
        do {
            let newRec:DurationLog = DurationLog()
            newRec.identifier = identifier
            newRec.entryTime = Date()
            let _ = try WoosmapDataManager.connect.save(entity: newRec.dbEntity())
        } catch {
        }
    }
    
    /// Update exit time and calculated time spent in region
    ///
    ///Sample Code:
    ///```swift
    ///let duration = DurationLogs.addExitLog(identifier: "test1")
    ///```
    /// - Parameter identifier: ID
    /// - Returns: Time spend in region
    public static func addExitLog(identifier: String) -> TimeInterval{
        //Check Entry event for given id
        let predicate = NSPredicate(format: "identifier == %@ AND exitTime = nil", identifier)
        do {
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: DurationLogDB.self, predicate: predicate)
            if let log:DurationLogDB  = fetchedResults.first {
                log.exitTime = Date()
                let _ = try WoosmapDataManager.connect.save(entity: log)
                return Date().timeIntervalSinceReferenceDate - log.entryTime!.timeIntervalSinceReferenceDate
            }
        } catch {
        }
        return 0
    }
    
    /// Fetch All Duration Logs
    ///
    ///Sample Code:
    ///```swift
    ///let logs: [DurationLog] = DurationLogs.getAll()
    ///```
    /// - Returns: List of Logs in offile database
    public static func getAll() -> [DurationLog] {
        do {
            let logs = try WoosmapDataManager.connect.retrieve(entityClass: DurationLogDB.self)
            return Array((logs).map({ log in
                return DurationLog(durationLogDB: log)
            }))
            
        } catch {
        }
        return []
    }
    
    
    /// Clear DurationLog
    ///
    ///Sample Code:
    ///```swift
    ///DurationLogs.deleteAll()
    ///```
    public static func deleteAll() {
        do {
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: DurationLogDB.self)
        } catch let error as NSError {
            print(error)
        }
    }
}
public class Regions {
    
    /// Create new circle region
    /// - Parameters:
    ///   - POIregion: POI
    ///   - didEnter: Flag is Enter in region
    ///   - fromPositionDetection: user location
    /// - Returns: Region
    public static func add(POIregion: CLRegion, didEnter: Bool, fromPositionDetection: Bool) -> Region {
        do {
            
            let latRegion = (POIregion as! CLCircularRegion).center.latitude
            let lngRegion = (POIregion as! CLCircularRegion).center.longitude
            let radius = (POIregion as! CLCircularRegion).radius
            var identifier = POIregion.identifier
            var origin = "custom"
            if(POIregion.identifier.contains(RegionType.poi.rawValue)) {
                identifier = POIregion.identifier.components(separatedBy: "<id>")[1]
                origin = "POI"
            } else if (POIregion.identifier.contains(RegionType.custom.rawValue)) {
                identifier = POIregion.identifier.components(separatedBy: "<id>")[1]
                origin = "custom"
            }
            let eventName = didEnter ? "woos_geofence_entered_event" : "woos_geofence_exited_event"
            let entry = Region(latitude: latRegion,
                               longitude: lngRegion,
                               radius: radius,
                               dateCaptured: Date(),
                               identifier: identifier,
                               didEnter: didEnter,
                               fromPositionDetection: fromPositionDetection,
                               eventName: eventName)
        
            entry.origin = origin
            if(didEnter){
                DurationLogs.addEntryLog(identifier: identifier)
                entry.spentTime = 0
            }
            else{
                entry.spentTime = DurationLogs.addExitLog(identifier: identifier)
            }
            let _ = try WoosmapDataManager.connect.save(entity: entry.dbEntity())
            return entry
        } catch {
        }
        return Region()
    }
    
    
    /// Add Custom region
    /// - Parameter classifiedRegion: Custom region
    public static func add(classifiedRegion: Region) {
        
        do {
            let newRec:Region = Region()
            newRec.date = classifiedRegion.date
            newRec.didEnter = classifiedRegion.didEnter
            newRec.identifier = classifiedRegion.identifier
            newRec.latitude = classifiedRegion.latitude
            newRec.longitude = classifiedRegion.longitude
            newRec.radius = classifiedRegion.radius
            newRec.fromPositionDetection = classifiedRegion.fromPositionDetection
            newRec.distance = classifiedRegion.distance
            newRec.distanceText = classifiedRegion.distanceText
            newRec.duration = classifiedRegion.duration
            newRec.durationText = classifiedRegion.durationText
            newRec.type = classifiedRegion.type
            newRec.origin = classifiedRegion.origin
            newRec.eventName = classifiedRegion.eventName
            
            if(classifiedRegion.didEnter){
                DurationLogs.addEntryLog(identifier: classifiedRegion.identifier)
                newRec.spentTime = 0
            }
            else{
                newRec.spentTime = DurationLogs.addExitLog(identifier: classifiedRegion.identifier)
            }
            let _ = try WoosmapDataManager.connect.save(entity: newRec.dbEntity())
            
            
        } catch {
        }
    }
    
    /// Get Region information
    /// - Parameter id: ID
    /// - Returns: Region
    public static func getRegionFromId(id: String) -> Region? {
        do {
            var identifier = id
            if((id.contains(RegionType.poi.rawValue) || id.contains(RegionType.custom.rawValue))
               && id.contains("<id>")) {
                identifier = id.components(separatedBy: "<id>")[1]
            }
            let predicate = NSPredicate(format: "identifier == %@", identifier)
            let fetchedResults = try WoosmapDataManager.connect.retrieve(entityClass: RegionDB.self, predicate: predicate)
            if let aRegion = fetchedResults.first {
                return Region(regionDB:  aRegion)
            }
        } catch {
        }
        return nil
    }
    
    /// Get all region list
    /// - Returns: Regions
    public static func getAll() -> [Region] {
        do {
            let regions = try WoosmapDataManager.connect.retrieve(entityClass: RegionDB.self)
            return Array((regions).map({ region in
                return Region(regionDB: region)
            }))
        } catch {
        }
        return []
    }
    
    /// Delete all regions
    public static func deleteAll() {
        do {
            let _ = try WoosmapDataManager.connect.deleteAll(entityClass: RegionDB.self)
        } catch let error as NSError {
            print(error)
        }
    }
}
