//
//  DataCleaner.swift
//  WoosmapGeofencing
//

import Foundation
@_implementationOnly import RealmSwift

/// Data cleaning form offline databse
public class DataCleaner {
    
    public init() {}
    
    /// Delete old data
    public func cleanOldGeographicData() {
        let lastDateUpdate = UserDefaults.standard.object(forKey: "lastDateUpdate") as? Date
        
        if lastDateUpdate != nil {
            let dateComponents = Calendar.current.dateComponents([.day], from: lastDateUpdate!, to: Date())
            // update date if no updating since 1 day
            if dateComponents.day! >= 1 {
                // Cleanning database
                do {
                    let realm = try Realm()
                    let limitDate = Calendar.current.date(byAdding: .day, value: -dataDurationDelay, to: Date())
                    let predicate = NSPredicate(format: "(date <= %@)", limitDate! as CVarArg)
                    let locationFetchedResults = realm.objects(LocationModel.self).filter(predicate)
                    let poiFetchedResults = realm.objects(POIModel.self).filter(predicate)
                    let distanceFetchedResults = realm.objects(DistanceModel.self).filter(predicate)
                    let regionFetchedResults = realm.objects(RegionModel.self).filter(predicate)
                    let visitFetchedResults = realm.objects(VisitModel.self).filter(predicate)
                    if !visitFetchedResults.isEmpty {
                        ZOIs.updateZOI(visits: Array(visitFetchedResults).map({ visitModel in
                            return Visit(visitModel: visitModel)
                        }))
                    }
                    realm.beginWrite()
                    realm.delete(locationFetchedResults)
                    realm.delete(poiFetchedResults)
                    realm.delete(visitFetchedResults)
                    realm.delete(distanceFetchedResults)
                    realm.delete(regionFetchedResults)
                    try realm.commitWrite()
                } catch {
                }
            }
        }
        // Update date
        UserDefaults.standard.set(Date(), forKey: "lastDateUpdate")
    }
    
    /// Delete all data more than x days
    /// - Parameter days: Days
    func removeLocationOlderThan(days: Int) {
        do {
            let realm = try Realm()
            let limitDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())
            let predicate = NSPredicate(format: "(date <= %@)", limitDate! as CVarArg)
            let fetchedResults = realm.objects(LocationModel.self).filter(predicate)
            try realm.write {
                realm.delete(fetchedResults)
            }
        } catch {
        }
    }
    
    /// Remove all POI more than x days
    /// - Parameter days: days
    func removePOIOlderThan(days: Int) {
        do {
            let realm = try Realm()
            let limitDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())
            let predicate = NSPredicate(format: "(date <= %@)", limitDate! as CVarArg)
            let fetchedResults = realm.objects(POIModel.self).filter(predicate)
            try realm.write {
                realm.delete(fetchedResults)
            }
        } catch {
        }
    }
    
    /// Remove all visits more than x days
    /// - Parameter days: days
    func removeVisitOlderThan(days: Int) {
        do {
            let realm = try Realm()
            let limitDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())
            let predicate = NSPredicate(format: "(date <= %@)", limitDate! as CVarArg)
            let fetchedResults = realm.objects(VisitModel.self).filter(predicate)
            try realm.write {
                if !fetchedResults.isEmpty {
                    ZOIs.updateZOI(visits: Array(fetchedResults).map({ visitModel in
                        return Visit(visitModel: visitModel)
                    }))
                }
                realm.delete(fetchedResults)
            }
        } catch {
        }
    }
}
