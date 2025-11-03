//
//  Clique.swift
//  Clique
//
//  Created by Rod Tavangar on 6/13/24.
//

import Foundation

struct Clique: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    let creation: Date
    var bio: String
    var cliquePic: MediaUrls? = nil
    var cliqueBanner: MediaUrls? = nil

    var numMembers: Int = 0
//    var numAura: Int = 0
    var numFlicks: Int = 0

    var leader: String? // user id
    var relationship: CliqueRelationship?

    var memberIDs: Set<String>?
//    
//    static func == (lhs: Clique, rhs: Clique) -> Bool {
//        return lhs.id == rhs.id
//    }
//    
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
}

extension Clique {
    static let MOCK_CLIQUES: [Clique] = [
        .init(id: "1", name: "Brod Squad", creation: createDate(year: 2021, month: 12, day: 5), bio: "We are the Brod Squad", cliquePic: MediaUrls(url: "brod-pp"), cliqueBanner: MediaUrls(url: "brod-banner"), leader: "1"),
        .init(id: "2", name: "Kyurun Maroon", creation: createDate(year: 2019, month: 1, day: 10), bio: "We are Kyurun Maroon", cliquePic: MediaUrls(url: "kyurun-pp"), cliqueBanner: MediaUrls(url: "kyurun-banner"), leader: "3"),
        .init(id: "3", name: "Rodho fo sho", creation: createDate(year: 2021, month: 2, day: 20), bio: "We are Rodho fo sho", cliquePic: MediaUrls(url: "rodho-pp"), cliqueBanner: MediaUrls(url: "rodho-banner"), leader: "1"),
        .init(id: "4", name: "Kyurunoi my boy", creation: createDate(year: 2021, month: 3, day: 15), bio: "We are Kyurunoi my boy", cliquePic: MediaUrls(url: "kyurunoi-pp"), cliqueBanner: MediaUrls(url: "kyurunoi-banner"), leader: "3"),
        .init(id: "5", name: "Huddle", creation: createDate(year: 2021, month: 2, day: 25), bio: "Lol", cliquePic: MediaUrls(url: "huddle-pp"), cliqueBanner: MediaUrls(url: "huddle-banner"), leader: "5"),
        .init(id: "6", name: "2021 Tinder Olympics", creation: createDate(year: 2021, month: 9, day: 15), bio: "A great group of friends", cliquePic: MediaUrls(url: "tinder-pp"), cliqueBanner: MediaUrls(url: "tinder-banner"), leader: "10"),
        .init(id: "7", name: "Dos Equis", creation: createDate(year: 2021, month: 8, day: 31), bio: "Soy Caden y Juan", cliquePic: MediaUrls(url: "dosequis-pp"), cliqueBanner: MediaUrls(url: "dosequis-banner"), leader: "14"),
        .init(id: "8", name: "The Kyuhomies", creation: createDate(year: 2022, month: 10, day: 1), bio: "We are the Kyuhomies. We are comprised of a bunch of stupid idiots.", cliquePic: MediaUrls(url: "kyuhomies-pp"), cliqueBanner: MediaUrls(url: "kyuhomies-banner"), leader: "3")
    ]
    
    static func createDate(year: Int, month: Int, day: Int) -> Date {
        let dateComponents = DateComponents(year: year, month: month, day: day)
        let calendar = Calendar.current
        return calendar.date(from: dateComponents)!
    }
}
