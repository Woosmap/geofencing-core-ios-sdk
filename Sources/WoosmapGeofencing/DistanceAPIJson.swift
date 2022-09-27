//
//  TrafficDistanceAPIJson.swift
//  WoosmapGeofencing
//

import Foundation

/// Distance API JSON Data
public struct DistanceAPIData: Codable {
    public let rows: [RowDistance]?
    public let status: String?
}

/// Row Distance JSON Data
public struct RowDistance: Codable {
    public let elements: [ElementDistance]?
}

/// Element Distance JSON Data
public struct ElementDistance: Codable {
    public let status: String?
    public let duration_with_traffic: DistanceInfo?
    public let duration: DistanceInfo?
    public let distance: DistanceInfo?
}

/// DistanceInfo JSON Data
public struct DistanceInfo: Codable {
    public let value: Int?
    public let text: String?
}
