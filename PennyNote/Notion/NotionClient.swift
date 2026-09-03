import Foundation

actor NotionClient {
    private let token: String

    init(token: String) {
        self.token = token
    }

    func verifyConnection() async throws {
        let request = try NotionRequestBuilder.request(path: "users/me", method: "GET", token: token)
        _ = try await send(request)
    }

    func createDatabase(parentPageID: String, categoryNames: [String]) async throws -> String {
        let body: [String: Any] = [
            "parent": ["type": "page_id", "page_id": parentPageID],
            "title": [["type": "text", "text": ["content": "PennyNote"]]],
            "properties": NotionMapper.databaseSchemaProperties(categoryNames: categoryNames),
        ]
        let request = try NotionRequestBuilder.request(path: "databases", method: "POST", token: token, body: body)
        let json = try await send(request)
        guard let id = json["id"] as? String else { throw NotionError.decoding }
        return id
    }

    func updateCategorySchema(databaseID: String, categoryNames: [String]) async throws {
        let body: [String: Any] = ["properties": NotionMapper.categorySchemaProperties(categoryNames: categoryNames)]
        let request = try NotionRequestBuilder.request(path: "databases/\(databaseID)", method: "PATCH", token: token, body: body)
        _ = try await send(request)
    }

    func createPage(
        databaseID: String,
        amount: Decimal,
        date: Date,
        title: String,
        paymentMethod: PaymentMethod,
        categoryName: String?
    ) async throws -> ParsedNotionPage {
        let body: [String: Any] = [
            "parent": ["database_id": databaseID],
            "properties": NotionMapper.properties(amount: amount, date: date, title: title, paymentMethod: paymentMethod, categoryName: categoryName),
        ]
        let request = try NotionRequestBuilder.request(path: "pages", method: "POST", token: token, body: body)
        let json = try await send(request)
        guard let page = NotionMapper.parsePage(json) else { throw NotionError.decoding }
        return page
    }

    func updatePage(
        pageID: String,
        amount: Decimal,
        date: Date,
        title: String,
        paymentMethod: PaymentMethod,
        categoryName: String?,
        archived: Bool
    ) async throws -> ParsedNotionPage {
        var body: [String: Any] = ["archived": archived]
        body["properties"] = NotionMapper.properties(amount: amount, date: date, title: title, paymentMethod: paymentMethod, categoryName: categoryName)
        let request = try NotionRequestBuilder.request(path: "pages/\(pageID)", method: "PATCH", token: token, body: body)
        let json = try await send(request)
        guard let page = NotionMapper.parsePage(json) else { throw NotionError.decoding }
        return page
    }

    func queryDatabase(
        databaseID: String,
        editedAfter: Date?,
        cursor: String?
    ) async throws -> (pages: [ParsedNotionPage], nextCursor: String?, hasMore: Bool) {
        var body: [String: Any] = ["page_size": 100]
        if let editedAfter {
            body["filter"] = [
                "timestamp": "last_edited_time",
                "last_edited_time": ["on_or_after": NotionMapper.isoDateTime(editedAfter)],
            ]
        }
        if let cursor {
            body["start_cursor"] = cursor
        }

        let request = try NotionRequestBuilder.request(path: "databases/\(databaseID)/query", method: "POST", token: token, body: body)
        let json = try await send(request)
        guard let resultsJSON = json["results"] as? [[String: Any]] else { throw NotionError.decoding }

        let pages = resultsJSON.compactMap(NotionMapper.parsePage)
        let hasMore = json["has_more"] as? Bool ?? false
        let nextCursor = json["next_cursor"] as? String
        return (pages, nextCursor, hasMore)
    }

    private func send(_ request: URLRequest) async throws -> [String: Any] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NotionError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.network(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NotionError.decoding
            }
            return json
        case 401:
            throw NotionError.unauthorized
        case 404:
            throw NotionError.notFound
        case 429:
            let retryAfter = Double(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 1
            throw NotionError.rateLimited(retryAfter: retryAfter)
        case 400:
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = body?["message"] as? String
            throw NotionError.validation(message: message ?? "Petición inválida a Notion.")
        default:
            throw NotionError.network(URLError(.badServerResponse))
        }
    }
}
