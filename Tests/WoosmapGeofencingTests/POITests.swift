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
        sundayDate = formatter.date(from: "2025-08-03 15:00")!
    
        weekDate = formatter.date(from: "2025-07-28 16:00")!
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testOpenForToday() throws {
        let poi = POI()
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
                "last_updated": "2025-07-28T08:27:10.122916+00:00",
                "distance": 2323.95810781,
                "open": {
                  "open_now": true,
                  "open_hours": [
                    {
                      "all-day": true
                    }
                  ],
                  "week_day": 1,
                  "current_slice": {
                    "all-day": true
                  }
                },
                "weekly_opening": {
                  "1": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "2": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "3": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "4": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "5": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "6": {
                    "hours": [
                      {
                        "end": "20:00",
                        "start": "08:00"
                      }
                    ],
                    "isSpecial": false
                  },
                  "7": {
                    "hours": [
                      {
                        "end": "20:00",
                        "start": "08:00"
                      }
                    ],
                    "isSpecial": false
                  },
                  "timezone": "Asia/Kolkata"
                },
                "opening_hours": {
                  "usual": {
                    "7": [
                      {
                        "end": "20:00",
                        "start": "08:00"
                      }
                    ],
                    "default": [
                      {
                        "all-day": true
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
        let result = poi.calculateOpenNow(timeStamp: weekDate)
        XCTAssertTrue(result)
    }
    
    func testCloseForToday() throws {
        let poi = POI()
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
                "last_updated": "2025-07-28T08:27:10.122916+00:00",
                "distance": 2323.95810781,
                "open": {
                  "open_now": true,
                  "open_hours": [
                    {
                      "all-day": true
                    }
                  ],
                  "week_day": 1,
                  "current_slice": {
                    "all-day": true
                  }
                },
                "weekly_opening": {
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
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "3": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "4": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "5": {
                    "hours": [
                        {
                          "end": "20:00",
                          "start": "08:00"
                        }
                    ],
                    "isSpecial": false
                  },
                  "6": {
                    "hours": [
                      {
                        "end": "20:00",
                        "start": "08:00"
                      }
                    ],
                    "isSpecial": false
                  },
                  "7": {
                    "hours": [
                      {
                        "end": "20:00",
                        "start": "08:00"
                      }
                    ],
                    "isSpecial": false
                  },
                  "timezone": "Asia/Kolkata"
                },
                "opening_hours": {
                  "usual": {
                    "7": [
                      {
                        "end": "20:00",
                        "start": "08:00"
                      }
                    ],
                    "default": [
                      {
                        "all-day": true
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
        let result = poi.calculateOpenNow(timeStamp: weekDate)
        XCTAssertFalse(result)
    }
    
}
