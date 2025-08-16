//
//  AsyncSemaphore.swift
//  Clique
//
//  Created by Rod Tavangar on 4/29/25.
//

import Foundation

actor AsyncSemaphore {
    private var value: Int
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        while value <= 0 {
            await Task.yield()
        }
        value -= 1
    }
    
    func signal() {
        value += 1
    }
}
