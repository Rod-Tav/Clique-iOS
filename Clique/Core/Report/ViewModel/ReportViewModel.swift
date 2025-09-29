//
//  ReportViewModel.swift
//  Clique
//
//  Created by Quinn Liu on 3/6/25.
//

import Foundation

@Observable
class ReportViewModel {
    
    var report: Report
    let scriptUrl: String
    
    init(reporterId: String, objectId: String, reportType: ReportType, reportReason: String, date: Date) {
        self.report = Report(reporterId: reporterId, objectId: objectId, reportType: reportType, reportReason: reportReason, date: date)
        self.scriptUrl = Bundle.main.object(forInfoDictionaryKey: "REPORT_URL") as? String ?? "URL_NOT_FOUND"
    }
    
    internal func sendReport(completion: @escaping (ReportResult) -> Void) {
        if scriptUrl == "URL_NOT_FOUND" {
            DispatchQueue.main.async {
                completion(.failure)
            }
            return
        }
        
        var request = URLRequest(url: URL(string: scriptUrl)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let reportJson = try JSONEncoder().encode(report)
            let reportJsonString = String(data: reportJson, encoding: .utf8)!
            print(reportJsonString)
            request.httpBody = reportJson
        } catch {
            DispatchQueue.main.async {
                completion(.failure)
            }
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    completion(.failure)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure)
                }
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let status = jsonResponse["status"] as? Int,
                       let _ = jsonResponse["message"] as? String {

                        switch status {
                        case 201:
                            DispatchQueue.main.async {
                                completion(.success)
                            }
                        case 409:
                            DispatchQueue.main.async {
                                completion(.conflict)
                            }
                        default:
                            DispatchQueue.main.async {
                                completion(.failure)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure)
                }
            }
        }

        task.resume()
    }}
