//
//  RealmLocal.swift
//  WoosmapGeofencing
//
//  Created by WGS on 26/07/23.
//  Copyright © 2023 Web Geo Services. All rights reserved.
//

import Foundation
@_implementationOnly import RealmSwift
/// Location Object
class LocationModel: Object {
    /// Date
    @objc public dynamic var date: Date? = nil
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Description
    @objc public dynamic var locationDescription: String?
    
    /// ID
    @objc public dynamic var locationId: String? = nil
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    public override init() {
        
    }
    /// Create new Location object
    /// - Parameters:
    ///   - locationId:
    ///   - latitude:
    ///   - longitude:
    ///   - dateCaptured:
    ///   - descriptionToSave:
    public init(locationId: String, latitude: Double, longitude: Double, dateCaptured: Date, descriptionToSave: String) {
        self.locationId = locationId
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.locationDescription = descriptionToSave
    }
}

/// Log Search API
class LogSearchAPIModel: Object {
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    /// last Search Location Latitude
    @objc public dynamic var lastSearchLocationLatitude: Double = 0.0
    
    /// last Search Location Longitude
    @objc public dynamic var lastSearchLocationLongitude: Double = 0.0
    
    /// last POI distance
    @objc public dynamic var lastPOI_distance: String?
    
    /// distance Limit
    @objc public dynamic var distanceLimit: String?
    
    /// location Description
    @objc public dynamic var locationDescription: String?
    
    /// distance Traveled
    @objc public dynamic var distanceTraveled: String?
    
    /// distance To Furthest Monitored POI
    @objc public dynamic var distanceToFurthestMonitoredPOI: String?
    
    /// distance Traveled Last Refresh POI Region
    @objc public dynamic var distanceTraveledLastRefreshPOIRegion: String?
    
    /// search API Last Request TimeStamp Value
    @objc public dynamic var searchAPILastRequestTimeStampValue = 0.0
    
    /// send Search API Request
    @objc public dynamic var sendSearchAPIRequest: Bool = false
    
    /// Woosmap API Key
    @objc public dynamic var woosmapAPIKey: String?
    
    /// Search API Request Enable
    @objc public dynamic var searchAPIRequestEnable: Bool = false
    
    override init() {
        
    }
    
    init(logSearchApi: LogSearchAPI) {
        self.date = logSearchApi.date
        self.latitude = logSearchApi.latitude
        self.longitude = logSearchApi.longitude
        self.lastSearchLocationLatitude = logSearchApi.lastSearchLocationLatitude
        self.lastSearchLocationLongitude = logSearchApi.lastSearchLocationLongitude
        self.lastPOI_distance = logSearchApi.lastPOI_distance
        self.distanceLimit = logSearchApi.distanceLimit
        self.locationDescription = logSearchApi.locationDescription
        self.distanceTraveled = logSearchApi.distanceTraveled
        self.distanceToFurthestMonitoredPOI = logSearchApi.distanceToFurthestMonitoredPOI
        self.distanceTraveledLastRefreshPOIRegion = logSearchApi.distanceTraveledLastRefreshPOIRegion
        self.searchAPILastRequestTimeStampValue = logSearchApi.searchAPILastRequestTimeStampValue
        self.sendSearchAPIRequest = logSearchApi.sendSearchAPIRequest
        self.woosmapAPIKey = logSearchApi.woosmapAPIKey
        self.searchAPIRequestEnable = logSearchApi.searchAPIRequestEnable
    }
}
/// Distance Object
class DistanceModel: Object {
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// origin Latitude
    @objc public dynamic var originLatitude: Double = 0.0
    
    /// origin Longitude
    @objc public dynamic var originLongitude: Double = 0.0
    
    /// Destination Latitude
    @objc public dynamic var destinationLatitude: Double = 0.0
    
    /// Destination Longitude
    @objc public dynamic var destinationLongitude: Double = 0.0
    
    /// Distance
    @objc public dynamic var distance: Int = 0
    
    /// Distance Text
    @objc public dynamic var distanceText: String?
    
    /// Duration
    @objc public dynamic var duration: Int = 0
    
    /// Duration Text
    @objc public dynamic var durationText: String?
    
    /// mode
    @objc public dynamic var mode: String?
    
    /// Units
    @objc public dynamic var units: String?
    
    /// Routing
    @objc public dynamic var routing: String?
    
    /// Status
    @objc public dynamic var status: String?
    
    /// Location Id
    @objc public dynamic var locationId: String?
    
    
    /// Create new distance object
    /// - Parameters:
    ///   - originLatitude:
    ///   - originLongitude:
    ///   - destinationLatitude:
    ///   - destinationLongitude:
    ///   - dateCaptured:
    ///   - distance:
    ///   - duration:
    ///   - mode:
    ///   - units:
    ///   - routing:
    ///   - status:
    ///   - locationId:
    convenience public init(originLatitude: Double,
                            originLongitude: Double,
                            destinationLatitude: Double,
                            destinationLongitude: Double,
                            dateCaptured: Date,
                            distance: Int,
                            duration: Int,
                            mode: String,
                            units: String,
                            routing: String,
                            status: String,
                            locationId: String) {
        self.init()
        self.originLatitude = originLatitude
        self.originLongitude = originLongitude
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.date = dateCaptured
        self.distance = distance
        self.duration = duration
        self.mode = mode
        self.units = units
        self.routing = routing
        self.status = status
        self.locationId = locationId
    }
    
}

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
    
    internal convenience init(poi: POI) {
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

/// Offline Databse: Region
class RegionModel: Object {
    
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
    
    internal convenience init(region: Region) {
        self.init()
        self.latitude = region.latitude
        self.longitude = region.longitude
        self.date = region.date
        self.didEnter = region.didEnter
        self.identifier = region.identifier
        self.radius = region.radius
        self.fromPositionDetection = region.fromPositionDetection
        self.eventName = region.eventName
    }
    
}

/// Offline Database: DurationLog
class DurationLogModel: Object {
    
    /// identifier
    @objc public dynamic var identifier: String = ""
    
    /// entryTime
    @objc public dynamic var entryTime: Date = Date()
    
    /// exitTime
    @objc public dynamic var exitTime: Date?
}

/// Visit Object
class VisitModel: Object {
    
    /// Accuracy
    @objc public dynamic var accuracy: Double = 0.0
    
    /// Arrival Date
    @objc public dynamic var arrivalDate: Date?
    
    /// Date
    @objc public dynamic var date: Date?
    
    /// Departure Date
    @objc public dynamic var departureDate: Date?
    
    /// Latitude
    @objc public dynamic var latitude: Double = 0.0
    
    /// Longitude
    @objc public dynamic var longitude: Double = 0.0
    
    /// ID
    @objc public dynamic var visitId: String?
    
    /// New Visit object
    /// - Parameters:
    ///   - visitId:
    ///   - arrivalDate:
    ///   - departureDate:
    ///   - latitude:
    ///   - longitude:
    ///   - dateCaptured:
    ///   - accuracy:
    convenience public init(visitId: String, arrivalDate: Date? = nil, departureDate: Date? = nil, latitude: Double, longitude: Double, dateCaptured: Date? = nil, accuracy: Double) {
        self.init()
        self.visitId = visitId
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.latitude = latitude
        self.longitude = longitude
        self.date = dateCaptured
        self.accuracy = accuracy
    }
    
    internal convenience init(visit: Visit) {
        self.init()
        self.visitId = visit.visitId
        self.arrivalDate = visit.arrivalDate
        self.departureDate = visit.departureDate
        self.latitude = visit.latitude
        self.longitude = visit.longitude
        self.date = visit.date
        self.accuracy = visit.accuracy
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

/// Offline Database object: RegionIsochrone
//class RegionIsochroneModel: Object {
//    
//    /// date
//    @objc public dynamic var date: Date?
//    
//    /// didEnter
//    @objc public dynamic var didEnter: Bool = false
//    
//    /// identifier
//    @objc public dynamic var identifier: String?
//    
//    /// locationId
//    @objc public dynamic var locationId: String?
//    
//    /// idStore
//    @objc public dynamic var idStore: String?
//    
//    /// latitude
//    @objc public dynamic var latitude: Double = 0.0
//    
//    /// longitude
//    @objc public dynamic var longitude: Double = 0.0
//    
//    /// radius
//    @objc public dynamic var radius: Int = 0
//    
//    /// fromPositionDetection
//    @objc public dynamic var fromPositionDetection: Bool = false
//    
//    /// distance
//    @objc public dynamic var distance = 0;
//    
//    /// distanceText
//    @objc public dynamic var distanceText = "";
//    
//    /// duration
//    @objc public dynamic var duration = 0;
//    
//    /// durationText
//    @objc public dynamic var durationText = "";
//    
//    /// type
//    @objc public dynamic var type = "isochrone";
//    
//    /// expectedAverageSpeed
//    @objc public dynamic var expectedAverageSpeed:Double = -1;
//    
//    /// Create object of RegionIsochrone
//    /// - Parameters:
//    ///   - latitude:
//    ///   - longitude:
//    ///   - radius:
//    ///   - dateCaptured:
//    ///   - identifier:
//    ///   - didEnter:
//    ///   - fromPositionDetection:
//    convenience init(latitude: Double, longitude: Double, radius: Int, dateCaptured: Date, identifier: String, didEnter: Bool, fromPositionDetection: Bool) {
//        self.init()
//        self.latitude = latitude
//        self.longitude = longitude
//        self.date = dateCaptured
//        self.didEnter = didEnter
//        self.identifier = identifier
//        self.radius = radius
//        self.fromPositionDetection = fromPositionDetection
//    }
//    
//    internal convenience init(regionIsochrone: RegionIsochrone) {
//        self.init()
//        self.latitude = regionIsochrone.latitude
//        self.longitude = regionIsochrone.longitude
//        self.date = regionIsochrone.date
//        self.didEnter = regionIsochrone.didEnter
//        self.identifier = regionIsochrone.identifier
//        self.radius = regionIsochrone.radius
//        self.fromPositionDetection = regionIsochrone.fromPositionDetection
//    }
//}
