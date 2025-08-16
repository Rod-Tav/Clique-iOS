//
//  ReportType.swift
//  Clique
//
//  Created by Quinn Liu on 3/3/25.
//

enum ReportType: String {
    case collection, image, user, clique
    
    var capitalized: String {
        return self.rawValue.capitalized
    }
    
    var reportReasons: [String] {
        switch self {
        case .user:
            return ["user report"]
        case .clique:
            return ["clique report"]
        default:
            return [
                "Spam or misleading information",
                "Hate speech or harrassment",
                "Violence or harmful behavior",
                "Nudity or sexual content",
                "Illegal or prohibited content",
                "Misinformation or false claims",
                "Privacy violation",
                "Impersonation or fake account",
                "Intellectual property violation",
                "Other"
            ]
        }
    }
}
