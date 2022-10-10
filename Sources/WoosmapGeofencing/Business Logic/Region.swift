//
//  Region.swift
//  WoosmapGeofencing
//

import Foundation
import RealmSwift
import CoreLocation

/// Offline Databse: Region
public class Region: Object {
    
    /// date
    @objc public dynamic var date: Date = Date()
    
    /// didEnter
    @objc public dynamic var didEnter: Bool = false
    
    /// identifier
    @objc public dynamic var identifier: String = ""
    
    /// latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// longitude
    @objc public dynamic var longitude: Double = 0.0
    
    /// radius
    @objc public dynamic var radius: Double = 0.0
    
    /// fromPositionDetection
    @objc public dynamic var fromPositionDetection: Bool = false
    
    /// distance
    @objc public dynamic var distance = 0;
    
    /// distanceText
    @objc public dynamic var distanceText = "";
    
    /// duration
    @objc public dynamic var duration = 0;
    
    /// durationText
    @objc public dynamic var durationText = "";
    
    /// type
    @objc public dynamic var type = "circle";
    
    /// origin
    @objc public dynamic var origin = "";
    
    /// eventName
    @objc public dynamic var eventName: String = "";
    
    /// spentTime
    @objc public dynamic var spentTime: Double = 0;
    
    /// Create new region object
    /// - Parameters:
    ///   - latitude:
    ///   - longitude:
    ///   - radius:
    ///   - dateCaptured:
    ///   - identifier:
    ///   - didEnter:
    ///   - fromPositionDetection:
    ///   - eventName:
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
}

/// Offline Database: DurationLog
public class DurationLog: Object {
    
    /// identifier
    @objc public dynamic var identifier: String = ""
    
    /// entryTime
    @objc public dynamic var entryTime: Date = Date()
    
    /// exitTime
    @objc public dynamic var exitTime: Date?
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
            let realm = try Realm()
            let entry = DurationLog()
            entry.identifier = identifier
            entry.entryTime = Date()
            realm.beginWrite()
            realm.add(entry)
            try realm.commitWrite()
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
            let realm = try Realm()
            let fetchedResults = realm.objects(DurationLog.self).filter(predicate)
            if let log:DurationLog  = fetchedResults.first {
                try realm.write {
                    log.exitTime = Date()
                }
                return Date().timeIntervalSinceReferenceDate - log.entryTime.timeIntervalSinceReferenceDate
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
            let realm = try Realm()
            let regions = realm.objects(DurationLog.self)
            return Array(regions)
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
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(DurationLog.self))
            }
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
            let realm = try Realm()
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
                DurationLogs.addEntryLog(identifier: entry.identifier)
                entry.spentTime = 0
            }
            else{
                entry.spentTime = DurationLogs.addExitLog(identifier: entry.identifier)
            }
            realm.beginWrite()
            realm.add(entry)
            try realm.commitWrite()
            return entry
        } catch {
        }
        return Region()
    }
    
    
    /// Add Custom region
    /// - Parameter classifiedRegion: Custom region
    public static func add(classifiedRegion: Region) {
        do {
            let realm = try Realm()
            if(classifiedRegion.didEnter){
                DurationLogs.addEntryLog(identifier: classifiedRegion.identifier)
                classifiedRegion.spentTime = 0
            }
            else{
                classifiedRegion.spentTime = DurationLogs.addExitLog(identifier: classifiedRegion.identifier)
            }
            realm.beginWrite()
            realm.add(classifiedRegion)
            try realm.commitWrite()
        } catch {
        }
    }
    
    /// Get Region information
    /// - Parameter id: ID
    /// - Returns: Region
    public static func getRegionFromId(id: String) -> Region? {
        do {
            let realm = try Realm()
            var identifier = id
            if((id.contains(RegionType.poi.rawValue) || id.contains(RegionType.custom.rawValue))
               && id.contains("<id>")) {
                identifier = id.components(separatedBy: "<id>")[1]
            }
            let predicate = NSPredicate(format: "identifier == %@", identifier)
            let fetchedResults = realm.objects(Region.self).filter(predicate)
            if let aRegion = fetchedResults.last {
                return aRegion
            }
        } catch {
        }
        return nil
    }
    
    /// Get all region list
    /// - Returns: Regions
    public static func getAll() -> [Region] {
        do {
            let realm = try Realm()
            let regions = realm.objects(Region.self)
            return Array(regions)
        } catch {
        }
        return []
    }
    
    /// Delete all regions
    public static func deleteAll() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(Region.self))
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
