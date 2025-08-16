//
//  Tips.swift
//  Clique
//
//  Created by Quinn Liu on 3/9/25.
//

import Foundation
import TipKit

// MARK: Feed
struct FeedGalleryTip: Tip {
    
    static let navigationLinkTapEvent = Event(id: "navLinkTap")
    
    var title: Text {
        Text("View the gallery")
    }
    
    var message: Text? {
        Text("Click on a collection's name to see all its images.")
    }
    
    var image: Image? {
        Image("collections")
            .resizable()
            .frame(width: 16, height: 16) as? Image
    }
    
    var rules: [Rule] {
        #Rule(Self.navigationLinkTapEvent) { event in
            event.donations.count == 0
        }
    }
}

// MARK: Gallery
struct GallerySortTip: Tip {

    static let sortTapEvent = Event(id: "sortTap")

    var title: Text {
        Text("Sort collection photos")
    }

    var message: Text? {
        Text("Order photos by likes or recency.")
    }

    var rules: [Rule] {
        #Rule(Self.sortTapEvent) { event in
            event.donations.count == 0
        }
    }
}
