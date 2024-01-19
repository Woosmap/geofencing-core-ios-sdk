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
    

    private var _isDBMissing: Bool = false
    public var isDBMissing: Bool {
        get { return _isDBMissing }
    }
    
    lazy var woosmapDB: NSPersistentContainer = {
        var messageKitBundle = Bundle(identifier: self.identifier)
        if messageKitBundle == nil{
            messageKitBundle = Bundle.main
        }
        if let modelURL = messageKitBundle!.url(forResource: self.model, withExtension: "momd"){
            let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)
            let container = NSPersistentContainer(name: self.model, managedObjectModel: managedObjectModel!)
            /*add necessary support for migration*/
            if let description = container.persistentStoreDescriptions.first{
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
                description.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
                container.persistentStoreDescriptions =  [description]
            }
            /*add necessary support for migration*/
            
            container.loadPersistentStores { (storeDescription, error) in
                if let err = error{
                    NotificationCenter.default.post(name: .woosmapGeofenceError, object: self, userInfo: ["error": err])
                    if(WoosLog.isValidLevel(level: .error)){
                        if #available(iOS 14.0, *) {
                            Logger.sdklog.error("\(LogEvent.s.rawValue) \(#function) Loading of store failed:\(err.localizedDescription)")
                        } else {
                            WoosLog.critical("\(#function) Loading of store failed:\(err.localizedDescription)")
                        }
                    }
                    self._isDBMissing = true
                }
            }
            return container
            
        }
        else{
            let error = WoosmapGeofenceError.dbMissing
            NotificationCenter.default.post(name: .woosmapGeofenceError, object: self, userInfo: ["error": error])
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.s.rawValue) \(#function) Loading of store: database missing")
                } else {
                    WoosLog.critical("\(#function) Loading of store: database missing")
                }
            }
            _isDBMissing = true
            return NSPersistentContainer(name: self.model)
        }
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
        let context = woosmapDB.newBackgroundContext()
        if isDBMissing == true{
            return false
        }
        do {
            let results = try context.fetch(fetchRequest)
            for managedObject in results {
                if let managedObjectData: NSManagedObject = managedObject as? NSManagedObject {
                    context.delete(managedObjectData)
                }
            }
            try context.save()
            return true
        } catch let error as NSError {
            NotificationCenter.default.post(name: .woosmapGeofenceError, object: self, userInfo: ["error": error])
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
        let context = woosmapDB.newBackgroundContext()
        if( isDBMissing == true){
            return []
        }
        do{
            let fetchedResult = try context.fetch(request)
            return fetchedResult as? [T] ?? []
        }catch let fetchErr as NSError {
            NotificationCenter.default.post(name: .woosmapGeofenceError, object: self, userInfo: ["error": fetchErr])
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
        } catch let error as NSError  {
            NotificationCenter.default.post(name: .woosmapGeofenceError, object: self, userInfo: ["error": error])
            if(WoosLog.isValidLevel(level: .error)){
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) \(#function) Failed to create/update record: \(entity.entity.name ?? "") \(error.localizedDescription)")
                } else {
                    WoosLog.error("\(#function) Failed to create/update record: \(error.localizedDescription)")
                }
            }
            throw error
        }
        catch let error{
            NotificationCenter.default.post(name: .woosmapGeofenceError, object: self, userInfo: ["error": error])
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


enum WoosmapGeofenceError: Error {
    // Throw when an invalid password is entered
    case dbMissing

    // Throw in all other cases
    case unexpected(code: Int)
}
extension WoosmapGeofenceError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dbMissing:
            return "Database is missing"
        case .unexpected(_):
            return "An unexpected error occurred."
        }
    }
}
extension WoosmapGeofenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .dbMissing:
            return NSLocalizedString(
                "Database is missing",
                comment: "Woosmap Geofence Error"
            )
        case .unexpected(_):
            return NSLocalizedString(
                "An unexpected error occurred.",
                comment: "Unexpected Error"
            )
        }
    }
}
