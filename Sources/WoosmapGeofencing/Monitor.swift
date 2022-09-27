import Foundation
import CoreLocation
import UserNotifications

/// Location Service callback
public protocol LocationServiceDelegate: AnyObject {
    func tracingLocation(location: Location)
    func tracingLocationDidFailWithError(error: Error)
}

/// Search Service callback
public protocol SearchAPIDelegate: AnyObject {
    func searchAPIResponse(poi: POI)
    func serachAPIError(error: String)
}

/// Distance API Callback
public protocol DistanceAPIDelegate: AnyObject {
    func distanceAPIResponse(distance: [Distance])
    func distanceAPIError(error: String)
}

/// Region service callback
public protocol RegionsServiceDelegate: AnyObject {
    func updateRegions(regions: Set<CLRegion>)
    func didEnterPOIRegion(POIregion: Region)
    func didExitPOIRegion(POIregion: Region)
    func workZOIEnter(classifiedRegion: Region)
    func homeZOIEnter(classifiedRegion: Region)
}

/// Visit service callback
public protocol VisitServiceDelegate: AnyObject {
    func processVisit(visit: Visit)
}

/// Location manage protocal extend  LocationManagerProtocol
public protocol LocationManagerProtocol {
    var desiredAccuracy: CLLocationAccuracy { get set }
    var allowsBackgroundLocationUpdates: Bool { get set }
    var distanceFilter: CLLocationDistance { get set }
    var pausesLocationUpdatesAutomatically: Bool { get set }
    var delegate: CLLocationManagerDelegate? { get set }
    var monitoredRegions: Set<CLRegion> { get }
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func startMonitoringSignificantLocationChanges()
    func stopMonitoringSignificantLocationChanges()
    func stopMonitoring(for: CLRegion)
    func startMonitoring(for: CLRegion)
    func startMonitoringVisits()
}

extension CLLocationManager: LocationManagerProtocol {}

public extension Date {
    /// Returns the amount of seconds from another date
    func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    /// Get date in format of string: dd-MM-yy HH:mm:ss
    /// - Returns: dd-MM-yy HH:mm:ss
    func stringFromDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yy HH:mm:ss"
        let stringDate = formatter.string(from: self) // string purpose I add here
        return stringDate
    }
    
    /// Return date in fomat ISO8601
    /// - Returns: -
    func stringFromISO8601Date() -> String {
        let formatter = ISO8601DateFormatter()
        let stringDate = formatter.string(from: self) // string purpose I add here
        return stringDate
    }
}

