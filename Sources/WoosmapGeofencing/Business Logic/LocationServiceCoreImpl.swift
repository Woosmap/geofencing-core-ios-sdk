//
//  LocationServiceCoreImpl.swift
//  WoosmapGeofencingCore
//

import Foundation
import CoreLocation

/// Location service implementation
open class LocationServiceCoreImpl: NSObject,
                                    LocationService,
                                    LocationServiceInternal,
                                    CLLocationManagerDelegate  {
    
    /// Location Manager
    public var locationManager: LocationManagerProtocol?
    
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
        guard var myLocationManager = self.locationManager else {
            return
        }
        
        myLocationManager.allowsBackgroundLocationUpdates = true
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        myLocationManager.distanceFilter = 10
        myLocationManager.pausesLocationUpdatesAutomatically = true
        myLocationManager.delegate = self
        if visitEnable {
            myLocationManager.startMonitoringVisits()
        }
    }
    
    /// Authorization request for location service
    func requestAuthorization () {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager?.requestAlwaysAuthorization()
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
        self.locationManager?.startUpdatingLocation()
        if visitEnable {
            self.locationManager?.startMonitoringVisits()
        }
    }
    
    /// Stop Locaton service to receive pause location update
    public func stopUpdatingLocation() {
        if (!modeHighfrequencyLocation) {
            self.locationManager?.stopUpdatingLocation()
        }
    }
    
    /// Monitoring Significant Location Changes
    public func startMonitoringSignificantLocationChanges() {
        self.requestAuthorization()
        self.locationManager?.startMonitoringSignificantLocationChanges()
    }
    
    /// Pause Monitoring Significant Location Changes
    public func stopMonitoringSignificantLocationChanges() {
        self.locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    /// Stop mnitoring region
    public func stopMonitoringCurrentRegions() {
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        for region in monitoredRegions {
            if getRegionType(identifier: region.identifier) == RegionType.position {
                self.locationManager?.stopMonitoring(for: region)
            }
        }
    }
    
    /// Start monitoring region
    func startMonitoringCurrentRegions(regions: Set<CLRegion>) {
        self.requestAuthorization()
        for region in regions {
            self.locationManager?.startMonitoring(for: region)
        }
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        self.regionDelegate?.updateRegions(regions: monitoredRegions)
    }
    
    /// Update region monitoring
    func updateRegionMonitoring () {
        if self.currentLocation != nil {
            self.stopUpdatingLocation()
            self.stopMonitoringCurrentRegions()
            if(!modeHighfrequencyLocation) {
                self.startMonitoringCurrentRegions(regions: RegionsGenerator().generateRegionsFrom(location: self.currentLocation!))
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
    
    /// Callback when new location receive form device
    /// - Parameters:
    ///   - manager: location service
    ///   - locations: Updated locations
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard locations.last != nil else {
            return
        }
        
        self.stopUpdatingLocation()
        updateLocation(locations: locations)
        self.updateRegionMonitoring()
    }
    
    
    /// Change Auth status
    /// - Parameters:
    ///   - manager: location service
    ///   - status: new status
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
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
        if (modeHighfrequencyLocation) {
            self.handleRegionChange()
            return
        }
        if  (getRegionType(identifier: region.identifier) == RegionType.custom) || (getRegionType(identifier: region.identifier) == RegionType.poi) {
            addRegionLogTransition(region: region, didEnter: false,fromPositionDetection: false)
        }
        self.handleRegionChange()
    }
    
    /// Fires when User entered region that monitor by app
    /// - Parameters:
    ///   - manager: location service
    ///   - region: region info
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if (modeHighfrequencyLocation) {
            self.handleRegionChange()
            return
        }
        if  (getRegionType(identifier: region.identifier) == RegionType.custom) || (getRegionType(identifier: region.identifier) == RegionType.poi) {
            addRegionLogTransition(region: region, didEnter: true, fromPositionDetection: false)
        }
        self.handleRegionChange()
    }
    
    /// Created new circular region
    /// - Parameters:
    ///   - identifier: ID
    ///   - center: center point
    ///   - radius: area
    /// - Returns: status
    open func addRegion(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) -> (isCreate: Bool, identifier: String) {
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
        self.locationManager?.startMonitoring(for: CLCircularRegion(center: center, radius: radius, identifier: id ))
        checkIfUserIsInRegion(region: CLCircularRegion(center: center, radius: radius, identifier: id ))
        return (true, RegionType.custom.rawValue + "<id>" + identifier)
    }
    
    
    /// Remove circular region
    /// - Parameter identifier: ID
    public func removeRegion(identifier: String) {
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        for region in monitoredRegions {
            if (region.identifier == identifier) {
                self.locationManager?.stopMonitoring(for: region)
                self.handleRegionChange()
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
    open func addRegion(identifier: String, center: CLLocationCoordinate2D, radius: Int, type: String) -> (isCreate: Bool, identifier: String){
        if(type == "circle"){
            let (regionIsCreated, identifier) = addRegion(identifier: identifier, center: center, radius: Double(radius))
            return (regionIsCreated, identifier)
        }
        return (false, "the type is incorrect")
    }
    
    
    /// Remove circular region form monitoring
    /// - Parameter center: center point
    public func removeRegion(center: CLLocationCoordinate2D) {
        guard let monitoredRegions = locationManager?.monitoredRegions else { return }
        for region in monitoredRegions {
            let latRegion = (region as! CLCircularRegion).center.latitude
            let lngRegion = (region as! CLCircularRegion).center.longitude
            if center.latitude == latRegion && center.longitude == lngRegion {
                self.locationManager?.stopMonitoring(for: region)
                self.handleRegionChange()
            }
        }
    }
    
    /// Remove circular region form monitoring
    /// - Parameter type: Type
    public func removeRegions(type: RegionType) {
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
    
    
    /// Check user is in region
    /// - Parameter region: region info
    open func checkIfUserIsInRegion(region: CLCircularRegion) {
        guard let location = currentLocation else { return }
        if(region.contains(location.coordinate)) {
            let regionEnter = Regions.add(POIregion: region,
                                          didEnter: true,
                                          fromPositionDetection: true)
            self.regionDelegate?.didEnterPOIRegion(POIregion: regionEnter)
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
                handleVisitEvent(visit: visitRecorded)
            }
        }
    }
    
    /// Update Location detail
    /// - Parameter locations: Location info
    open func updateLocation(locations: [CLLocation]) {
        guard let delegate = self.locationServiceDelegate else {
            return
        }
        
        let location = locations.last!
        
        if self.currentLocation != nil {
            
            let theLastLocation = self.currentLocation!
            
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
        
        self.currentLocation = location
        
        if searchAPIRequestEnable {
            searchAPIRequest(location: locationSaved)
        }
        checkIfPositionIsInsideGeofencingRegions(location: location)
    }
    
    open func searchAPIRequest(location: Location) {
#if DEBUG
        let logAPI = LogSearchAPI()
        logAPI.date = Date()
        logAPI.latitude = location.latitude
        logAPI.longitude = location.longitude
        logAPI.woosmapAPIKey = WoosmapAPIKey
        logAPI.searchAPIRequestEnable = searchAPIRequestEnable
        NSLog("=>>>>>> searchAPIRequest WoosmapKey = %@", WoosmapAPIKey)
        logAPI.lastSearchLocationLatitude = lastSearchLocation.latitude
        logAPI.lastSearchLocationLongitude = lastSearchLocation.longitude
#endif
        
        if(WoosmapAPIKey.isEmpty) {
            return
        }
        
        let POIClassified = POIs.getAll().sorted(by: { $0.distance > $1.distance })
        let lastPOI = POIClassified.first
#if DEBUG
        NSLog("=>>>>>> lastPOI distance = %@", String(lastPOI?.distance ?? 0))
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
            
            let timeEllapsed = abs(currentLocation!.timestamp.seconds(from: lastPOI!.date!))
            
            if (timeEllapsed < searchAPIRefreshDelayDay*3600*24) {
                let distanceLimit = lastPOI!.distance - lastPOI!.radius
                let distanceTraveled =  CLLocation(latitude: lastSearchLocation.latitude, longitude: lastSearchLocation.longitude).distance(from: currentLocation!)
#if DEBUG
                NSLog("=>>>>>> distanceLimit = %@", String(distanceLimit))
                NSLog("=>>>>>> distanceTraveled = %@", String(distanceTraveled))
                logAPI.distanceLimit = String(distanceLimit)
                logAPI.distanceTraveled = String(distanceTraveled)
#endif
                
                if (distanceTraveled > distanceLimit) && (distanceTraveled > searchAPIDistanceFilter) && (timeEllapsed > searchAPITimeFilter) {
                    POIs.deleteAll()
                    sendSearchAPIRequest(location: location)
#if DEBUG
                    logAPI.sendSearchAPIRequest = true
#endif
                }
            } else {
                POIs.deleteAll()
                sendSearchAPIRequest(location: location)
#if DEBUG
                logAPI.sendSearchAPIRequest = true
#endif
            }
        } else {
            POIs.deleteAll()
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
        let url = URLRequest(url: components.url!)
        
        // Call API search
        let task = URLSession.shared.dataTask(with: url) { [self] (data, response, error) in
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    NSLog("statusCode: \(response.statusCode)")
                    delegate.serachAPIError(error: "Error Search API " + String(response.statusCode))
                    return
                }
                if let error = error {
                    NSLog("error: \(error)")
                } else {
                    print("=>>>>>> searchAPIRequest")
                    let pois:[POI] = POIs.addFromResponseJson(searchAPIResponse: data!, locationId: locationId)
                    
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
        task.resume()
        
    }
    
    /// Capture error while monitoring region
    /// - Parameters:
    ///   - manager: location service
    ///   - region: region info
    ///   - error: Error info
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("WoosmapGeofencing Error : can't create geofence " + (region?.identifier ?? "") + error.localizedDescription)
    }
    
    /// Remove old poi for given region
    /// - Parameter newPOIS: poi info
    open func removeOldPOIRegions(newPOIS: [POI]) {
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
    
    /// Calculate distance between location and POI region
    /// - Parameters:
    ///   - locationOrigin: Location center
    ///   - coordinatesDest: destination array
    ///   - locationId: Locaton id
    public func calculateDistance(locationOrigin: CLLocation, coordinatesDest: [(Double, Double)], locationId: String) {
        calculateDistance(locationOrigin: locationOrigin, coordinatesDest: coordinatesDest,distanceProvider:distanceProvider, locationId: locationId)
    }
    
    /// Calculate distance between location and POI region
    /// - Parameters:
    ///   - locationOrigin: Location center
    ///   - coordinatesDest: destinations array
    ///   - distanceProvider: provider
    ///   - distanceMode: mode
    ///   - distanceUnits: unit
    ///   - distanceLanguage: language
    public func calculateDistance(locationOrigin: CLLocation,
                                  coordinatesDest: [(Double, Double)],
                                  distanceProvider : DistanceProvider = distanceProvider,
                                  distanceMode: DistanceMode = distanceMode,
                                  distanceUnits: DistanceUnits = distanceUnits,
                                  distanceLanguage: String = distanceLanguage){
        calculateDistance(locationOrigin: locationOrigin,
                          coordinatesDest: coordinatesDest,
                          distanceProvider:distanceProvider,
                          distanceMode: distanceMode,
                          distanceUnits:distanceUnits,
                          distanceLanguage:distanceLanguage,
                          trafficDistanceRouting: trafficDistanceRouting)
    }
    
    
    /// Calculate distance between location and POI region
    /// - Parameters:
    ///   - locationOrigin: Location center
    ///   - coordinatesDest: destinations array
    ///   - distanceProvider: provider
    ///   - distanceMode: mode
    ///   - distanceUnits: Unit
    ///   - distanceLanguage: language
    ///   - trafficDistanceRouting: traffic
    ///   - locationId: Location id
    private func calculateDistance(locationOrigin: CLLocation,
                                   coordinatesDest: [(Double, Double)],
                                   distanceProvider : DistanceProvider = distanceProvider,
                                   distanceMode: DistanceMode = distanceMode,
                                   distanceUnits: DistanceUnits = distanceUnits,
                                   distanceLanguage: String = distanceLanguage,
                                   trafficDistanceRouting: TrafficDistanceRouting = trafficDistanceRouting,
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
        
        var storeAPIUrl = ""
        if(distanceProvider == DistanceProvider.woosmapDistance) {
            storeAPIUrl = String(format: distanceWoosmapAPI, distanceMode.rawValue, distanceUnits.rawValue, distanceLanguage, userLatitude, userLongitude, coordinateDestinations)
        } else {
            storeAPIUrl = String(format: trafficDistanceWoosmapAPI, distanceMode.rawValue, distanceUnits.rawValue,trafficDistanceRouting.rawValue,distanceLanguage, userLatitude, userLongitude, coordinateDestinations)
        }
        
        let url = URL(string: storeAPIUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        
        // Call API Distance
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                if let response = response as? HTTPURLResponse {
                    if response.statusCode != 200 {
                        NSLog("statusCode: \(response.statusCode)")
                        delegateDistance.distanceAPIError(error: "Error Distance API " + String(response.statusCode))
                        return
                    }
                    if let error = error {
                        NSLog("error: \(error)")
                    } else {
                        let distance = Distances.addFromResponseJson(APIResponse: data!,
                                                                     locationId: locationId,
                                                                     origin: locationOrigin,
                                                                     destination: coordinatesDest,
                                                                     distanceProvider: distanceProvider,
                                                                     distanceMode: distanceMode,
                                                                     distanceUnits: distanceUnits,
                                                                     distanceLanguage: distanceLanguage,
                                                                     trafficDistanceRouting: trafficDistanceRouting)
                        delegateDistance.distanceAPIResponse(distance: distance)
                        
                    }
                }
            }
        }
        task.resume()
        
    }
    
    /// Location arror trace
    /// - Parameter error: <#error description#>
    public func tracingLocationDidFailWithError(error: Error) {
        print("\(error)")
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
        self.stopMonitoringCurrentRegions()
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
                let latRegion = (region as! CLCircularRegion).center.latitude
                let lngRegion = (region as! CLCircularRegion).center.longitude
                let distance = location.distance(from: CLLocation(latitude: latRegion, longitude: lngRegion)) - location.horizontalAccuracy
                if(distance < (region as! CLCircularRegion).radius) {
                    addRegionLogTransition(region: region, didEnter: true, fromPositionDetection: true)
                }else {
                    addRegionLogTransition(region: region, didEnter: false, fromPositionDetection: true)
                }
            }
        }
    }
    
    /// Add Region Log Transition
    /// - Parameters:
    ///   - region: region info
    ///   - didEnter: Event
    ///   - fromPositionDetection: User Locaton
    open func addRegionLogTransition(region: CLRegion, didEnter: Bool, fromPositionDetection: Bool) {
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
    
    //Empty shell method
    
    /// handle Refresh System Geofence
    /// - Parameters:
    ///   - addCustomGeofence:-
    ///   - locationId: -
    open func handleRefreshSystemGeofence(addCustomGeofence: Bool = false, locationId: String) {
    }
    
    /// handle Visit Event
    /// - Parameter visit: -
    open func handleVisitEvent(visit: Visit) {
    }
    
    /// Handle POI Event
    /// - Parameter poi: -
    open func handlePOIEvent(poi: POI) {
    }
    
    /// handle ZOI Classified Event
    /// - Parameter region: -
    open func handleZOIClassifiedEvent(region: Region) {
    }
}

