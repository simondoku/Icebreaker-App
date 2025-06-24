//
//  User.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    var firstName: String
    var age: Int
    var bio: String
    var location: String?
    var profileImageURL: String?
    var interests: [String]
    let createdAt: Date
    
    // Additional properties for visibility and discovery
    var isVisible: Bool = false
    var visibilityRange: Double = 20.0 // meters
    var recentAnswers: [String] = []
}
