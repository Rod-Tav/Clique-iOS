//
//  Post2.swift
//  Clique
//
//  Created by Rod Tavangar on 7/11/24.
//

import SwiftUI

struct Post2: Identifiable {
    let id: UUID = .init()
    var username: String
    var content: String
    var pics: [PicItem]
    /// View Based Properties
    var scrollPosition: UUID?
}

/// Sample Posts
var samplePosts: [Post2] = [
    .init(username: "iJustine", content: "Nature Pics", pics: pics),
    .init(username: "iJustine", content: "Nature Pics", pics: pics1)
]

private var pics: [PicItem] = [.init(image: "rod-pp"), .init(image: "brendan-pp"), .init(image: "kyuho-pp"), .init(image: "khoi-pp")]

private var pics1: [PicItem] = [.init(image: "rod-pp"), .init(image: "brendan-pp"), .init(image: "kyuho-pp"), .init(image: "khoi-pp")].reversed()
