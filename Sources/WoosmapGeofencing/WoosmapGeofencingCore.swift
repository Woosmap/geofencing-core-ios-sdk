import Foundation
import AdSupport
import CoreLocation
import RealmSwift

/**
 WoosmapGeofencingCore main class. Cannot be instanciated, use `shared` property to access singleton
 */
@objcMembers public class WoosmapGeofencingCore: NSObject {
    
    public var locationService: LocationService!
    public var sphericalMercator: SphericalMercator!
    public var visitPoint: LoadedVisit!
    var locationManager: CLLocationManager?
    
    /**
     Access singleton of Now object
     */
    public static let shared: WoosmapGeofencingCore = {
        let instance = WoosmapGeofencingCore()
        return instance
    }()
    
    /// Init class
    private override init () {
        super.init()
        self.initServices()
        self.initRealm()
    }
    
    /// Init Offline DB
    private func initRealm() {
        Realm.Configuration.defaultConfiguration = Realm.Configuration(schemaVersion: 10)
    }
    
    /// Location service
    /// - Returns: Location service object
    public func getLocationService() -> LocationServiceCoreImpl {
        return locationService as! LocationServiceCoreImpl
    }
    
    /// Get Spherical Mercator
    /// - Returns: SphericalMercator
    public func getSphericalMercator() -> SphericalMercator {
        return sphericalMercator
    }
    
    /// Visit Point
    /// - Returns: LoadedVisit
    public func getVisitPoint() -> LoadedVisit {
        return visitPoint
    }
    
    /// Activate location services
    public func initServices() {
        if self.locationService == nil {
            self.locationService = LocationServiceCoreImpl(locationManger: self.locationManager)
        }
    }
    
    /// Update Tracking
    /// - Parameter enable: status
    public func setTrackingEnable(enable: Bool) {
        if enable != getTrackingState() {
            trackingEnable = enable
            setModeHighfrequencyLocation(enable: false)
            trackingChanged(tracking: trackingEnable)
        }
    }
    
    
    /// Status for tracking
    /// - Returns: enable/disable
    public func getTrackingState() -> Bool {
        return trackingEnable
    }
    
    /// Update Woosmap Key
    /// - Parameter key: key
    public func setWoosmapAPIKey(key: String) {
        WoosmapAPIKey = key
    }
    
    /// Update Google Map Key
    /// - Parameter key: key
    public func setGMPAPIKey(key: String) {
        GoogleStaticMapKey = key
    }
    
    /// Update Search API Endpoint
    /// - Parameter api: Endpoint URL
    public func setSearchWoosmapAPI(api: String) {
        searchWoosmapAPI = api
    }
    
    /// Update Distance API endpoint
    /// - Parameter api: Endpoint URL
    public func setDistanceWoosmapAPI(api: String) {
        distanceWoosmapAPI = api
    }
    
    /// Update Traffic API endpoint
    /// - Parameter api: Endpoint URL
    public func setTrafficDistanceWoosmapAPI(api: String) {
        trafficDistanceWoosmapAPI = api
    }
    
    /// Update Provider
    /// - Parameter provider: DistanceProvider
    public func setDistanceProvider(provider: DistanceProvider) {
        if(provider != DistanceProvider.woosmapDistance || provider != DistanceProvider.woosmapTraffic){
            distanceProvider = provider
        }else {
            distanceProvider = DistanceProvider.woosmapDistance
        }
    }
    
    /// Update Distance api mode
    /// - Parameter mode: DistanceMode
    public func setDistanceAPIMode(mode: DistanceMode) {
        if(mode != DistanceMode.driving || mode != DistanceMode.cycling || mode != DistanceMode.truck || mode != DistanceMode.walking) {
            distanceMode = mode
        } else {
            distanceMode = DistanceMode.driving
        }
    }
    
    /// Update Traffic Distance Routing
    /// - Parameter routing: TrafficDistanceRouting
    public func setTrafficDistanceAPIRouting(routing: TrafficDistanceRouting) {
        if(trafficDistanceRouting != TrafficDistanceRouting.fastest || trafficDistanceRouting != TrafficDistanceRouting.balanced) {
            trafficDistanceRouting = routing
        }else {
            trafficDistanceRouting = TrafficDistanceRouting.fastest
        }
    }
    
    /// Update DistanceAPIUnits
    /// - Parameter units: DistanceUnits
    public func setDistanceAPIUnits(units: DistanceUnits) {
        if(units != DistanceUnits.metric || units != DistanceUnits.imperial) {
            distanceUnits = units
        }else {
            distanceUnits = DistanceUnits.metric
        }
    }
    
    /// Update language
    /// - Parameter language: language
    public func setDistanceAPILanguage(language: String) {
        distanceLanguage = language
    }
    
    /// Update DistanceMaxAirDistanceFilter
    /// - Parameter distance: Int
    public func setDistanceMaxAirDistanceFilter(distance: Int) {
        distanceMaxAirDistanceFilter = distance
    }
    
    /// Update Distance Time Filter
    /// - Parameter time: Int
    public func setDistanceTimeFilter(time: Int) {
        distanceTimeFilter = time
    }
    
    /// Update Position filter
    /// - Parameters:
    ///   - distance: Double
    ///   - time: Int
    public func setCurrentPositionFilter(distance: Double, time: Int) {
        currentLocationDistanceFilter = distance
        currentLocationTimeFilter = time
    }
    
    /// Update state
    /// - Parameter enable: Bool
    public func setSearchAPIRequestEnable(enable: Bool) {
        if enable != getSearchAPIRequestEnable() {
            searchAPIRequestEnable = enable
        }
    }
    
    /// SearchAPI Request Enable
    /// - Returns: Bool
    public func getSearchAPIRequestEnable() -> Bool {
        return searchAPIRequestEnable
    }
    
    /// Time Stamp for request
    /// - Returns: Timestamp
    public func getSearchAPILastRequestTimeStamp() -> Double {
        return searchAPILastRequestTimeStamp
    }
    
    /// Distance API Status
    /// - Parameter enable: Bool
    public func setDistanceAPIRequestEnable(enable: Bool) {
        if enable != getDistanceAPIRequestEnable() {
            distanceAPIRequestEnable = enable
        }
    }
    
    /// Status of Distance API RequestEnable
    /// - Returns: Bool
    public func getDistanceAPIRequestEnable() -> Bool {
        return distanceAPIRequestEnable
    }
    
    
    /// SearchAPI Refresh Delay Day
    /// - Returns: Int
    public func getSearchAPIRefreshDelayDay() -> Int {
        return searchAPIRefreshDelayDay
    }
    
    /// Update Visit Enable
    /// - Parameter enable: Bool
    public func setVisitEnable(enable: Bool) {
        visitEnable = enable
    }
    
    /// Status Visit Enable
    /// - Returns: Bool
    public func getVisitEnable() -> Bool {
        return visitEnable
    }
    
    /// Update Accuracy Visit Filter
    /// - Parameter accuracy: Double
    public func setAccuracyVisitFilter(accuracy: Double) {
        accuracyVisitFilter = accuracy
    }
    
    /// Update Creation Of ZOIEnable
    /// - Parameter enable: Bool
    public func setCreationOfZOIEnable(enable: Bool) {
        creationOfZOIEnable = enable
    }
    
    /// Update Classification
    /// - Parameter enable: Bool
    public func setClassification(enable: Bool) {
        classificationEnable = enable
    }
    
    /// Update Radius Detection Classified ZOI
    /// - Parameter radius: Double
    public func setRadiusDetectionClassifiedZOI(radius: Double) {
        radiusDetectionClassifiedZOI = radius
    }
    
    /// Start Monitoring ForeGround
    public func startMonitoringInForeGround() {
        if self.locationService == nil {
            return
        }
        self.locationService?.startUpdatingLocation()
    }
    
    /**
     Call this method from the DidFinishLaunchWithOptions method of your App Delegate
     */
    public func startMonitoringInBackground() {
        if self.locationService == nil {
            NSLog("WoosmapGeofencing is not initiated")
            return
        }
        self.locationService?.startUpdatingLocation()
        self.locationService?.startMonitoringSignificantLocationChanges()
    }
    
    /**
     Call this method from the applicationDidBecomeActive method of your App Delegate
     */
    public func didBecomeActive() {
        if self.locationService == nil {
            NSLog("WoosmapGeofencing is not initiated")
            return
        }
        let userDataCleaner = DataCleaner()
        userDataCleaner.cleanOldGeographicData()
        self.startMonitoringInBackground()
    }
    
    /// Update trackingChanged
    /// - Parameter tracking: Bool
    public func trackingChanged(tracking: Bool) {
        if !tracking {
            self._stopAllMonitoring()
        } else {
            self.locationService?.locationManager = CLLocationManager()
            self.locationService?.initLocationManager()
            self.locationService?.startUpdatingLocation()
            self.locationService?.startMonitoringSignificantLocationChanges()
        }
    }
    
    /// _stopAllMonitoring
    func _stopAllMonitoring() {
        self.locationService.stopUpdatingLocation()
        self.locationService.stopMonitoringCurrentRegions()
        self.locationService.stopMonitoringSignificantLocationChanges()
        self.locationService.locationManager = nil
        self.locationService.locationManager?.delegate = nil
    }
    
    /// _logDenied
    func _logDenied() {
        self._stopAllMonitoring()
        NSLog("User has activated DNT")
    }
    
    /// Update High frequency Location Mode
    /// - Parameter enable: Bool
    public func setModeHighfrequencyLocation(enable: Bool) {
        modeHighfrequencyLocation = enable
        
        if (modeHighfrequencyLocation == true) {
            self.locationService?.startUpdatingLocation()
            setSearchAPIRequestEnable(enable: false)
            setDistanceAPIRequestEnable(enable: false)
            setClassification(enable: false)
            self.locationService?.removeRegions(type: RegionType.position)
        } else {
            self.locationService?.stopUpdatingLocation()
            self.locationService?.startUpdatingLocation()
        }
    }
    
    /// Status High frequency Location Mode
    /// - Returns: Bool
    public func getModeHighfrequencyLocation() -> Bool {
        return modeHighfrequencyLocation
    }
    
    /// Refresh Location update
    /// - Parameter allTime: Bool
    public func refreshLocation(allTime: Bool) {
        self.locationService?.startUpdatingLocation()
        if(allTime){
            modeHighfrequencyLocation = true
        }
        
    }
    
    /// Update Search API Parameters
    /// - Parameter parameters: Customize Parameters
    public func setSearchAPIParameters(parameters : [String: String]) {
        searchAPIParameters = parameters
    }
    
    /// Update UserProperties Filter
    /// - Parameter properties: Customize Parameters
    public func setUserPropertiesFilter(properties : [String]) {
        userPropertiesFilter = properties
    }
    
}

extension WoosmapGeofencingCore {
    
    
}
