//
//  DatabaseTests.swift
//  WoosmapGeofencingTests
//
//  Copyright © 2021 Web Geo Services. All rights reserved.
//

import XCTest
import WoosmapGeofencingCore
import CoreLocation

class DatabaseTests: XCTestCase {
    let dateFormatter = DateFormatter()

    override func setUp() {
        super.setUp()
        cleanDatabase()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
        dateFormatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ssZ"
    }

    override func tearDown() {
        super.tearDown()
        cleanDatabase()
    }

    func test_add_delete_location_in_DB() {
        let lng = 3.8793329
        let lat = 43.6053862

        for _ in 0...59 {
            let location = CLLocation(latitude: lat, longitude: lng)
            let _ = Locations.add(locations: [location])
        }

        XCTAssertEqual(Locations.getAll().count, 60)
        
        Locations.deleteAll()
        
        XCTAssertEqual(Locations.getAll().count, 0)
    }
    
    func test_add_delete_POI_in_DB() {
        let lng = 3.8793329
        let lat = 43.6053862
        XCTAssertEqual(POIs.getAll().count, 0)

        for day in 0...59 {
            let id = UUID().uuidString
            let dateCaptured = Calendar.current.date(byAdding: .day, value: -day, to: Date())

            let POIToSave = POI(locationId: id, city: "CityTest", zipCode: "CodeTest", distance: 10.0, latitude: lat, longitude: lng, dateCaptured: dateCaptured, radius: 100.0)
            
            POIs.addTest(poi: POIToSave)
            
            let poiFromLocationId = POIs.getPOIbyLocationID(locationId: id)
            
            XCTAssert(poiFromLocationId?.locationId == POIToSave.locationId)
            
            let poiUpdatedWithDistance = POIs.updatePOIWithDistance(distance: 10.0, duration: "10 min", locationId: id)
            
            XCTAssertEqual(poiUpdatedWithDistance.distance, 10.0)
            XCTAssertEqual(poiUpdatedWithDistance.duration, "10 min")
            
        }

        XCTAssertEqual(POIs.getAll().count, 60)
        
        POIs.deleteAll()
        
        XCTAssertEqual(POIs.getAll().count, 0)
    }
    
    func test_add_delete_Visits_in_DB() {
        let lng = 3.8793329
        let lat = 43.6053862
        let accuracy = 20.0
        
        for day in 0...59 {
            let id = UUID().uuidString
            let dateCaptured = Calendar.current.date(byAdding: .day, value: -day, to: Date())
            
            let visitToSave = Visit(visitId: id, arrivalDate: dateCaptured, departureDate: Calendar.current.date(byAdding: .day, value: 1, to: dateCaptured!), latitude: lat, longitude: lng, dateCaptured: dateCaptured, accuracy: accuracy)

            Visits.addTest(visit: visitToSave)
            
            let visitFromId = Visits.getVisitFromUUID(id: id)
            
            XCTAssert(visitFromId?.visitId == visitToSave.visitId)
            
        }

        XCTAssert(Visits.getAll().count == 60)
        
        XCTAssert(ZOIs.getAll().count == 1)
        
        Visits.deleteAll()
        
        XCTAssert(Visits.getAll().count == 0)
        
        ZOIs.deleteAll()
        
        XCTAssert(ZOIs.getAll().count == 0)
    }
    
    func test_add_delete_region_in_DB() {
        let lng = 3.8793329
        let lat = 43.6053862

        for _ in 0...59 {
            let id = UUID().uuidString
            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: 100.0, identifier: id )
            
            let _ = Regions.add(POIregion: region, didEnter: true, fromPositionDetection: false)
        }

        XCTAssert(Regions.getAll().count == 60)
        
        Regions.deleteAll()
        
        XCTAssert(Regions.getAll().count == 0)
    }

    func cleanDatabase() {
        Locations.deleteAll()
        Visits.deleteAll()
        ZOIs.deleteAll()
        POIs.deleteAll()
    }

}
