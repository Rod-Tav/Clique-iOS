//
//  WebService.swift
//  Clique
//
//  Created by Rod Tavangar on 12/6/24.
//

import Foundation
import OpenAPIURLSession

class WebService<C: APIProtocol> {
    let client: C
    
    init(client: C) {
        self.client = client
    }
    
    init() where C == Client {
        self.client = Client(
            serverURL: AppConfig.serverURL,
            transport: URLSessionTransport()
        )
    }
}
