import Foundation

@main
struct DiscoveryProfileTests {
    static func main() throws {
        var data: [String: Any] = ["isVisible": true, "email": "private@example.test",
            "firstName": "Simon", "bio": "Hello", "interests": ["art", "cooking"],
            "location": ["latitude": 40.7128, "longitude": -74.006],
            "answers": [["answer": "Private answer"]], "lastActive": Date()]
        let shared = DiscoveryProfile.project(data)
        let allowed: Set<String> = ["schemaVersion", "isVisible", "firstName", "bio", "interestsText", "profileImageURL", "cellLat", "cellLon"]
        precondition(Set(shared.keys) == allowed)
        precondition(shared["cellLat"] as? Int == 1307 && shared["cellLon"] as? Int == 1059)
        let center = DiscoveryProfile.center(shared)!
        precondition(abs(center.latitude - 40.75) < 0.000001)
        precondition(abs(center.longitude - (-74.05)) < 0.000001)
        data["isVisible"] = false
        precondition(DiscoveryProfile.project(data).count == 1)
        data["location"] = ["latitude": 41.123, "longitude": -73.123]
        precondition(DiscoveryProfile.project(data)["isVisible"] as? Bool == false)
        data["isVisible"] = true; data["isLocationVisible"] = false
        precondition(DiscoveryProfile.project(data).count == 1)
        data["isLocationVisible"] = true; data["location"] = ["latitude": Double.nan, "longitude": -74.0]
        precondition(DiscoveryProfile.project(data).count == 1)
        data["location"] = ["latitude": 40.0, "longitude": Double.infinity]
        precondition(DiscoveryProfile.project(data).count == 1)
        data.removeValue(forKey: "location")
        data["latitude"] = -90.0; data["longitude"] = -180.0
        precondition(DiscoveryProfile.project(data)["cellLat"] as? Int == 0)
        data["latitude"] = 90.0; data["longitude"] = 180.0
        precondition(DiscoveryProfile.project(data)["cellLon"] as? Int == 3599)
        precondition(DiscoveryProfile.latitudeBounds(90, radiusKm: 50).max == 1799)
        precondition(DiscoveryProfile.distanceLabel(meters: 2300) == "In your area")
        precondition(DiscoveryProfile.distanceLabel(meters: 23456) == "About 20 km away")
        // The exact Swift-produced projection is also exercised against the Firestore rules.
        if CommandLine.arguments.count > 1 {
            let json = try JSONSerialization.data(withJSONObject: shared, options: [.sortedKeys])
            try json.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        print("14 discovery projection checks passed")
    }
}
