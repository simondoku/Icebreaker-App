//
//  User.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import Foundation
import CoreLocation
import Firebase
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    var firstName: String
    var name: String
    var age: Int
    var bio: String
    var location: String?
    var profileImageURL: String?
    var interests: [String]
    let createdAt: Date
    
    // Location properties for Firebase
    var latitude: Double?
    var longitude: Double?
    var lastLocationUpdate: Date?
    var isLocationVisible: Bool = false
    var visibilityRange: Double = 20.0 // kilometers
    
    // Online status and activity
    var isOnline: Bool = false
    var lastSeen: Date?
    var isVisible: Bool = false
    
    // AI answers for matching
    var aiAnswers: [AIAnswer] = []
    var recentAnswers: [String] = []
    
    // Computed distance property (not stored in Firebase)
    var distance: Double {
        return distanceFromUser ?? 0.0
    }
    
    var distanceFromUser: Double?
    
    // Computed properties for radar positioning
    var radarPosition: CGPoint {
        // Generate a position based on user ID for consistent placement
        let hash = abs(id.hashValue)
        let x = Double((hash % 200) - 100) // -100 to 100
        let y = Double(((hash / 200) % 200) - 100) // -100 to 100
        return CGPoint(x: x, y: y)
    }
    
    // Activity status
    var isActive: Bool {
        guard let lastSeen = lastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) < 300 // 5 minutes
    }
    
    // Computed CLLocation property
    var clLocation: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    init(id: String, firstName: String, age: Int, bio: String, location: String? = nil, profileImageURL: String? = nil, interests: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.name = firstName
        self.age = age
        self.bio = bio
        self.location = location
        self.profileImageURL = profileImageURL
        self.interests = interests
        self.createdAt = createdAt
    }

    // Update location
    mutating func updateLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.lastLocationUpdate = Date()
    }

    // Check if user is within range
    func isWithinRange(of otherUser: User, maxDistance: Double) -> Bool {
        guard let myLocation = clLocation,
              let otherLocation = otherUser.clLocation else { return false }

        let distance = myLocation.distance(from: otherLocation)
        return distance <= maxDistance * 1000 // Convert km to meters
    }

    // Custom coding keys for Firebase compatibility
    enum CodingKeys: String, CodingKey {
        case id, firstName, name, age, bio, location, profileImageURL, interests, createdAt
        case latitude, longitude, lastLocationUpdate, isLocationVisible, visibilityRange
        case isOnline, lastSeen, isVisible, aiAnswers, recentAnswers
    }
}
