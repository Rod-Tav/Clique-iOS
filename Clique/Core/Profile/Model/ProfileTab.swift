//
//  ProfileTabFilter.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

protocol ProfileTab: CaseIterable {
    var rawValue: Int { get }
    var icon: String { get }
    var image: AnyView { get }
}
