//
//  LocationServiceCoreImpl.swift
//  WoosmapGeofencingCore
//

import Foundation
import CoreLocation
import os
import UIKit
/// Location service implementation
public class LocationServiceCoreImpl: NSObject,
                                    LocationService,
                                    LocationServiceInternal,
                                      CLLocationManagerDelegate  {
    

    /// Location Manager
    public var locationManager: LocationManagerProtocol?
    
    /// Region monitor use iOS 17 and above
    internal var monitor:RegionMonitoring?
    
    /// Current Location
    public var currentLocation: CLLocation?
    
    /// Last Location
    public var lastSearchLocation: LastSearhLocation = LastSearhLocation()
    
    /// Last POI ID
    public var lastRefreshRegionPOILocationId: String = ""
    
    /// Last Region
    public var lastRegionUpdate: Date?
    
    /// Location service callback
    public weak var locationServiceDelegate: LocationServiceDelegate?
    
    /// Search service callback
    public weak var searchAPIDataDelegate: SearchAPIDelegate?
    
    /// Distance service callback
    public weak var distanceAPIDataDelegate: DistanceAPIDelegate?
    
    /// Region service callback
    public weak var regionDelegate: RegionsServiceDelegate?
    
    /// Visit service callback
    public weak var visitDelegate: VisitServiceDelegate?
    
    
    /// New Locaion service
    /// - Parameter locationManger: location service object
    required public init(locationManger: LocationManagerProtocol?) {
        
        super.init()
        
        self.locationManager = locationManger
        initLocationManager()
        
    }
    
    /// Interrnal location manager
    public func initLocationManager() {
        guard let myLocationManager = self.locationManager else {
            return
        }
        if let backgroundMode:[String] = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String]{
            if backgroundMode.contains("location"){
                myLocationManager.allowsBackgroundLocationUpdates = true
            }
            else{
                if(WoosLog.isValidLevel(level: .warn)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.warning("\(LogEvent.w.rawValue) Permission: background location permission disabled.Please set background mode as location in your info.plist")
                    } else {
                        WoosLog.warning("Permission: background permission disabled.Please set background mode as location in your info.plist")
                    }
                }
            }
        }
        else{
            if(WoosLog.isValidLevel(level: .warn)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.warning("\(LogEvent.w.rawValue) Permission: background permission disabled.Please set background mode as location in your info.plist")
                } else {
                    WoosLog.warning("Permission: background location permission disabled.Please set background mode as location in your info.plist")
                }
            }
        }
        
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        myLocationManager.distanceFilter = 10
        myLocationManager.pausesLocationUpdatesAutomatically = true
        myLocationManager.showsBackgroundLocationIndicator = true
        myLocationManager.delegate = self
        if visitEnable {
            myLocationManager.startMonitoringVisits()
        }
        if #available(iOS 17, *) {
            monitor = RegionMonitoringImpl(self)
            //Process old data
            let lastMonitoring = myLocationManager.monitoredRegions
            lastMonitoring.forEach { region in
                if(region.identifier == region.RegionIdentifier){
                    let regionType = getRegionType(identifier: region.identifier)
                    if(regionType == .poi){
                        myLocationManager.stopMonitoring(for: region)
                        if let circleRegion = region as? CLCircularRegion{
                            Task{
                                await monitor?.addRegion(circleRegion.center, circleRegion.radius, forID: circleRegion.identifier)
                            }
                        }
                        else if let beaconRegion = region as? CLBeaconRegion{
                            monitor?.addBeaconRegion(beaconRegion.uuid, beaconRegion.major?.uint16Value, beaconRegion.minor?.uint16Value, forID: beaconRegion.identifier)
                        }
                    }
                }
            }
        }
    }
    
    /// Authorization request for location service
    func requestAuthorization () {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager?.requestAlwaysAuthorization()
        }
        else{
            if (CLLocationManager.authorizationStatus() == .denied){
                if(WoosLog.isValidLevel(level: .warn)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.warning("\(LogEvent.w.rawValue) Permission: Location permission not granted")
                    } else {
                        WoosLog.warning("Permission: Location permission not granted")
                    }
                }
            }
        }
    }
    
    /// Update Region service delegate
    /// - Parameter delegate: new callback
    func setRegionDelegate(delegate: RegionsServiceDelegate) {
        self.regionDelegate = delegate
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        delegate.updateRegions(regions: monitoredRegions)
    }
    
    /// Start Locaton service to receive new location update
    public func startUpdatingLocation() {
        self.requestAuthorization()
        DispatchQueue.global().async {
            self.locationManager?.startUpdatingLocation()
            if visitEnable {
                self.locationManager?.startMonitoringVisits()
            }
        }
        if(WoosLog.isValidLevel(level: .trace)){
            if #available(iOS 14.0, *) {
                Logger.sdklog.trace("\(LogEvent.v.rawValue) trace: Starting Location service")
            } else {
                WoosLog.trace("trace: Starting Location service")
            }
        }
    }
    
    /// Stop Locaton service to receive pause location update
    public func stopUpdatingLocation() {
        if (!modeHighfrequencyLocation) {
            DispatchQueue.global().async {
                self.locationManager?.stopUpdatingLocation()
            }
            if(WoosLog.isValidLevel(level: .trace)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.trace("\(LogEvent.v.rawValue) trace: Stoped Location service")
                } else {
                    WoosLog.trace("trace: Stoped Location service")
                }
            }
        }
    }
    
    /// Monitoring Significant Location Changes
    public func startMonitoringSignificantLocationChanges() {
        self.requestAuthorization()
        self.locationManager?.startMonitoringSignificantLocationChanges()
        if(WoosLog.isValidLevel(level: .trace)){
            if #available(iOS 14.0, *) {
                Logger.sdklog.trace("\(LogEvent.v.rawValue) trace: Requested Significant Monitoring")
            } else {
                WoosLog.trace("trace: Requested Significant Monitoring")
            }
        }
    }
    
    /// Pause Monitoring Significant Location Changes
    public func stopMonitoringSignificantLocationChanges() {
        self.locationManager?.stopMonitoringSignificantLocationChanges()
        if(WoosLog.isValidLevel(level: .trace)){
            if #available(iOS 14.0, *) {
                Logger.sdklog.trace("\(LogEvent.v.rawValue) trace: Stopped Significant Monitoring")
            } else {
                WoosLog.trace("trace: Stopped Significant Monitoring")
            }
        }
    }
    
    /// Stop mnitoring region
    public func stopMonitoringCurrentRegions() {
        if #available(iOS 17.0, *) {
            Task{
                await stopMonitoringCurrentRegions()
            }
        }
        else{
            guard let monitoredRegions = locationManager?.monitoredRegions else { return }
            Task{
                for region in monitoredRegions {
                    if getRegionType(identifier: region.identifier) == RegionType.position {
                       self.locationManager?.stopMonitoring(for: region)
                    }
                }
            }
            
            if(WoosLog.isValidLevel(level: .trace)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.trace("\(LogEvent.v.rawValue) trace: Stopped Monitoring Region")
                } else {
                    WoosLog.trace("trace: Stopped Monitoring Region")
                }
            }
        }
    }
    
    /// Start monitoring region
    func startMonitoringCurrentRegions(regions: Set<CLRegion>) {
        self.requestAuthorization()
        if #available(iOS 17.0, *) {
            Task {
                await startMonitoringCurrentRegions(regions:regions)
            }
            
        }
        else{
            self.stopMonitoringCurrentRegions()
            for region in regions {
                self.locationManager?.startMonitoring(for: region)
            }
            guard let monitoredRegions = locationManager?.monitoredRegions else { return }
            self.regionDelegate?.updateRegions(regions: monitoredRegions)
        }
        
    }
    
    /// Update region monitoring
    func updateRegionMonitoring () {
        if let deviceLocation = self.currentLocation {
            self.stopUpdatingLocation()
            if(!modeHighfrequencyLocation) {
                self.startMonitoringCurrentRegions(regions: RegionsGenerator().generateRegionsFrom(location: deviceLocation))
            }
            else{
                self.stopMonitoringCurrentRegions()
            }
        }
    }
    
    /// Callback when new location update when user in region
    /// - Parameters:
    ///   - manager: Location service
    ///   - visit: Visit info
    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        updateVisit(visit: visit)
        self.startUpdatingLocation()
    }
    private var lastfatchLocation: CLLocation?
    /// Callback when new location receive form device
    /// - Parameters:
    ///   - manager: location service
    ///   - locations: Updated locations
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let newLocation = locations.last else {
            return
        }
        if(newLocation.horizontalAccuracy > 100 ||  newLocation.horizontalAccuracy < -1){
            return //Less accurate data
        }
        //Do not consume batter if app is in background
        if(UIApplication.shared.applicationState == .background){
            guard ProcessInfo.processInfo.isLowPowerModeEnabled == false else { return } //When a user has enabled low-power mode you probably want to avoid doing API call to save CPU usage
            UIDevice.current.isBatteryMonitoringEnabled = true
            var  batteryLevel = UIDevice.current.batteryLevel
            batteryLevel =  batteryLevel == -1 ? 1.0:batteryLevel
            if(batteryLevel <= 0.1 && UIDevice.current.batteryState != UIDevice.BatteryState.charging)
            {
                return //less then 10% battery remain on device ignore background processing
            }
        }
        
        if let history = lastfatchLocation{
            let distanceupdated = history.distance(from: newLocation) // meter
            let timeskipped = newLocation.timestamp.seconds(from: history.timestamp) //Seconds
            if(distanceupdated < 5 &&  timeskipped < 5){ //Small changes
                self.stopUpdatingLocation()
                return
            }
        }
        
        lastfatchLocation = newLocation
        self.stopUpdatingLocation()
        updateLocation(locations: locations)
        DispatchQueue.global().async {
            self.updateRegionMonitoring()
        }
    }
    
    
    /// Change Auth status
    /// - Parameters:
    ///   - manager: location service
    ///   - status: new status
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if(WoosLog.isValidLevel(level: .info)){
            if #available(iOS 14.0, *) {
                Logger.sdklog.info("\(LogEvent.i.rawValue) trace: Location manager status \(status.rawValue)")
            } else {
                WoosLog.info("trace: Location manager status \(status.rawValue)")
            }
        }
    }
    
    /// Handle all error callback in case of something wrong in service
    /// - Parameters:
    ///   - manager: location service
    ///   - error: error info
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        updateLocationDidFailWithError(error: error)
    }
    
    /// Fires when User existed region that monitor by app
    /// - Parameters:
    ///   - manager: location service
    ///   - region: region info
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if #available(iOS 17.0, *) {
            //It handle by region monitoring event of CLManager
        }
        else{
            if (modeHighfrequencyLocation) {
                self.handleRegionChange()
                return
            }
            if  (getRegionType(identifier: region.identifier) == RegionType.custom) || (getRegionType(identifier: region.identifier) == RegionType.poi) {
                addRegionLogTransition(region: region, didEnter: false,fromPositionDetection: false)
            }
            self.handleRegionChange()
        }
        
    }
    
    /// Fires when User entered region that monitor by app
    /// - Parameters:
    ///   - manager: location service
    ///   - region: region info
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if #available(iOS 17.0, *) {
            //It handle by region monitoring event of CLManager
        }
        else{
            if (modeHighfrequencyLocation) {
                self.handleRegionChange()
                return
            }
            if  (getRegionType(identifier: region.identifier) == RegionType.custom) || (getRegionType(identifier: region.identifier) == RegionType.poi) {
                addRegionLogTransition(region: region, didEnter: true, fromPositionDetection: false)
            }
            self.handleRegionChange()
        }
    }
    
    /// Created new circular region
    /// - Parameters:
    ///   - identifier: ID
    ///   - center: center point
    ///   - radius: area
    /// - Returns: status
    public func addRegion(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) -> (isCreate: Bool, identifier: String) {
        guard let monitoredRegions = locationManager?.monitoredRegions else { return (false, "") }
        
        var nbrCustomGeofence = 0
        for region in monitoredRegions {
            if (getRegionType(identifier: region.identifier) == RegionType.custom) {
                nbrCustomGeofence += 1
            }
        }
        if(nbrCustomGeofence >= 3) {
            return (false, "number of custom geofence can be more than 3")
        }
        let id = RegionType.custom.rawValue + "<id>" + identifier
        
        let customRegion = CLCircularRegion(center: center, radius: radius, identifier: id )
        
        if #available(iOS 17.0, *) {
            Task{
                await monitor?.addRegion(customRegion.center, customRegion.radius, forID: customRegion.identifier)
            }
        }else{
            self.locationManager?.startMonitoring(for: customRegion)
        }
        
        checkIfUserIsInRegion(region: CLCircularRegion(center: center, radius: radius, identifier: id ))
        return (true, RegionType.custom.rawValue + "<id>" + identifier)
    }
    
    
    /// Remove circular region
    /// - Parameter identifier: ID
    public func removeRegion(identifier: String) {
        if #available(iOS 17.0, *) {
            Task{
                await removeRegion(identifier:identifier)
            }
        }
        else{
            guard let monitoredRegions = locationManager?.monitoredRegions else { return }
            for region in monitoredRegions {
                if (region.RegionIdentifier == identifier) {
                    self.locationManager?.stopMonitoring(for: region)
                    self.handleRegionChange()
                }
            }
        }
    }
    
    /// Created new circular region
    /// - Parameters:
    ///   - identifier: Id
    ///   - center: Center point
    ///   - radius: area
    ///   - type: "Curcle"
    /// - Returns: status
    public func addRegion(identifier: String, center: CLLocationCoordinate2D, radius: Int, type: String) -> (isCreate: Bool, identifier: String){
        if(type == "circle"){
            let (regionIsCreated, identifier) = addRegion(identifier: identifier, center: center, radius: Double(radius))
            return (regionIsCreated, identifier)
        }
        return (false, "the type is incorrect")
    }
    
    
    /// Remove circular region form monitoring
    /// - Parameter center: center point
    public func removeRegion(center: CLLocationCoordinate2D) {
        if #available(iOS 17.0, *) {
            Task {
                await removeRegion(center: center)
            }
        }
        else{
            guard let monitoredRegions = locationManager?.monitoredRegions else { return }
            for region in monitoredRegions {
                if let circularRegion = region as? CLCircularRegion{
                    let latRegion = circularRegion.center.latitude
                    let lngRegion = circularRegion.center.longitude
                    if center.latitude == latRegion && center.longitude == lngRegion {
                        self.locationManager?.stopMonitoring(for: region)
                        self.handleRegionChange()
                    }
                }
            }
        }
    }
    
    /// Remove circular region form monitoring
    /// - Parameter type: Type
    public func removeRegions(type: RegionType) {
        if #available(iOS 17.0, *) {
            Task{
                await removeRegions(type:type)
            }
        }
        else{
            guard let monitoredRegions = locationManager?.monitoredRegions else { return }
            if RegionType.none == type {
                for region in monitoredRegions {
                    if !region.identifier.contains(RegionType.position.rawValue) {
                        self.locationManager?.stopMonitoring(for: region)
                    }
                }
            } else {
                for region in monitoredRegions {
                    if region.identifier.contains(type.rawValue) {
                        self.locationManager?.stopMonitoring(for: region)
                    }
                }
            }
            self.handleRegionChange()
        }
    }
    
    
    /// Check user is in region
    /// - Parameter region: region info
    public func checkIfUserIsInRegion(region: CLCircularRegion) {
        guard let location = currentLocation else { return }
        if(region.contains(location.coordinate)) {
            let regionEnter = Regions.add(POIregion: region,
                                          didEnter: true,
                                          fromPositionDetection: true)
            self.regionDelegate?.didEnterPOIRegion(POIregion: regionEnter)
            if(WoosLog.isValidLevel(level: .info)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.info("\(LogEvent.i.rawValue)  Event: You are inside POI Region \(regionEnter.identifier) of type \(regionEnter.type)")
                } else {
                    WoosLog.info("Event: You are inside POI Region \(regionEnter.identifier) of type \(regionEnter.type)")
                }
            }
        }
    }
    
    /// Did Pause Location Updates
    /// - Parameter manager: Location service
    public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        self.startMonitoringSignificantLocationChanges()
    }
    
    /// Start Monitoring Region
    /// - Parameters:
    ///   - manager: Location service
    ///   - region: Regon info
    public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if(UIApplication.shared.applicationState == .background){
            return
        }
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        self.regionDelegate?.updateRegions(regions: monitoredRegions)
    }
    
    /// Update Visit details
    /// - Parameter visit: Visit Info
    func updateVisit(visit: CLVisit) {
        guard let delegate = self.visitDelegate else {
            return
        }
        if visit.horizontalAccuracy < accuracyVisitFilter {
            detectVisitInZOIClassified(visit: visit)
            let visitRecorded = Visits.add(visit: visit)
            if visitRecorded.visitId != nil {
                delegate.processVisit(visit: visitRecorded)
                if(WoosLog.isValidLevel(level: .info)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.info("\(LogEvent.d.rawValue) Event: Visit recorded at \(visitRecorded.visitId ?? "-")")
                    } else {
                        WoosLog.info("Event: Visit recored at \(visitRecorded.visitId ?? "-")")
                    }
                }
                handleVisitEvent(visit: visitRecorded)
            }
        }
    }
    
    /// Update Location detail
    /// - Parameter locations: Location info
    public func updateLocation(locations: [CLLocation]) {
        guard let delegate = self.locationServiceDelegate else {
            return
        }
        
        let location = locations.last!
        
        if let theLastLocation = self.currentLocation {
            let timeEllapsed = abs(locations.last!.timestamp.seconds(from: theLastLocation.timestamp))
            
            if theLastLocation.distance(from: location) < currentLocationDistanceFilter && timeEllapsed < currentLocationTimeFilter {
                return
            }
            
            if timeEllapsed < 2 && locations.last!.horizontalAccuracy >= theLastLocation.horizontalAccuracy {
                return
            }
        }
        // Save in database
        let locationSaved = Locations.add(locations: locations)
        
        if locationSaved.locationId == nil {
            return
        }
        
        // Retrieve location
        delegate.tracingLocation(location: locationSaved)
        if(WoosLog.isValidLevel(level: .trace)){
            if #available(iOS 14.0, *) {
                Logger.sdklog.trace("\(LogEvent.v.rawValue) \(#function) location:\(locationSaved.latitude),\(locationSaved.longitude)")
            } else {
                WoosLog.trace("\(#function) location:\(locationSaved.latitude),\(locationSaved.longitude)")
            }
        }
        
        self.currentLocation = location
        
        if searchAPIRequestEnable {
            searchAPIRequest(location: locationSaved)
        }
        checkIfPositionIsInsideGeofencingRegions(location: location)
    }
    
    public func searchAPIRequest(location: Location) {
        
#if DEBUG
        let logAPI = LogSearchAPI()
        logAPI.date = Date()
        logAPI.latitude = location.latitude
        logAPI.longitude = location.longitude
        logAPI.woosmapAPIKey = WoosmapAPIKey
        logAPI.searchAPIRequestEnable = searchAPIRequestEnable
        
        logAPI.lastSearchLocationLatitude = lastSearchLocation.latitude
        logAPI.lastSearchLocationLongitude = lastSearchLocation.longitude
#endif
        
        if(WoosmapAPIKey.isEmpty) {
            return
        }
        guard let deviceLocation = currentLocation else {return}
        
        let POIClassified = POIs.getAll().sorted(by: { $0.distance > $1.distance })
        let lastPOI = POIClassified.first
        
        if let poilog = lastPOI{
            if(WoosLog.isValidLevel(level: .trace)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.trace("\(LogEvent.v.rawValue) \(#function) Your location is near to \(poilog.idstore ?? "-") with distance \(poilog.distance) meters")
                } else {
                    WoosLog.trace("\(#function) Your location is near to \(poilog.idstore ?? "-") with distance \(poilog.distance) meters")
                }
            }
        }
        
        
#if DEBUG
        logAPI.lastPOI_distance = String(lastPOI?.distance ?? 0)
        logAPI.searchAPILastRequestTimeStampValue = searchAPILastRequestTimeStamp
#endif
        if lastPOI != nil && !location.locationId!.isEmpty && lastSearchLocation.locationId != "" {
            if(searchAPILastRequestTimeStamp > lastPOI!.date!.timeIntervalSince1970) {
                if ((searchAPILastRequestTimeStamp - lastPOI!.date!.timeIntervalSince1970) > Double(searchAPIRefreshDelayDay*3600*24)) {
    
                    sendSearchAPIRequest(location: location)
#if DEBUG
                    logAPI.sendSearchAPIRequest = true
#endif
                    return
                }
            }
            let timeEllapsed = abs(deviceLocation.timestamp.seconds(from: lastPOI!.date!))
            
            if (timeEllapsed < searchAPIRefreshDelayDay*3600*24) {
                let distanceLimit = lastPOI!.distance - lastPOI!.radius
                let distanceTraveled =  CLLocation(latitude: lastSearchLocation.latitude, longitude: lastSearchLocation.longitude).distance(from: deviceLocation)
                
                if(WoosLog.isValidLevel(level: .trace)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.trace("\(LogEvent.v.rawValue) \(#function) distanceLimit \(distanceLimit) distanceTraveled \(distanceTraveled) meters")
                    } else {
                        WoosLog.trace("\(#function) distanceLimit \(distanceLimit) distanceTraveled \(distanceTraveled) meters")
                    }
                }
#if DEBUG
                logAPI.distanceLimit = String(distanceLimit)
                logAPI.distanceTraveled = String(distanceTraveled)
#endif
                
                if (distanceTraveled > distanceLimit) && (distanceTraveled > searchAPIDistanceFilter) && (timeEllapsed > searchAPITimeFilter) {

                    sendSearchAPIRequest(location: location)
#if DEBUG
                    logAPI.sendSearchAPIRequest = true
#endif
                }
            } else {
                sendSearchAPIRequest(location: location)
#if DEBUG
                logAPI.sendSearchAPIRequest = true
#endif
            }
        } else {
            sendSearchAPIRequest(location: location)
#if DEBUG
            logAPI.sendSearchAPIRequest = true
#endif
        }
#if DEBUG
        LogSearchAPIs.add(log: logAPI)
#endif
    }
    
    /// Call Search API
    /// - Parameter location: Location object
    public func sendSearchAPIRequest(location: Location) {
        guard let delegate = self.searchAPIDataDelegate else {
            return
        }
        // Get POI nearest
        // Get the current coordiante
        let userLatitude: String = String(format: "%f", location.latitude)
        let userLongitude: String = String(format: "%f", location.longitude)
        let storeAPIUrl: String = String(format: searchWoosmapAPI, userLatitude, userLongitude)
        let locationId = location.locationId!
        self.lastSearchLocation.longitude = location.longitude
        self.lastSearchLocation.latitude = location.latitude
        self.lastSearchLocation.locationId = location.locationId ?? ""
        self.lastSearchLocation.date = location.date ?? Date()
        
        var components = URLComponents(string: storeAPIUrl)!
        
        for (key, value) in searchAPIParameters {
            if(key == "stores_by_page") {
                let storesByPage =  Int(value) ?? 0
                if (storesByPage > 20){ //todo param nbr max de poi
                    components.queryItems?.append(URLQueryItem(name: "stores_by_page", value: "20" ))
                } else {
                    components.queryItems?.append(URLQueryItem(name: "stores_by_page", value: value ))
                }
            } else {
                components.queryItems?.append(URLQueryItem(name: key, value: value ))
            }
        }
        
        if searchAPIParameters["stores_by_page"] == nil {
            components.queryItems?.append(URLQueryItem(name: "stores_by_page", value: "20" )) //todo param nbr max de poi
        }
        
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        // Call API search
        woosApiCall(with: components.url!) { [self] (data, response, error) in
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    if(WoosLog.isValidLevel(level: .error)){
                        if #available(iOS 14.0, *) {
                            Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) SearchAPI failed with status \(response.statusCode)")
                        } else {
                            WoosLog.error("\(#function) SearchAPI failed with status \(response.statusCode)")
                        }
                    }
                    delegate.serachAPIError(error: "Error Search API " + String(response.statusCode))
                    delegate.searchAPIError(error: "Error Search API " + String(response.statusCode))
                    return
                }
                if let error = error {
                    if(WoosLog.isValidLevel(level: .error)){
                        if #available(iOS 14.0, *) {
                            Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) SearchAPI Error \(error)")
                        } else {
                            WoosLog.error("\(#function) SearchAPI Error \(error)")
                        }
                    }
                } else {
                    POIs.deleteAll()
                    let pois:[POI] = POIs.addFromResponseJson(searchAPIResponse: data!, locationId: locationId)
                    if(WoosLog.isValidLevel(level: .trace)){
                        if #available(iOS 14.0, *) {
                            Logger.sdklog.trace("\(LogEvent.v.rawValue) searchAPI called. Returned \(pois.count) poi(s)")
                        } else {
                            WoosLog.trace("searchAPI called. Returned \(pois.count) poi(s)")
                        }
                    }
                    
                    if(pois.isEmpty) {
                        searchAPILastRequestTimeStamp = Date().timeIntervalSince1970
                        return
                    }
                    
                    
                    for poi in pois {
                        self.handlePOIEvent(poi: poi)
                        delegate.searchAPIResponse(poi: poi)
                    }
                    
                    
                    self.lastRefreshRegionPOILocationId = locationId
                    self.handleRefreshSystemGeofence(locationId: locationId)
                    
                }
            }
            
        }
        
    }
    
    /// Capture error while monitoring region
    /// - Parameters:
    ///   - manager: location service
    ///   - region: region info
    ///   - error: Error info
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if region is CLCircularRegion{
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) WoosmapGeofencing Error : can't create geofence \((region?.identifier ?? "")) \(error.localizedDescription)")
                } else {
                    WoosLog.error("WoosmapGeofencing Error : can't create geofence \((region?.identifier ?? "")) \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Remove old poi for given region
    /// - Parameter newPOIS: poi info
    public func removeOldPOIRegions(newPOIS: [POI]) {
        if #available(iOS 17.0, *) {
            Task {
                await removeOldPOIRegions(newPOIS:newPOIS)
            }
        }
        else{
            guard let monitoredRegions = locationManager?.monitoredRegions else { return }
            for region in monitoredRegions {
                var exist = false
                for poi in newPOIS {
                    let identifier = "<id>" + (poi.idstore ?? "") + "<id>"
                    if (region.identifier.contains(identifier)) {
                        exist = true
                    }
                }
                if(!exist) {
                    if region.identifier.contains(RegionType.poi.rawValue) {
                        self.locationManager?.stopMonitoring(for: region)
                    }
                }
            }
        }
    }
    
    /// Calculate distance between location and POI region
    /// - Parameters:
    ///   - locationOrigin: Location center
    ///   - coordinatesDest: destination array
    ///   - locationId: Locaton id
    public func calculateDistance(locationOrigin: CLLocation, coordinatesDest: [(Double, Double)], locationId: String) {
        calculateDistance(locationOrigin: locationOrigin, coordinatesDest: coordinatesDest,distanceWithTraffic:distanceWithTraffic, locationId: locationId)
    }
    
    /// Calculate distance between location and POI region
    /// - Parameters:
    ///   - locationOrigin: Location center
    ///   - coordinatesDest: destinations array
    ///   - distanceWithTraffic: Calculate distance with consideration of traffic
    ///   - distanceMode: mode
    ///   - distanceUnits: unit
    ///   - distanceLanguage: language
    public func calculateDistance(locationOrigin: CLLocation,
                                  coordinatesDest: [(Double, Double)],
                                  distanceWithTraffic : Bool = distanceWithTraffic,
                                  distanceMode: DistanceMode = distanceMode,
                                  distanceUnits: DistanceUnits = distanceUnits,
                                  distanceLanguage: String = distanceLanguage){
        calculateDistance(locationOrigin: locationOrigin,
                          coordinatesDest: coordinatesDest,
                          distanceWithTraffic:distanceWithTraffic,
                          distanceMode: distanceMode,
                          distanceUnits:distanceUnits,
                          distanceLanguage:distanceLanguage,
                          distanceMethod: distanceMethod)
    }
    
    
    /// Calculate distance between location and POI region
    /// - Parameters:
    ///   - locationOrigin: Location center
    ///   - coordinatesDest: destinations array
    ///   - distanceWithTraffic: Calculate distance with consideration of traffic
    ///   - distanceMode: mode
    ///   - distanceUnits: Unit
    ///   - distanceLanguage: language
    ///   - distanceMethod: time/distance
    ///   - locationId: Location id
    private func calculateDistance(locationOrigin: CLLocation,
                                   coordinatesDest: [(Double, Double)],
                                   distanceWithTraffic : Bool = distanceWithTraffic,
                                   distanceMode: DistanceMode = distanceMode,
                                   distanceUnits: DistanceUnits = distanceUnits,
                                   distanceLanguage: String = distanceLanguage,
                                   distanceMethod: DistanceMethod = distanceMethod,
                                   locationId: String = "") {
        
        guard let delegateDistance = self.distanceAPIDataDelegate else {
            return
        }
        
        let userLatitude: String = String(format: "%f", locationOrigin.coordinate.latitude)
        let userLongitude: String = String(format: "%f", locationOrigin.coordinate.longitude)
        
        var coordinatesDestList: [String] = []
        coordinatesDest.forEach { item in
            coordinatesDestList.append("\(item.0),\(item.1)")
        }
        let coordinateDestinations = coordinatesDestList.joined(separator: "|")
        
       
        var url = URLComponents(string: distanceWoosmapAPI)!
        var queryItem:[URLQueryItem] = [
            URLQueryItem(name: "mode", value: distanceMode.rawValue),
            URLQueryItem(name: "units", value: distanceUnits.rawValue),
            URLQueryItem(name: "language", value: distanceLanguage),
            URLQueryItem(name: "origins", value: "\(userLatitude),\(userLongitude)"),
            URLQueryItem(name: "destinations", value: coordinateDestinations),
            URLQueryItem(name: "private_key", value: WoosmapAPIKey),
            URLQueryItem(name: "elements", value: "duration_distance"),
        ]
        
        if(distanceWithTraffic) {
            let method: String = distanceMethod.rawValue
            queryItem.append(URLQueryItem(name: "method", value: method))
            queryItem.append(URLQueryItem(name: "departure_time", value: "now"))
    
        }
        url.queryItems = queryItem
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        if let url = url.url{
            // Call API Distance
            woosApiCall(with: url) {(data, response, error) in
                DispatchQueue.main.async {
                    if let response = response as? HTTPURLResponse {
                        if response.statusCode != 200 {
                            if(WoosLog.isValidLevel(level: .error)){
                                if #available(iOS 14.0, *) {
                                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) DistanceAPI failed with status \(response.statusCode)")
                                } else {
                                    WoosLog.error("\(#function) Distance failed with status \(response.statusCode)")
                                }
                            }
                            delegateDistance.distanceAPIError(error: "Error Distance API " + String(response.statusCode))
                            return
                        }
                        if let error = error {
                            if(WoosLog.isValidLevel(level: .error)){
                                if #available(iOS 14.0, *) {
                                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) DistanceAPI Error \(error)")
                                } else {
                                    WoosLog.error("\(#function) DistanceAPI Error \(error)")
                                }
                            }
                        } else {
                            let distance = Distances.addFromResponseJson(APIResponse: data!,
                                                                         locationId: locationId,
                                                                         origin: locationOrigin,
                                                                         destination: coordinatesDest,
                                                                         distanceMode: distanceMode,
                                                                         distanceUnits: distanceUnits,
                                                                         distanceLanguage: distanceLanguage,
                                                                         distanceMethod: distanceMethod)
                            delegateDistance.distanceAPIResponse(distance: distance)
                        }
                    }
                }
            }
        }
    }
    
    /// Location arror trace
    /// - Parameter error: <#error description#>
    public func tracingLocationDidFailWithError(error: Error) {
        if(WoosLog.isValidLevel(level: .error)){
            if #available(iOS 14.0, *) {
                Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) error: \(error)")
            } else {
                WoosLog.error("\(#function) error: \(error)")
            }
        }
    }
    
    
    /// Location Error
    /// - Parameter error: Error info
    func updateLocationDidFailWithError(error: Error) {
        
        guard let delegate = self.locationServiceDelegate else {
            return
        }
        
        delegate.tracingLocationDidFailWithError(error: error)
    }
    
    
    /// Handle Region Changes
    func handleRegionChange() {
        self.lastRegionUpdate = Date()
    //TODO:Add iOS 17 catch
        if #available(iOS 17.0, *) {
            //Do nothing it handle while adding new by CLMonitor
        }else{
            self.stopMonitoringCurrentRegions()
        }
        
        self.startUpdatingLocation()
        self.startMonitoringSignificantLocationChanges()
    }
    
    
    /// Region Type
    /// - Parameter identifier: ID
    /// - Returns: Region Type
    public func getRegionType(identifier: String) -> RegionType {
        if identifier.contains(RegionType.position.rawValue) {
            return RegionType.position
        } else if identifier.contains(RegionType.custom.rawValue) {
            return RegionType.custom
        } else if identifier.contains(RegionType.poi.rawValue) {
            return RegionType.poi
        }
        return RegionType.none
    }
    
    /// Test that Position Is Inside Geofencing Regions
    /// - Parameter location: location center
    public func checkIfPositionIsInsideGeofencingRegions(location: CLLocation) {
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        for region in monitoredRegions {
            if (!region.identifier.contains(RegionType.position.rawValue)) {
                if let circularRegion = region  as? CLCircularRegion {
                    let latRegion = circularRegion.center.latitude
                    let lngRegion = circularRegion.center.longitude
                    let distance = location.distance(from: CLLocation(latitude: latRegion, longitude: lngRegion)) - location.horizontalAccuracy
                    if(distance < circularRegion.radius) {
                        addRegionLogTransition(region: region, didEnter: true, fromPositionDetection: true)
                    }else {
                        addRegionLogTransition(region: region, didEnter: false, fromPositionDetection: true)
                    }
                }
            }
        }
    }
    
    /// Add Region Log Transition
    /// - Parameters:
    ///   - region: region info
    ///   - didEnter: Event
    ///   - fromPositionDetection: User Locaton
    public func addRegionLogTransition(region: CLRegion, didEnter: Bool, fromPositionDetection: Bool) {
        if let regionLog = Regions.getRegionFromId(id: region.identifier) {
            if (regionLog.date.timeIntervalSinceNow > -5) {
                return
            }
            if (regionLog.didEnter != didEnter) {
                let newRegionLog = Regions.add(POIregion: region,
                                               didEnter: didEnter,
                                               fromPositionDetection:fromPositionDetection)
                if newRegionLog.identifier != "" {
                    
                    if (didEnter) {
                        self.regionDelegate?.didEnterPOIRegion(POIregion: newRegionLog)
                    } else {
                        self.regionDelegate?.didExitPOIRegion(POIregion: newRegionLog)
                    }
                    if(WoosLog.isValidLevel(level: .info)){
                        if #available(iOS 14.0, *) {
                            Logger.sdklog.info("\(LogEvent.i.rawValue) Event: You are \(didEnter ? "Inside": "exited") POI Region \(newRegionLog.identifier) of type \(newRegionLog.type)")
                        } else {
                            WoosLog.info("Event: You are \(didEnter ? "Inside": "exited") POI Region \(newRegionLog.identifier) of type \(newRegionLog.type)")
                        }
                    }
                }
            }
        } else if (didEnter) {
            let newRegionLog = Regions.add(POIregion: region,
                                           didEnter: didEnter,
                                           fromPositionDetection:fromPositionDetection)
            if newRegionLog.identifier != "" {
                if (didEnter) {
                    self.regionDelegate?.didEnterPOIRegion(POIregion: newRegionLog)
                } else {
                    self.regionDelegate?.didExitPOIRegion(POIregion: newRegionLog)
                }
                if(WoosLog.isValidLevel(level: .info)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.info("\(LogEvent.i.rawValue) Event: You are \(didEnter ? "Inside": "exited") POI Region \(newRegionLog.identifier) of type \(newRegionLog.type)")
                    } else {
                        WoosLog.info("Event: You are \(didEnter ? "Inside": "exited") POI Region \(newRegionLog.identifier) of type \(newRegionLog.type)")
                    }
                }
            }
        }
    }
    
    
    /// Detect All Visit In ZOIClassified
    /// - Parameter visit: Visit info
    func detectVisitInZOIClassified(visit: CLVisit) {
        let visitLocation = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        let classifiedZOIs = ZOIs.getWorkHomeZOI()
        let calendar = Calendar.current
        for classifiedZOI in classifiedZOIs {
            let sMercator = SphericalMercator()
            let latitude = sMercator.y2lat(aY: classifiedZOI.lngMean)
            let longitude = sMercator.x2lon(aX: classifiedZOI.latMean)
            let distance = visitLocation.distance(from: CLLocation(latitude: latitude, longitude: longitude))
            if(distance < radiusDetectionClassifiedZOI) {
                let classifiedRegion = Region()
                classifiedRegion.date = Date()
                if(calendar.component(.year, from: visit.departureDate) != 4001) {
                    classifiedRegion.didEnter = false
                    classifiedRegion.eventName = "woos_zoi_classified_exited_event"
                } else {
                    classifiedRegion.didEnter = true
                    classifiedRegion.eventName = "woos_zoi_classified_entered_event"
                }
                classifiedRegion.radius = radiusDetectionClassifiedZOI
                classifiedRegion.latitude = latitude
                classifiedRegion.longitude = longitude
                classifiedRegion.identifier = classifiedZOI.period ?? ""
                Regions.add(classifiedRegion: classifiedRegion)
                self.regionDelegate?.homeZOIEnter(classifiedRegion: classifiedRegion)
                if(WoosLog.isValidLevel(level: .info)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.info("\(LogEvent.i.rawValue) Event: You are \(classifiedRegion.didEnter ? "inside": "exited" ) home Region")
                    } else {
                        WoosLog.info("Event: You are \(classifiedRegion.didEnter ? "inside": "exited" ) home Region")
                    }
                }
                handleZOIClassifiedEvent(region: classifiedRegion)
            }
        }
    }
    
    /// Populate Poi data properties
    /// - Parameters:
    ///   - poi: POI info
    ///   - propertyDictionary: Extra properties
    public func setDataFromPOI(poi: POI, propertyDictionary: inout Dictionary <String, Any>) {
        let jsonStructure = try? JSONDecoder().decode(JSONAny.self, from:  poi.jsonData ?? Data.init())
        if let value = jsonStructure!.value as? [String: Any] {
            if let features = value["features"] as? [[String: Any]] {
                for feature in features {
                    if let properties = feature["properties"] as? [String: Any] {
                        let idstoreFromJson = properties["store_id"] as? String ?? ""
                        if let userProperties = properties["user_properties"] as? [String: Any] {
                            if (idstoreFromJson == poi.idstore) {
                                for (key, value) in userProperties {
                                    if(userPropertiesFilter.isEmpty || userPropertiesFilter.contains(key)) {
                                        propertyDictionary["user_properties_" + key] = value
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        propertyDictionary["city"] = poi.city
        propertyDictionary["zipCode"] = poi.zipCode
        propertyDictionary["distance"] = poi.distance
        propertyDictionary["idStore"] = poi.idstore
        propertyDictionary["name"] = poi.name
        propertyDictionary["country_code"] = poi.countryCode
        propertyDictionary["tags"] = poi.tags
        propertyDictionary["types"] = poi.types
        propertyDictionary["address"] = poi.address
        propertyDictionary["contact"] = poi.contact
        propertyDictionary["openNow"] = poi.openNow
    }
    
    public func woosApiCall(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
        let bundle = Bundle(for: LocationServiceCoreImpl.self)
        var url = URLRequest(url: url)
        
        url.addValue("geofence-sdk", forHTTPHeaderField: "X-SDK-Source")
        url.addValue("iOS", forHTTPHeaderField: "X-AK-SDK-Platform")
        
        url.addValue(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0", forHTTPHeaderField: "X-AK-SDK-Version")
        url.addValue(Bundle.main.bundleIdentifier ?? "unknown", forHTTPHeaderField: "X-iOS-Identifier")
        url.addValue(WoosmapAPIKey, forHTTPHeaderField: "X-Api-Key")
        
        // Call Get API
        let apiConfigtation: URLSessionConfiguration =  URLSessionConfiguration.default// URLSession.shared.configuration
        if(UIApplication.shared.applicationState == .background){ // Add time out intervel low in case of SDK call from background thread
            url.timeoutInterval = 6
            apiConfigtation.timeoutIntervalForRequest = 6
        }
        
        let apiURLSession = URLSession(configuration: apiConfigtation)
        let task = apiURLSession.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                completionHandler(data, response, error)
            }
        }
        task.resume()
    }
    
    func woosApiAsync(with url: URL) async throws -> Data {
        let bundle = Bundle(for: LocationServiceCoreImpl.self)
        var url = URLRequest(url: url)
        
        
        url.addValue("geofence-sdk", forHTTPHeaderField: "X-SDK-Source")
        url.addValue("iOS", forHTTPHeaderField: "X-AK-SDK-Platform")
        
        url.addValue(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0", forHTTPHeaderField: "X-AK-SDK-Version")
        url.addValue(Bundle.main.bundleIdentifier ?? "unknown", forHTTPHeaderField: "X-iOS-Identifier")
        url.addValue(WoosmapAPIKey, forHTTPHeaderField: "X-Api-Key")
        
        // Call Get API
        let (data, response) =  try await URLSession.shared.data(for: url)
        if let response = response as? HTTPURLResponse {
            if(response.statusCode != 200){
                if(response.statusCode == 403){
                    throw WoosmapApiError.runtimeErrorUnAuthorize("Api Key is not valid")
                }
                else{
                    throw WoosmapApiError.runtimeError("Api is not working")
                }
            }
        }
        
        return data
    }
    
    //Empty shell method
    
    /// handle Refresh System Geofence
    /// - Parameters:
    ///   - addCustomGeofence:-
    ///   - locationId: -
    public func handleRefreshSystemGeofence(addCustomGeofence: Bool = false, locationId: String) {
    }
    
    /// handle Visit Event
    /// - Parameter visit: -
    public func handleVisitEvent(visit: Visit) {
    }
    
    /// Handle POI Event
    /// - Parameter poi: -
    public func handlePOIEvent(poi: POI) {
    }
    
    /// handle ZOI Classified Event
    /// - Parameter region: -
    public func handleZOIClassifiedEvent(region: Region) {
    }
}

extension LocationServiceCoreImpl : RegionMonitoringDelegate{
    func regionMonitoring(_ manager: any RegionMonitoring, didExitRegion region: CLRegion) {
        if (modeHighfrequencyLocation) {
            self.handleRegionChange()
            return
        }
        if  (getRegionType(identifier: region.identifier) == RegionType.custom) || (getRegionType(identifier: region.identifier) == RegionType.poi) {
            addRegionLogTransition(region: region, didEnter: false,fromPositionDetection: false)
            
        }
        self.handleRegionChange()
    }
    
    func regionMonitoring(_ manager: any RegionMonitoring, monitoringDidFailFor region: CLRegion?, withError error: any Error) {
        if region is CLCircularRegion{
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) WoosmapGeofencing Error : can't create geofence \((region?.identifier ?? "")) \(error.localizedDescription)")
                } else {
                    WoosLog.error("WoosmapGeofencing Error : can't create geofence \((region?.identifier ?? "")) \(error.localizedDescription)")
                }
            }
        }
    }
    
    func regionMonitoring(_ manager: any RegionMonitoring, didEnterRegion region: CLRegion) {
        if (modeHighfrequencyLocation) {
            self.handleRegionChange()
            return
        }
        if  (getRegionType(identifier: region.identifier) == RegionType.custom) || (getRegionType(identifier: region.identifier) == RegionType.poi) {
            addRegionLogTransition(region: region, didEnter: true, fromPositionDetection: false)
        }
        self.handleRegionChange()
    }
}

@available(iOS 17.0, *)
private extension LocationServiceCoreImpl {
    func stopMonitoringCurrentRegions() async {
        guard let monitoredRegions = await monitor?.monitoredRegions() else { return }
        for region in monitoredRegions {
            if getRegionType(identifier: region.identifier) == RegionType.position {
                await monitor?.removeRegion(region.RegionIdentifier)
            }
        }
        if(WoosLog.isValidLevel(level: .trace)){
            Logger.sdklog.trace("\(LogEvent.v.rawValue) trace: Stopped Monitoring Region")
        }
    }
    
    
    func startMonitoringCurrentRegions(regions: Set<CLRegion>) async {
        //remove old positioning region
        let regionList = await monitor?.list() ?? [:]
        for (regionKey, _ ) in  regionList{
            let regiontype = getRegionType(identifier: regionKey)
            if(regiontype == .position){
                await monitor?.removeRegion(regionKey)
            }
        }
        //remove old positioning region
        //let timeStamp = Date().timeIntervalSince1970
        for region in regions {
            if let circleR = region as? CLCircularRegion{
                await monitor?.addRegion(circleR.center,circleR.radius,forID: "\(circleR.identifier)")
            }
        }
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        self.regionDelegate?.updateRegions(regions: monitoredRegions)
    }
    
    func removeRegion(identifier: String) async {
        guard let monitoredRegions = await monitor?.monitoredRegions() else { return }
        for region in monitoredRegions {
            if (region.RegionIdentifier == identifier) {
               await monitor?.removeRegion(region.RegionIdentifier)
               self.handleRegionChange()
            }
        }
    }
    
     func removeRegion(center: CLLocationCoordinate2D) async {
        guard let monitoredRegions = await monitor?.monitoredRegions() else { return }
        for region in monitoredRegions {
            if let circularRegion = region as? CLCircularRegion{
                let latRegion = circularRegion.center.latitude
                let lngRegion = circularRegion.center.longitude
                if center.latitude == latRegion && center.longitude == lngRegion {
                    await monitor?.removeRegion(region.RegionIdentifier)
                    self.handleRegionChange()
                }
            }
        }
    }
    
    func removeRegions(type: RegionType) async {
        let regionList = await monitor?.list() ?? [:]
        if RegionType.none == type {
            for (regionkey,_) in regionList{
                if !regionkey.contains(RegionType.position.rawValue) {
                    await monitor?.removeRegion(regionkey)
                }
            }
        }
        else {
            for (regionkey,_) in regionList{
                if regionkey.contains(type.rawValue) {
                    await monitor?.removeRegion(regionkey)
                }
            }
        }
        self.handleRegionChange()
    }
    
    func removeOldPOIRegions(newPOIS: [POI]) async {
        let regionList = await self.monitor?.list() ?? [:]
        for (regionkey , _) in regionList{
            var exist = false
            for poi in newPOIS {
                let identifier = "<id>" + (poi.idstore ?? "") + "<id>"
                if (regionkey.contains(identifier)) {
                    exist = true
                }
            }
            
            if(!exist) {
                if regionkey.contains(RegionType.poi.rawValue) {
                    await self.monitor?.removeRegion(regionkey)
                }
            }
        }
    }
}
enum WoosmapApiError: Error {
    case runtimeError(String)
    case runtimeErrorUnAuthorize(String)
}
