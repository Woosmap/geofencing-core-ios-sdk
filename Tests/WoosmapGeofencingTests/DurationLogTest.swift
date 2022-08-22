//
//  DurationLogTest.swift
//  WoosmapGeofencingCoreTests
//
//  Created by WGS on 12/08/22.
//  Copyright © 2022 Web Geo Services. All rights reserved.
//

import XCTest
import RealmSwift
@testable import WoosmapGeofencingCore

class DurationLogTest: XCTestCase {
    let dateFormatter = DateFormatter()
    
    override func setUp() {
        super.setUp()
        let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                                     appropriateFor: nil, create: false)
        let url = documentDirectory!.appendingPathComponent("durationlog\(Date.timeIntervalBetween1970AndReferenceDate).realm")
        Realm.Configuration.defaultConfiguration.fileURL = url
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
        dateFormatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ssZ"
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        DurationLogs.deleteAll()
    }

    func testEntryEvent() throws {
        DurationLogs.addEntryLog(identifier: "test1")
        let count = DurationLogs.getAll().count
        XCTAssert(count > 0)
        
    }
    
    func testExitEvent() throws {
        let exp = expectation(description: "Test after 5 seconds")
        DurationLogs.addEntryLog(identifier: "test1")
        let result = XCTWaiter.wait(for: [exp], timeout: 5.0)
        if result == XCTWaiter.Result.timedOut {
            let duration = DurationLogs.addExitLog(identifier: "test1")
            XCTAssert(duration > 5)
         } else {
             XCTFail("Delay interrupted")
         }
        
    }
    func testExitEventWithoutEntryLog() throws {
        let exp = expectation(description: "Test after 5 seconds")
        let result = XCTWaiter.wait(for: [exp], timeout: 5.0)
        if result == XCTWaiter.Result.timedOut {
            let duration = DurationLogs.addExitLog(identifier: "testNotFound")
            print("time spend \(duration)")
            XCTAssert(duration == 0)
         } else {
             XCTFail("Delay interrupted")
         }
        
    }
    
    func testDuplicateEntryEvent() throws {
        let exp = expectation(description: "Test after 5 seconds")
        let expAgain = expectation(description: "Test after 5 seconds")
        DurationLogs.addEntryLog(identifier: "test1")
        let result = XCTWaiter.wait(for: [exp], timeout: 5.0)
        if result == XCTWaiter.Result.timedOut {
            //Duplicate ID
            DurationLogs.addEntryLog(identifier: "test1")
            let resultAgain = XCTWaiter.wait(for: [expAgain], timeout: 5.0)
            if resultAgain == XCTWaiter.Result.timedOut {
            let duration = DurationLogs.addExitLog(identifier: "test1")
            XCTAssert(duration > 10)
                let durationNew = DurationLogs.addExitLog(identifier: "test1")
                XCTAssert(durationNew > 5)
            }
            else{
                XCTFail("Delay interrupted")
            }
         } else {
             XCTFail("Delay interrupted")
         }
    }
}
