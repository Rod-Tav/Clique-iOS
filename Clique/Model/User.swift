//
//  User.swift
//  Clique
//
//  Created by Rod Tavangar on 6/13/24.
//

import Foundation

struct User: Identifiable, Hashable, Codable {
    let id: String
    var firstname: String = ""
    var lastname: String = ""
    let number: String
    var username: String
    var profilePic: MediaUrls? = nil
    var bio: String = ""
    var isPrivate: Bool = true
    
    var numCliques: Int = 0
    var numFollowers: Int = 0
    var numFollowing: Int = 0
   
    var cliques: [Clique]? = []
    var pinnedCliques: [Clique]? = []
    var settings: String? = ""
    var blockedCliques: [Clique]? = []
    var blockedUsers: [User]? = []
    
    var relationship: UserRelationship?
    
    /// Convenience
//    var isCurrentUser: Bool {
//        guard let user = UserService.shared.currentUser else { return false }
//        return user.id == id
//    }
    
    var fullname: String {
        return firstname + " " + lastname
    }
    
//    static func == (lhs: User, rhs: User) -> Bool {
//        return lhs.id == rhs.id
//    }
//    
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
}

extension User {
    static var MOCK_USERS: [User] = [
        .init(id: "1", firstname: "Rod", lastname: "Tavangar", number: "1", username: "rodtavangar", profilePic: PhotoUrls(medQualityUrl: "rod-pp"), bio: "Hi my name is Rod", cliques: [Clique.MOCK_CLIQUES[0], Clique.MOCK_CLIQUES[2], Clique.MOCK_CLIQUES[5]]),
        .init(id: "2", firstname: "Brendan", lastname: "Baron", number: "2", username: "bbaron", profilePic: PhotoUrls(medQualityUrl: "brendan-pp"), bio: "Hi my name is Brendan", cliques: [Clique.MOCK_CLIQUES[0], Clique.MOCK_CLIQUES[5]]),
        .init(id: "3", firstname: "Kyuho", lastname: "Lee", number: "3", username: "kyuholee", profilePic: PhotoUrls(medQualityUrl: "kyuho-pp"), bio: "Lock this in gang. Historic night is tonight.", cliques: [Clique.MOCK_CLIQUES[1], Clique.MOCK_CLIQUES[2], Clique.MOCK_CLIQUES[3], Clique.MOCK_CLIQUES[7]]),
        .init(id: "4", firstname: "Varun", lastname: "Sasisekharan", number: "4", username: "varunsasi", profilePic: PhotoUrls(medQualityUrl: "varun-pp"), bio: "Hi my name is Varun", cliques: [Clique.MOCK_CLIQUES[1], Clique.MOCK_CLIQUES[3]]),
        .init(id: "5", firstname: "Khoi", lastname: "Le", number: "5", username: "khoile", profilePic: PhotoUrls(medQualityUrl: "khoi-pp"), bio: "Hi my name is Khoi", cliques: [Clique.MOCK_CLIQUES[3]]),
        .init(id: "6", firstname: "Benjamin", lastname: "Borgers", number: "6", username: "benborg", profilePic: PhotoUrls(medQualityUrl: "ben-pp"), bio: "Hi my name is Ben"),
        .init(id: "7", firstname: "Caden", lastname: "Elghazal", number: "7", username: "cadenelghazal", profilePic: PhotoUrls(medQualityUrl: "caden-pp"), bio: "Hi my name is Caden", cliques: [Clique.MOCK_CLIQUES[5], Clique.MOCK_CLIQUES[6]]),
        .init(id: "8", firstname: "Cristian", lastname: "Pedraza", number: "8", username: "yamkcp", profilePic: PhotoUrls(medQualityUrl: "cristian-pp"), bio: "Hi my name is Cristian", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "9", firstname: "Emma", lastname: "Kohrt", number: "9", username: "emmakohrt", profilePic: PhotoUrls(medQualityUrl: "emma-pp"), bio: "Hi my name is Emma", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "10", firstname: "Gyaviira", lastname: "Zimaze", number: "10", username: "z", profilePic: PhotoUrls(medQualityUrl: "z-pp"), bio: "Hi my name is Z", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "11", firstname: "Hafsa", lastname: "Rehman", number: "11", username: "hafsa", profilePic: PhotoUrls(medQualityUrl: "hafsa-pp"), bio: "Hi my name is Hafsa", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "12", firstname: "Jason", lastname: "Stewart", number: "12", username: "jstew", profilePic: PhotoUrls(medQualityUrl: "jason-pp"), bio: "Hi my name is Jason", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "13", firstname: "Joseph", lastname: "Feldman", number: "13", username: "joey", profilePic: PhotoUrls(medQualityUrl: "joey-pp"), bio: "Hi my name is Joey", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "14", firstname: "Juan", lastname: "Zapata", number: "14", username: "jzapesc", profilePic: PhotoUrls(medQualityUrl: "juan-pp"), bio: "Hi my name is Juan", cliques: [Clique.MOCK_CLIQUES[5], Clique.MOCK_CLIQUES[6]]),
        .init(id: "15", firstname: "Julian", lastname: "Haurin", number: "15", username: "kingjulian", profilePic: PhotoUrls(medQualityUrl: "julian-pp"), bio: "Hi my name is Julian", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "16", firstname: "Michael", lastname: "Nunes", number: "16", username: "nunes", profilePic: PhotoUrls(medQualityUrl: "michael-pp"), bio: "Hi my name is Michael", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "17", firstname: "Nathan", lastname: "Thewedros", number: "17", username: "nathanthew", profilePic: PhotoUrls(medQualityUrl: "nathan-pp"), bio: "Hi my name is Nathan", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "18", firstname: "Tom", lastname: "Glassman", number: "18", username: "tomglass", profilePic: PhotoUrls(medQualityUrl: "tom-pp"), bio: "Hi my name is Tom", cliques: [Clique.MOCK_CLIQUES[5]]),
        .init(id: "19", firstname: "Bill", lastname: "Gao", number: "19", username: "billgao", profilePic: PhotoUrls(medQualityUrl: "bill-pp"), bio: "Hi my name is Bill", cliques: [Clique.MOCK_CLIQUES[7]]),
        .init(id: "20", firstname: "Brandon", lastname: "Lee", number: "20", username: "brandonlee", profilePic: PhotoUrls(medQualityUrl: "brandon-pp"), bio: "Hi my name is Brandon", cliques: [Clique.MOCK_CLIQUES[7]]),
        .init(id: "21", firstname: "Callia", lastname: "Le", number: "21", username: "calliale", profilePic: PhotoUrls(medQualityUrl: "callia-pp"), bio: "Hi my name is Callia", cliques: [Clique.MOCK_CLIQUES[7]]),
        .init(id: "22", firstname: "Quinn", lastname: "Liu", number: "22", username: "quinnliu", profilePic: PhotoUrls(medQualityUrl: "quinn-pp"), bio: "Hi my name is Quinn", cliques: [Clique.MOCK_CLIQUES[7]]),
        .init(id: "23", firstname: "Joe", lastname: "Anderson", number: "23", username: "joeanderson", profilePic: PhotoUrls(medQualityUrl: "joe-pp"), bio: "Hi my name is Joe", cliques: [Clique.MOCK_CLIQUES[7]])
    ]
}
