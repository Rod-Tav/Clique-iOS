//
//  KingfisherToUIImage.swift
//  Clique
//
//  Created by Rod Tavangar on 3/2/25.
//

import UIKit
import Kingfisher

func fetchImageWithKingfisher(from urlString: String) async -> UIImage? {
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        return nil
    }

    return await withCheckedContinuation { continuation in
        KingfisherManager.shared.retrieveImage(with: url) { result in
            switch result {
            case .success(let value):
                continuation.resume(returning: value.image)
            case .failure(let error):
                print("Error fetching image with Kingfisher: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
}
