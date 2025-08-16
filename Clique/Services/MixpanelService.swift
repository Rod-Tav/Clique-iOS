//
//  MixpanelService.swift
//  Clique
//
//  Created by Rod Tavangar on 5/24/25.
//

import Mixpanel


func track(_ event: String) {
    Mixpanel.mainInstance().track(event: event)
}

func track(event: String, properties: Properties) {
    Mixpanel.mainInstance().track(event: event, properties: properties)
}
