//
//  ClCollection.swift
//  Clique
//
//  Created by Rod Tavangar on 6/27/24.
//

import SwiftUI
import PhotosUI

struct CollectionImage: Identifiable, Hashable, Codable {
    let id: String
    var owner: User?
    
    var imageUrl: PhotoUrls? = nil
    var uiImage: UIImage? = nil
    
    var date: Date
    var numLikes: Int = 0
    var numComments: Int = 0
    var numTaggedMembers: Int = 0
    var hasLiked: Bool = false
}

extension CollectionImage {
    enum CodingKeys: String, CodingKey {
        case id, owner, imageUrl, date, numLikes, numComments, numTaggedMembers, hasLiked
        // intentionally exclude `newImages`
    }
}

struct ClCollection: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String = ""
    var userId: String = ""
    var cliqueId: String = ""
    let creation: Date
    var images: [CollectionImage]
    var coverPhoto: PhotoUrls? = nil
    var visibility: Visibility
    var numFlicks: Int = 0
    
    var mostLikedImage: String?
}

extension ClCollection {
    static var MOCK_COLLECTIONS: [ClCollection] = [
        .init(id: "1", name: "Trip to New York", description: "A trip to New York City", creation: createDate(year: 2021, month: 8, day: 4), images: collectionUrls(cliqueName: "huddle", number: 1, max: 192), coverPhoto: PhotoUrls(highQualityUrl: "huddle-cl-1-cover"), visibility: .pub),
        .init(id: "2", name: "Fun in the snow", description: "So much fun in the snow!", creation: createDate(year: 2022, month: 1, day: 29), images: collectionUrls(cliqueName: "t_olympics", number: 1, max: 96), coverPhoto: PhotoUrls(highQualityUrl: "t_olympics-cl-1-cover"), visibility: .followers),
        .init(id: "3", name: "Vintage Flicks", description: "these are the best and hardest and toughest flicks from what we called my 20th birthday. tuff photos incthese are the best and hardest and toughest flicks from what we called my 20th birthday. tuff photos nice",creation: createDate(year: 2023, month: 9, day: 25), images: collectionUrls(cliqueName: "t_olympics", number: 2, max: 45), coverPhoto: PhotoUrls(highQualityUrl: "t_olympics-cl-2-cover"), visibility: .priv)
    ]
    
    static func collectionUrls(cliqueName: String, number: Int, max: Int) -> [CollectionImage] {
        var images: [CollectionImage] = []
        for i in 1 ... max {
            let name = "\(cliqueName)-cl-\(number)-\(i)"
            images.append(CollectionImage(id: UUID().uuidString, imageUrl: PhotoUrls(highQualityUrl: name), date: Date(timeIntervalSinceNow: Double(i * 50000))))
        }
        
        return images
    }
    
    static func createDate(year: Int, month: Int, day: Int) -> Date {
        let dateComponents = DateComponents(year: year, month: month, day: day)
        let calendar = Calendar.current
        return calendar.date(from: dateComponents)!
    }
}
