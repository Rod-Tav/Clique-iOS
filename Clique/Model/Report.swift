//
//  Report.swift
//  Clique
//
//  Created by Quinn Liu on 3/6/25.
//

import Foundation
import Toasts

struct Report: Codable, Identifiable {
    var id: String
    var reporterId: String // userId of reporter
    var objectId: String
    var reportType: String
    var reportReason: String
    var reportDescription: String
    var date: String
    
    init(reporterId: String, objectId: String, reportType: ReportType, reportReason: String, date: Date) {
        self.id = reporterId + ";" + objectId
        self.reporterId = reporterId
        self.objectId = objectId
        self.reportType = reportType.capitalized
        self.reportReason = reportReason
        self.reportDescription = ""
        self.date = date.description
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case reporterId
        case objectId
        case reportType
        case reportReason
        case reportDescription
        case date
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reporterId, forKey: .reporterId)
        try container.encode(objectId, forKey: .objectId)
        try container.encode(reportType, forKey: .reportType)
        try container.encode(reportReason, forKey: .reportReason)
        try container.encode(reportDescription, forKey: .reportDescription)
        try container.encode(date, forKey: .date)
    }

}

enum ReportResult {
    case success
    case conflict
    case failure
}
