//
//  WoosmapDataManager.swift
//  WoosmapGeofencing
import Foundation
import CoreData
import os
internal class WoosmapDataManager:NSObject {
    
    public static let connect = WoosmapDataManager()
    
    let identifier: String  = "WebGeoServices.WoosmapGeofencing"       //Your framework bundle ID
    let model: String       = "Woosmap"              //Model name
    var module: String      =  "WoosmapGeofencing"
    
    lazy var woosmapDB: NSPersistentContainer = {
        var messageKitBundle = Bundle(identifier: self.identifier)
        if messageKitBundle == nil{
            messageKitBundle = Bundle.main
        }
        let modelURL = messageKitBundle!.url(forResource: self.model, withExtension: "momd")!
        let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)
        let container = NSPersistentContainer(name: self.model, managedObjectModel: managedObjectModel!)
        /*add necessary support for migration*/
        let description = NSPersistentStoreDescription()
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions =  [description]
        /*add necessary support for migration*/
        
        container.loadPersistentStores { (storeDescription, error) in
            if let err = error{
                if(WoosLog.isValidLevel(level: .error)){
                    if #available(iOS 14.0, *) {
                        Logger.sdklog.error("\(LogEvent.s.rawValue) \(#function) Loading of store failed:\(err.localizedDescription)")
                        Logger.sdklog.error("\(LogEvent.s.rawValue) \(#function) Loading DB:\(modelURL.absoluteString)")
                    } else {
                        WoosLog.critical("\(#function) Loading of store failed:\(err.localizedDescription)")
                    }
                }
                //fatalError("❌ Loading of store failed:\(err)")
            }
        }
        return container
    }()
    

    override init(){
        super.init()
        module = NSStringFromClass(WoosmapDataManager.self).components(separatedBy: ".").first!
    }
    public func filePath() -> String{
        return NSPersistentContainer.defaultDirectoryURL().absoluteString
    }
    
    func deleteAll<T:NSManagedObject>(entityClass:T.Type, predicate:NSPredicate? = nil) throws -> Bool{
        
        let entityName = NSStringFromClass(entityClass).replacingOccurrences(of: "\(module).", with: "")
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = predicate
        let context = woosmapDB.viewContext
        do {
            let results = try context.fetch(fetchRequest)
            for managedObject in results {
                if let managedObjectData: NSManagedObject = managedObject as? NSManagedObject {
                    context.delete(managedObjectData)
                }
            }
            return true
        } catch let error as NSError {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) Deleted all my data in \(entityName) error : \(error) \(error.userInfo)")
                } else {
                    WoosLog.error("\(#function) Deleted all my data in \(entityName) error : \(error) \(error.userInfo)")
                }
            }
            throw error
        }
    }
    func retrieve<T: NSManagedObject>(entityClass:T.Type, sortBy:String? = nil, isAscending:Bool = true, predicate:NSPredicate? = nil) throws -> [T] {
        let entityName = NSStringFromClass(entityClass).replacingOccurrences(of: "\(module).", with: "")
        let request    = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        
        request.returnsObjectsAsFaults = false
        request.predicate = predicate
        
        if (sortBy != nil) {
            let sorter = NSSortDescriptor(key:sortBy , ascending:isAscending)
            request.sortDescriptors = [sorter]
        }
        let context = woosmapDB.viewContext
        do{
            let fetchedResult = try context.fetch(request)
            return fetchedResult as? [T] ?? []
        }catch let fetchErr {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) Failed to fetch \(entityName): \(fetchErr)")
                } else {
                    WoosLog.error("\(#function) Failed to fetch \(entityName): \(fetchErr)")
                }
            }
            throw fetchErr
        }
    }
    
    
    func save<T: NSManagedObject>(entity:T) throws -> Bool{
        do {
            
            try   entity.managedObjectContext?.save()
            return true
        } catch let error {
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) Failed to create/update record: \(entity.entity.name ?? "") \(error.localizedDescription)")
                } else {
                    WoosLog.error("\(#function) Failed to create/update record: \(error.localizedDescription)")
                }
            }
            throw error
        }
    }
}
