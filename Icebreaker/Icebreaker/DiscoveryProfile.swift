import Foundation

/// Explicit public projection. Never copy the private dictionary wholesale.
/// A cell spans 0.1 degree; only its index, never the original coordinates, is shared.
enum DiscoveryProfile {
    static func cell(_ coordinate: Double, offset: Double, count: Int) -> Int {
        min(count - 1, max(0, Int(floor((coordinate + offset) * 10))))
    }

    static func project(_ data: [String: Any]) -> [String: Any] {
        let visible = (data["isVisible"] as? Bool ?? data["isLocationVisible"] as? Bool ?? false)
            && (data["isLocationVisible"] as? Bool ?? true)
        let nested = data["location"] as? [String: Any]
        guard visible,
              let lat = data["latitude"] as? Double ?? nested?["latitude"] as? Double,
              let lon = data["longitude"] as? Double ?? nested?["longitude"] as? Double,
              lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon)
        else { return ["isVisible": false] }
        let interests = (data["interests"] as? [String] ?? []).prefix(20)
        let interestsText = String(interests.joined(separator: "\n").prefix(1000))
        return [
            "schemaVersion": 1,
            "isVisible": true,
            "firstName": String((data["firstName"] as? String ?? "").prefix(100)),
            "bio": String((data["bio"] as? String ?? "").prefix(1000)),
            "interestsText": interestsText,
            "profileImageURL": String((data["profileImageURL"] as? String ?? "").prefix(2048)),
            "cellLat": cell(lat, offset: 90, count: 1800),
            "cellLon": cell(lon, offset: 180, count: 3600)
        ]
    }

    static func center(_ data: [String: Any]) -> (latitude: Double, longitude: Double)? {
        guard data["isVisible"] as? Bool == true,
              let lat = data["cellLat"] as? Int, let lon = data["cellLon"] as? Int,
              (0..<1800).contains(lat), (0..<3600).contains(lon) else { return nil }
        return (Double(lat) / 10 - 90 + 0.05, Double(lon) / 10 - 180 + 0.05)
    }

    static func latitudeBounds(_ latitude: Double, radiusKm: Double) -> (min: Int, max: Int) {
        // Include cells intersecting the search radius; longitude is filtered with CLLocation.
        let delta = (radiusKm + 16) / 110
        return (cell(latitude - delta, offset: 90, count: 1800),
                cell(latitude + delta, offset: 90, count: 1800))
    }

    static func distanceLabel(meters: Double) -> String {
        guard meters.isFinite, meters >= 0 else { return "Approximate area" }
        if meters < 10000 { return "In your area" }
        return "About \(Int((meters / 10000).rounded()) * 10) km away"
    }
}
