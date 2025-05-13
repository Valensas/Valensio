//
//  RequestUploader.swift
//  Valensio
//
//  Created by Moray Baruh on 6.05.2025.
//
import Foundation


final class RequestUploader: NSObject, @unchecked Sendable {
    var continuation: CheckedContinuation<HttpResponse, Error>?
    let body: InputStream?
    private var data = Data()

    init(body: InputStream?) {
        self.body = body
    }
}

extension RequestUploader: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data.append(data)
    }

    func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
        return body
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            continuation?.resume(throwing: error)
            return
        }
        guard let response = task.response else {
            continuation?.resume(throwing: ClientError.noUrlResponse)
            return
        }
        continuation?.resume(returning: HttpResponse(urlResponse: response, data: data))
    }
}
