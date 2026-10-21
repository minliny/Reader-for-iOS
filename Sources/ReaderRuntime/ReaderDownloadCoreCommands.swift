import Foundation

extension ReaderLibraryService {
    func isDownloadCommand(_ method: String) -> Bool {
        downloadAction(method) != nil || method == "cache.download.operation.settle" ||
            method == "cache.clear" || method == "cache.clear.operation.settle"
    }

    private func downloadAction(_ method: String) -> String? {
        switch method {
        case "cache.book.prefetch": return "prefetch"
        case "cache.download.pause": return "pause"
        case "cache.download.resume": return "resume"
        case "cache.download.cancel": return "cancel"
        case "cache.chapter.materialization.report": return "report"
        default: return nil
        }
    }

    private func downloadDomain(_ action: String, parameters: [String: Any]) throws -> [String: Any] {
        guard let source = parameters["sourceId"] as? String, let book = parameters["bookId"] as? String else {
            throw ReaderLibraryError.invalidResponse("download operation domain")
        }
        var domain: [String: Any] = ["sourceId": source, "bookId": book, "action": action]
        if action != "prefetch" {
            guard let chapter = parameters["chapterIndex"] as? NSNumber else {
                throw ReaderLibraryError.invalidResponse("download operation chapter")
            }
            domain["chapterIndex"] = chapter
        }
        return domain
    }

    func downloadMutation(_ method: String, _ business: [String: Any], operationID: String,
                          scope: String, timeout: TimeInterval = 30) async throws -> Data {
        let parameters: [String: Any]
        if let old = try existingCoreParameters(operationID: operationID, method: method) {
            var originalBusiness = old
            originalBusiness.removeValue(forKey: "operationId"); originalBusiness.removeValue(forKey: "sequence")
            guard try JSONSerialization.data(withJSONObject: originalBusiness, options: [.sortedKeys]) ==
                    JSONSerialization.data(withJSONObject: business, options: [.sortedKeys]) else {
                throw ReaderLibraryError.invalidResponse("download operation identity changed")
            }
            parameters = old
        } else {
            let queryMethod: String
            var query: [String: Any]
            if method == "cache.clear" { queryMethod = "cache.clear.operation.query"; query = [:] }
            else {
                guard let action = downloadAction(method) else { throw ReaderLibraryError.invalidResponse("download mutation method") }
                queryMethod = "cache.download.operation.query"
                query = try downloadDomain(action, parameters: business)
            }
            let head = try object(await coreRead(queryMethod, query))["head"] as? [String: Any]
            let sequence = (head?["sequence"] as? NSNumber)?.uint64Value ?? 0
            guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("download sequence exhausted") }
            var bound = business
            bound["operationId"] = coreLineageID(operationID, sequence: sequence + 1)
            bound["sequence"] = sequence + 1
            parameters = bound
        }
        return try await coreMutation(method, parameters, operationID: operationID, scope: scope, timeout: timeout)
    }

    func exactDownloadCommandReceipt(method: String, parameters: [String: Any], operationID: String) async throws -> Data? {
        if method == "cache.clear" || method == "cache.clear.operation.settle" {
            guard let identity = parameters["operationId"] else { return nil }
            var query: [String: Any] = ["operationId": identity]
            if method == "cache.clear" { query["expected"] = parameters }
            let response = try object(await coreRead("cache.clear.operation.query", query))
            guard let receipt = response["receipt"] as? [String: Any],
                  let binding = receipt["binding"] as? [String: Any],
                  sameDownloadBinding(binding, parameters) else { return nil }
            if method.hasSuffix(".settle") {
                guard receipt["phase"] as? String == "settled", try sameDownloadObject(binding, parameters) else { return nil }
                return try JSONSerialization.data(withJSONObject: receipt)
            }
            guard let result = receipt["result"] as? [String: Any] else { return nil }
            return try JSONSerialization.data(withJSONObject: result)
        }
        let settling = method == "cache.download.operation.settle"
        guard let action = settling ? parameters["action"] as? String : downloadAction(method),
              let identity = parameters["operationId"] else { return nil }
        var query = try downloadDomain(action, parameters: parameters)
        query["operationId"] = identity
        if !settling { query["expected"] = ["action": action, "params": parameters] }
        let response = try object(await coreRead("cache.download.operation.query", query))
        guard let receipt = response["receipt"] as? [String: Any],
              let binding = receipt["binding"] as? [String: Any], sameDownloadBinding(binding, parameters),
              receipt["action"] as? String == action else { return nil }
        if settling {
            guard receipt["phase"] as? String == "settled",
                  binding["payloadFingerprint"] as? String == parameters["payloadFingerprint"] as? String else { return nil }
            return try JSONSerialization.data(withJSONObject: receipt)
        }
        if receipt["phase"] as? String == "pending" {
            // Only Core can authorize continuing its persisted original job.
            // A missing row or fresh task state never authorizes a new enqueue.
            guard action == "prefetch", response["canResumeOriginal"] as? Bool == true else { return nil }
            return try await request(method, parameters, mutation: true, timeout: 300, owner: .command(operationID))
        }
        guard ["committed", "settled"].contains(receipt["phase"] as? String ?? ""),
              let data = receipt["data"] as? [String: Any] else { return nil }
        return try JSONSerialization.data(withJSONObject: data)
    }

    func settleDownloadCommand(method: String, parameters: [String: Any], operationID: String) async throws {
        guard method == "cache.clear" || downloadAction(method) != nil,
              let identity = parameters["operationId"] else { return }
        let childID = operationID + ":settle"
        // Our retained original settlement ACK remains authoritative after
        // Core has legitimately compacted its bounded settled history.
        if try isCoreOperationCompleted(childID) { return }
        let clear = method == "cache.clear"
        let action = downloadAction(method)
        var query = clear ? [:] : try downloadDomain(action!, parameters: parameters)
        query["operationId"] = identity
        query["expected"] = clear ? parameters : ["action": action!, "params": parameters]
        let response = try object(await coreRead(clear ? "cache.clear.operation.query" : "cache.download.operation.query", query))
        guard let receipt = response["receipt"] as? [String: Any],
              let binding = receipt["binding"] as? [String: Any], sameDownloadBinding(binding, parameters),
              ["committed", "settled"].contains(receipt["phase"] as? String ?? "") else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        if receipt["phase"] as? String == "settled" { return }
        var settle = clear ? [:] : try downloadDomain(action!, parameters: parameters)
        settle.merge(binding) { _, bound in bound }
        _ = try await coreMutation(clear ? "cache.clear.operation.settle" : "cache.download.operation.settle", settle,
            operationID: childID, scope: "download-settle:" + operationID)
        try await finishCoreOperation(childID)
    }

    private func sameDownloadBinding(_ binding: [String: Any], _ params: [String: Any]) -> Bool {
        binding["operationId"] as? String == params["operationId"] as? String &&
            binding["sequence"] as? NSNumber == params["sequence"] as? NSNumber
    }
    private func sameDownloadObject(_ lhs: [String: Any], _ rhs: [String: Any]) throws -> Bool {
        try JSONSerialization.data(withJSONObject: lhs, options: [.sortedKeys]) ==
            JSONSerialization.data(withJSONObject: rhs, options: [.sortedKeys])
    }
}
