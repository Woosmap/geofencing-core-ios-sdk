//
//  WoosmapDataManager.swift
//  WoosmapGeofencing
import Foundation
import CoreData

internal class WoosmapDataManager:NSObject {
    
    public static let connect = WoosmapDataManager()
    
    let identifier: String  = "WebGeoServices.WoosmapGeofencing"       //Your framework bundle ID
    let model: String       = "Woosmap"              //Model name
    var module: String      =  "WoosmapGeofencing"
    
    lazy var woosmapDB: NSPersistentContainer = {
        let messageKitBundle = Bundle(identifier: self.identifier)
        let modelURL = messageKitBundle!.url(forResource: self.model, withExtension: "momd")!
        let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)
        let container = NSPersistentContainer(name: self.model, managedObjectModel: managedObjectModel!)
        container.loadPersistentStores { (storeDescription, error) in
            if let err = error{
                fatalError("❌ Loading of store failed:\(err)")
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
            print("Deleted all my data in myEntity error : \(error) \(error.userInfo)")
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
            print("❌ Failed to fetch \(entityName):",fetchErr)
            throw fetchErr
        }
    }
    
    
    func save<T: NSManagedObject>(entity:T) throws -> Bool{
        do {
            try   entity.managedObjectContext?.save()
            return true
        } catch let error {
            print("❌ Failed to create/update record: \(error.localizedDescription)")
            throw error
        }
    }
}
