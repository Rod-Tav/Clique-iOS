//
//  UserNotification.swift
//  Clique
//
//  Created by Rod Tavangar on 12/10/24.
//

import Foundation

enum NotificationSection: String, CaseIterable, Hashable {
    case today = "Today"
    case lastFewDays = "Last few days"
    case older = "Older"
}

struct UserNotification: Identifiable, Hashable, Codable {
    let id: String
    let type: NotificationType
    let user: User
    let time: Date
    var clique: Clique?
    var comment: String?
    var collection: ClCollection?
    var collectionImage: CollectionImage?
    var viewed: Bool?
    var accepted: Bool? = false
    
    static func randomDateWithinLastTwoWeeks() -> Date {
        let currentDate = Date()
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: currentDate)!

        let timeIntervalSinceTwoWeeksAgo = currentDate.timeIntervalSince(twoWeeksAgo)
        let randomTimeInterval = TimeInterval(arc4random_uniform(UInt32(timeIntervalSinceTwoWeeksAgo)))

        return twoWeeksAgo.addingTimeInterval(randomTimeInterval)
    }
}

extension UserNotification {
    var section: NotificationSection {
        let now = Date()
        let hoursAgo = now.timeIntervalSince(time) / 3600

        if hoursAgo < 24 {
            return .today
        } else if hoursAgo < 168 {
            return .lastFewDays
        } else {
            return .older
        }
    }
}

extension UserNotification {
    static var MOCK_NOTIFICATIONS: [UserNotification] = [
        .init(id: "mock-0", type: .postedFlick, user: User.MOCK_USERS[2], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: false),
        .init(id: "mock-1", type: .likedFlickInCollection, user: User.MOCK_USERS[0], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: false),
        .init(id: "mock-2", type: .cliqueInvite, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0]),
        .init(id: "mock-3", type: .cliqueInvite, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0]),
        .init(id: "mock-4", type: .cliqueInvite, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0]),
        .init(id: "mock-5", type: .cliqueInvite, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0]),
        .init(id: "mock-6", type: .cliqueInvite, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0]),
        .init(id: "mock-7", type: .cliqueInvite, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0]),
        .init(id: "mock-8", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-9", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-10", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-11", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-12", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-13", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-14", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-15", type: .followRequest, user: User.MOCK_USERS[4], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-16", type: .followedYou, user: User.MOCK_USERS[22], time: randomDateWithinLastTwoWeeks()),
        .init(id: "mock-17", type: .acceptedFollowRequest, user: User.MOCK_USERS[19], time: randomDateWithinLastTwoWeeks(), viewed: false),
        .init(id: "mock-18", type: .cliqueJoined, user: User.MOCK_USERS[21], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: false),
        .init(id: "mock-19", type: .cliqueLeft, user: User.MOCK_USERS[2], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: true),
        .init(id: "mock-20", type: .likedFlickInCollection, user: User.MOCK_USERS[0], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], collection: ClCollection.MOCK_COLLECTIONS[0], viewed: true),
        .init(id: "mock-21", type: .commentedOnPost, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[3], viewed: true),
        .init(id: "mock-22", type: .commentedInCollection, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[3], collection: ClCollection.MOCK_COLLECTIONS[1], viewed: true),
        .init(id: "mock-23", type: .mentionedYouInComment, user: User.MOCK_USERS[5], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], collection: ClCollection.MOCK_COLLECTIONS[0], viewed: true),
        .init(id: "mock-24", type: .mentionedYouInComment, user: User.MOCK_USERS[22], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: true),
        .init(id: "mock-25", type: .createdCollection, user: User.MOCK_USERS[18], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], collection: ClCollection.MOCK_COLLECTIONS[2], viewed: true),
        .init(id: "mock-26", type: .postedFlick, user: User.MOCK_USERS[0], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[0], viewed: true),
        .init(id: "mock-27", type: .newCliqueLeader, user: User.MOCK_USERS[19], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: true),
        .init(id: "mock-28", type: .taggedInFlicks, user: User.MOCK_USERS[1], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], viewed: true),
        .init(id: "mock-29", type: .taggedInFlicks, user: User.MOCK_USERS[2], time: randomDateWithinLastTwoWeeks(), clique: Clique.MOCK_CLIQUES[7], collection: ClCollection.MOCK_COLLECTIONS[0], viewed: true)
    ]
}
