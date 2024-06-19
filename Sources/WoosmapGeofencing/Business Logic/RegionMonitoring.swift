//
//  RegionLogging.swift
//  NewLocationManager
//
//  Created by WGS on 06/06/24.
//

import Foundation
import CoreLocation

@available(iOS 17, *)
extension CLMonitor {
        @MainActor
        static var woosmapMonitor: CLMonitor {
            get async {
                @MainActor
                struct Static {
                    static var task: Task<CLMonitor, Never>?
                }
                if let task = Static.task {
                    return await task.value
                }
                let task = Task { await CLMonitor("WoosmapMonitor") }
                Static.task = task
                return await task.value
        }
    }
}

extension CLRegion {
    var RegionIdentifier: String {
        get {
            let idFormat = self.identifier
            if(idFormat.contains("::")){
                let seperated = idFormat.components(separatedBy: "@")
                return seperated[1]
            }
            
            return idFormat
        }
    }
}

protocol RegionMonitoring{
    @available(iOS 17.0, *)
    func list() async -> [String: CLCondition]
    
    @available(iOS 17.0, *)
    func addRegion(_ location: CLLocationCoordinate2D, _ radius: CLLocationDistance, forID id:String) async
    
    @available(iOS 17.0, *)
    func addBeaconRegion(_ uuid: UUID, _ major: UInt16?,_ minor: UInt16?, forID id:String)
    
    @available(iOS 17.0, *)
    func addBeaconRegion(_ uuid: UUID, _ major: UInt16?,_ minor: UInt16?, forID id:String) async
    
    @available(iOS 17.0, *)
    func getRegion(_ id:String) async -> CLMonitor.Record?
    
    @available(iOS 17.0, *)
    func removeRegion(_ id:String) async
    
    var delegate:RegionMonitoringDelegate? {get set}
}

protocol RegionMonitoringDelegate {
    func regionMonitoring(_ manager: RegionMonitoring, didExitRegion region: CLRegion)
    func regionMonitoring(_ manager: RegionMonitoring, monitoringDidFailFor region: CLRegion?, withError error: any Error)
    func regionMonitoring(_ manager: RegionMonitoring, didEnterRegion region: CLRegion)
}

@available(iOS 17, *)
class RegionMonitoringImpl: NSObject,RegionMonitoring{
    var delegate: RegionMonitoringDelegate?
    var monitor: CLMonitor?
    
    init(_ event:RegionMonitoringDelegate){
        super.init()
        delegate = event
        self.populateEvent()
    }
    override init(){
        super.init()
        
        //@available(iOS, introduced: 7.0, deprecated: 13.0, message: "Use -startRangingBeaconsSatisfyingConstraint:")
        //@available(iOS, introduced: 7.0, deprecated: 100000)
        // Receiving events
        //populateEvent()
        
    }
    private func populateEvent(){
        Task{
            self.monitor = await CLMonitor.woosmapMonitor
            for try await event in await self.monitor!.events {
                switch (event.state){
                case .satisfied:
                    if let regioninfo = await self.getRegion(event.identifier){
                        if let circularRegion = regioninfo.condition  as? CLMonitor.CircularGeographicCondition{
                            let eventRegion: CLRegion = CLCircularRegion(center: circularRegion.center, radius: circularRegion.radius, identifier: event.identifier)
                            delegate?.regionMonitoring(self, didEnterRegion: eventRegion)
                        }
                        else if let beaconRegion = regioninfo.condition  as? CLMonitor.BeaconIdentityCondition{
                            var eventRegion: CLRegion = CLBeaconRegion(uuid: beaconRegion.uuid, identifier: event.identifier)
                            if(beaconRegion.major != nil && beaconRegion.minor != nil){
                                eventRegion = CLBeaconRegion(uuid: beaconRegion.uuid,
                                                             major: beaconRegion.major ?? 0,
                                                             minor:beaconRegion.minor ?? 0 ,
                                                             identifier: event.identifier)
                            }
                            else if beaconRegion.major != nil{
                                eventRegion = CLBeaconRegion(uuid: beaconRegion.uuid,
                                                             major: beaconRegion.major ?? 0,
                                                             identifier: event.identifier)
                            }
                                                                       
                            delegate?.regionMonitoring(self, didEnterRegion: eventRegion)
                        }
                    }
                    //print("\(event.identifier) is entered")
                case .unsatisfied:
                    if let regioninfo = await self.getRegion(event.identifier){
                        if let circularRegion = regioninfo.condition  as? CLMonitor.CircularGeographicCondition{
                            let eventRegion: CLRegion = CLCircularRegion(center: circularRegion.center, radius: circularRegion.radius, identifier: event.identifier)
                            delegate?.regionMonitoring(self, didExitRegion: eventRegion)
                        }
                        else if let beaconRegion = regioninfo.condition  as? CLMonitor.BeaconIdentityCondition{
                            var eventRegion: CLRegion = CLBeaconRegion(uuid: beaconRegion.uuid, identifier: event.identifier)
                            if(beaconRegion.major != nil && beaconRegion.minor != nil){
                                eventRegion = CLBeaconRegion(uuid: beaconRegion.uuid,
                                                             major: beaconRegion.major ?? 0,
                                                             minor:beaconRegion.minor ?? 0 ,
                                                             identifier: event.identifier)
                            }
                            else if beaconRegion.major != nil{
                                eventRegion = CLBeaconRegion(uuid: beaconRegion.uuid,
                                                             major: beaconRegion.major ?? 0,
                                                             identifier: event.identifier)
                            }
                                                                       
                            delegate?.regionMonitoring(self, didExitRegion: eventRegion)
                        }
                    }
                    
                    //print("\(event.identifier) is exited")
                case .unknown:
                    print("\(event.identifier) is unknown")
                case .unmonitored:
                    //await self.removeRegion(event.identifier)
                    print("\(event.identifier) is unmonitored")
                @unknown default:
                    print("\(event.identifier) is unknown default")
                }
            }
        }
    }
    func addRegion(_ location: CLLocationCoordinate2D, _ radius: CLLocationDistance, forID id:String) async{
        let georegion =  CLMonitor.CircularGeographicCondition(center: location, radius: radius)
        let monitor = await CLMonitor.woosmapMonitor
        await monitor.add(georegion, identifier: id)
    }
    func addBeaconRegion(_ uuid: UUID, _ major: UInt16?,_ minor: UInt16?, forID id:String){
        Task {
            var georegion =  CLMonitor.BeaconIdentityCondition(uuid: uuid)
            if(major != nil && minor != nil){
                georegion = CLMonitor.BeaconIdentityCondition(uuid: uuid, major: CLBeaconMajorValue( major ?? 0) , minor: CLBeaconMinorValue(minor ?? 0))
            }
            else if(major != nil){
                georegion = CLMonitor.BeaconIdentityCondition(uuid: uuid, major: CLBeaconMajorValue( major ?? 0))
            }
            let monitor = await CLMonitor.woosmapMonitor
            await monitor.add(georegion, identifier: id)
        }
    }
    
    func addBeaconRegion(_ uuid: UUID, _ major: UInt16?,_ minor: UInt16?, forID id:String) async{
        var georegion =  CLMonitor.BeaconIdentityCondition(uuid: uuid)
        if(major != nil && minor != nil){
            georegion = CLMonitor.BeaconIdentityCondition(uuid: uuid, major: CLBeaconMajorValue( major ?? 0) , minor: CLBeaconMinorValue(minor ?? 0))
        }
        else if(major != nil){
            georegion = CLMonitor.BeaconIdentityCondition(uuid: uuid, major: CLBeaconMajorValue( major ?? 0))
        }
        let monitor = await CLMonitor.woosmapMonitor
        await monitor.add(georegion, identifier: id)
    }
    
    func removeRegion(_ id:String) async{
        self.monitor = await CLMonitor.woosmapMonitor
        for anIdentifier in await self.monitor!.identifiers {
            if(anIdentifier == id){
                await self.monitor?.remove(anIdentifier)
            }
        }
    }
    
    func getRegion(_ id:String) async -> CLMonitor.Record?{
        if self.monitor == nil{
            self.monitor = await CLMonitor.woosmapMonitor
        }
        for anIdentifier in await self.monitor!.identifiers {
            if(anIdentifier == id){
                if let monitoredRecord = await self.monitor!.record(for: anIdentifier) {
                    return monitoredRecord
                }
            }
        }
        return nil
    }
    
    
    @available(*, noasync, message: "this method blocks thread use the async version instead")
    func getRegion(_ id:String) -> CLMonitor.Record? {
        class Enclosure {
            var value: CLMonitor.Record?
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        let enclosure = Enclosure()
        Task {
            enclosure.value = await getRegion(id)
            semaphore.signal()
        }
        semaphore.wait()
        return enclosure.value
    }
    @available(*, noasync, message: "this method blocks thread use the async version instead")
    func getRegionNotWorking(_ id:String) -> CLMonitor.Record? {
        class Enclosure {
            var value: CLMonitor.Record?
        }
        
        let enclosure = Enclosure()
        let group = DispatchGroup()
        group.enter()
        Task {
            enclosure.value = await getRegion(id)
            group.leave()
        }
        group.wait()
        return enclosure.value
    }
    
    @available(*, noasync, message: "this method blocks thread use the async version instead")
    func getRegionCallback(_ id:String, callback: @escaping (CLMonitor.Record?) -> Void) {
        Task {
            let result = await getRegion(id)
            callback(result)
        }
    }
    
    
    func list() async -> [String: CLCondition] {
        var output:[String: CLCondition] = [:]
        self.monitor = await CLMonitor.woosmapMonitor
        for anIdentifier in await self.monitor!.identifiers {
            
            // Get record
            if let monitoredRecord = await self.monitor!.record(for: anIdentifier) {
                output[anIdentifier] = monitoredRecord.condition
                //print("Records:\(anIdentifier) at state \(monitoredRecord.lastEvent.state)")
            }
            
        }
        return output
    }
}

