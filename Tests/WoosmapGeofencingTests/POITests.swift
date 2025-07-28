//
//  POITests.swift
//  WoosmapGeofencingCoreTests
//
//  Created by WGS on 28/07/25.
//  Copyright © 2025 Web Geo Services. All rights reserved.
//

import Foundation
import XCTest
@testable import WoosmapGeofencingCore

class POIDBTest: XCTestCase {
    
    
    var sundayDate: Date = Date()
    var weekDate: Date = Date()
    
    override func setUp() {
        super.setUp()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata") // Set your desired timezone
        sundayDate = formatter.date(from: "2025-08-03 10:00")!
    
        weekDate = formatter.date(from: "2025-07-28 10:00")!
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testOpenForToday() throws {
        let poi = POI()
        
        /// Default 08 to 13 sunday 10 to 14
        let testdata = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {
                        "store_id": "18409_190784",
                        "name": "Elphinstone Road",
                        "contact": {},
                        "address": {
                            "lines": [
                                "Indiabulls Finance Centre",
                                "Elphinstone Road (West)"
                            ],
                            "country_code": null,
                            "city": "Mumbai",
                            "zipcode": "400013"
                        },
                        "user_properties": {
                            "radius": 13
                        },
                        "tags": [
                            "station",
                            "Group",
                            "Office"
                        ],
                        "types": [],
                        "last_updated": "2025-07-28T13:01:35.696876+00:00",
                        "distance": 2323.95810781,
                        "open": {
                            "open_now": false,
                            "open_hours": [
                                {
                                    "end": "13:00",
                                    "start": "08:00"
                                }
                            ],
                            "week_day": 1,
                            "next_opening": {
                                "day": "2025-07-29",
                                "start": "08:00",
                                "end": "13:00"
                            }
                        },
                        "weekly_opening": {
                            "timezone": "Asia/Kolkata",
                            "1": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "2": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "3": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "4": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "5": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "6": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "7": {
                                "hours": [
                                    {
                                        "end": "14:00",
                                        "start": "10:00"
                                    }
                                ],
                                "isSpecial": false
                            }
                        },
                        "opening_hours": {
                            "usual": {
                                "7": [
                                    {
                                        "end": "14:00",
                                        "start": "10:00"
                                    }
                                ],
                                "default": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ]
                            },
                            "special": {},
                            "timezone": "Asia/Kolkata",
                            "temporary_closure": []
                        }
                    },
                    "geometry": {
                        "type": "Point",
                        "coordinates": [
                            72.835595,
                            19.009997
                        ]
                    }
                }
            ]
        }
        """
        poi.jsonData = testdata.data(using: .utf8)!
        let result = poi.calculateOpenNow(timeStamp: weekDate) //10 AM
        XCTAssertTrue(result)
        

        let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: weekDate)!
        let result1 = poi.calculateOpenNow(timeStamp: oneHourLater) //11 AM
        XCTAssertTrue(result1)
        
        let threeHourLater = Calendar.current.date(byAdding: .hour, value: 3, to: weekDate)!
        let result2 = poi.calculateOpenNow(timeStamp: threeHourLater) //13 AM
        XCTAssertTrue(result2)
        
        let fourHourLater = Calendar.current.date(byAdding: .hour, value: 4, to: weekDate)!
        let result3 = poi.calculateOpenNow(timeStamp: fourHourLater) //14 AM
        XCTAssertFalse(result3)
        
        let result4 = poi.calculateOpenNow(timeStamp: sundayDate) //sunday 10 AM
        XCTAssertTrue(result4)
        
        let oneHourbefore = Calendar.current.date(byAdding: .hour, value: -1, to: sundayDate)!
        let result5 = poi.calculateOpenNow(timeStamp: oneHourbefore) //sunday 9 AM
        XCTAssertFalse(result5)
        
    }
    
    
    
    func testSpecialDay() throws {
        let poi = POI()
        
        /// Default 08 to 13
        /// sunday 10 to 14
        ///
        /// Special day     28 16 -16 open
        ///            29 close all day
        let testdata = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {
                        "store_id": "18409_190784",
                        "name": "Elphinstone Road",
                        "contact": {},
                        "address": {
                            "lines": [
                                "Indiabulls Finance Centre",
                                "Elphinstone Road (West)"
                            ],
                            "country_code": null,
                            "city": "Mumbai",
                            "zipcode": "400013"
                        },
                        "user_properties": {
                            "radius": 13
                        },
                        "tags": [
                            "station",
                            "Group",
                            "Office"
                        ],
                        "types": [],
                        "last_updated": "2025-07-28T13:15:37.411637+00:00",
                        "distance": 2323.95810781,
                        "open": {
                            "open_now": false,
                            "open_hours": [
                                {
                                    "end": "16:00",
                                    "start": "15:00"
                                }
                            ],
                            "week_day": 1,
                            "next_opening": {
                                "day": "2025-07-30",
                                "start": "08:00",
                                "end": "13:00"
                            }
                        },
                        "weekly_opening": {
                            "timezone": "Asia/Kolkata",
                            "1": {
                                "hours": [
                                    {
                                        "end": "16:00",
                                        "start": "15:00"
                                    }
                                ],
                                "isSpecial": true
                            },
                            "2": {
                                "hours": [],
                                "isSpecial": true
                            },
                            "3": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "4": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "5": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "6": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "7": {
                                "hours": [
                                    {
                                        "end": "14:00",
                                        "start": "10:00"
                                    }
                                ],
                                "isSpecial": false
                            }
                        },
                        "opening_hours": {
                            "usual": {
                                "7": [
                                    {
                                        "end": "14:00",
                                        "start": "10:00"
                                    }
                                ],
                                "default": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ]
                            },
                            "special": {
                                "2025-07-28": [
                                    {
                                        "end": "16:00",
                                        "start": "15:00"
                                    }
                                ],
                                "2025-07-29": []
                            },
                            "timezone": "Asia/Kolkata",
                            "temporary_closure": []
                        }
                    },
                    "geometry": {
                        "type": "Point",
                        "coordinates": [
                            72.835595,
                            19.009997
                        ]
                    }
                }
            ]
        }
        """
        poi.jsonData = testdata.data(using: .utf8)!
        let result = poi.calculateOpenNow(timeStamp: weekDate) //10 AM
        XCTAssertFalse(result)
        
        let fiveHourAfter = Calendar.current.date(byAdding: .hour, value: 5, to: weekDate)!
        let result1 = poi.calculateOpenNow(timeStamp: fiveHourAfter) // 3 PM
        XCTAssertTrue(result1)
        
        let nextDayAfter = Calendar.current.date(byAdding: .day, value: 1, to: weekDate)!
        let result2 = poi.calculateOpenNow(timeStamp: nextDayAfter) //  next day 10 AM
        XCTAssertFalse(result2)
        
        let next2DayAfter = Calendar.current.date(byAdding: .day, value: 2, to: weekDate)!
        let result3 = poi.calculateOpenNow(timeStamp: next2DayAfter) //  on 30th day 10 AM
        XCTAssertTrue(result3)
    }
    
    
    func testTemporaryCloseDay() throws {
        let poi = POI()
        
        /// Default 08 to 13
        /// sunday 10 to 14
        ///
        /// TemporaryClose     28 -29 close all day
        ///               31 close all day
        let testdata = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {
                        "store_id": "18409_190784",
                        "name": "Elphinstone Road",
                        "contact": {},
                        "address": {
                            "lines": [
                                "Indiabulls Finance Centre",
                                "Elphinstone Road (West)"
                            ],
                            "country_code": null,
                            "city": "Mumbai",
                            "zipcode": "400013"
                        },
                        "user_properties": {
                            "radius": 13
                        },
                        "tags": [
                            "station",
                            "Group",
                            "Office"
                        ],
                        "types": [],
                        "last_updated": "2025-07-28T13:28:14.594150+00:00",
                        "distance": 2323.95810781,
                        "open": {
                            "open_now": false,
                            "open_hours": [],
                            "week_day": 1,
                            "next_opening": {
                                "day": "2025-07-30",
                                "start": "08:00",
                                "end": "13:00"
                            }
                        },
                        "weekly_opening": {
                            "timezone": "Asia/Kolkata",
                            "1": {
                                "hours": [],
                                "isSpecial": true
                            },
                            "2": {
                                "hours": [],
                                "isSpecial": true
                            },
                            "3": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "4": {
                                "hours": [],
                                "isSpecial": true
                            },
                            "5": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "6": {
                                "hours": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ],
                                "isSpecial": false
                            },
                            "7": {
                                "hours": [
                                    {
                                        "end": "14:00",
                                        "start": "10:00"
                                    }
                                ],
                                "isSpecial": false
                            }
                        },
                        "opening_hours": {
                            "usual": {
                                "7": [
                                    {
                                        "end": "14:00",
                                        "start": "10:00"
                                    }
                                ],
                                "default": [
                                    {
                                        "end": "13:00",
                                        "start": "08:00"
                                    }
                                ]
                            },
                            "special": {},
                            "timezone": "Asia/Kolkata",
                            "temporary_closure": [
                                {
                                    "end": "2025-07-29",
                                    "start": "2025-07-28"
                                },
                                {
                                    "end": "2025-07-31",
                                    "start": "2025-07-31"
                                }
                            ]
                        }
                    },
                    "geometry": {
                        "type": "Point",
                        "coordinates": [
                            72.835595,
                            19.009997
                        ]
                    }
                }
            ]
        }
        """
        poi.jsonData = testdata.data(using: .utf8)!
        let result = poi.calculateOpenNow(timeStamp: weekDate) //10 AM
        XCTAssertFalse(result)
        
        let nextDayAfter = Calendar.current.date(byAdding: .day, value: 1, to: weekDate)!
        let result1 = poi.calculateOpenNow(timeStamp: nextDayAfter) //  next day 10 AM
        XCTAssertFalse(result1)

        let next2DayAfter = Calendar.current.date(byAdding: .day, value: 2, to: weekDate)!
        let result2 = poi.calculateOpenNow(timeStamp: next2DayAfter) //  on 30th day 10 AM
        XCTAssertTrue(result2)
        
        let next3DayAfter = Calendar.current.date(byAdding: .day, value: 2, to: weekDate)!
        let result3 = poi.calculateOpenNow(timeStamp: next3DayAfter) //  on 31th day 10 AM
        XCTAssertTrue(result3)
    }
}
