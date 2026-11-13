import Foundation

struct APIClient: Sendable {
    static let apiBaseURL = URL(string: "https://api.karadesk.com")!

    let baseURL: URL
    let session: URLSession
    let userAgent: String

    init(baseURL: URL = APIClient.apiBaseURL, session: URLSession = .karaDesk, userAgent: String) {
        self.baseURL = baseURL
        self.session = session
        self.userAgent = userAgent
    }

    func send<Response>(_ request: APIRequest<Response>, token: String?) async throws(KaraDeskError) -> Response {
        let urlRequest = try makeURLRequest(request, token: token)
        let (data, response) = try await perform(urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw .unexpectedResponse
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.error(status: http.statusCode, data: data)
        }

        do {
            return try Coding.decoder().decode(Response.self, from: data)
        } catch {
            Log.network.error("Couldn't decode \(request.path, privacy: .public): \(String(describing: error), privacy: .public)")
            throw .unexpectedResponse
        }
    }

    func upload(_ file: Data, named filename: String, contentType: String, to target: UploadTicket.Upload) async throws(KaraDeskError) {
        let boundary = "KaraDesk-\(UUID().uuidString)"
        var request = URLRequest(url: target.url)
        request.httpMethod = target.method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartForm(boundary: boundary)
            .adding(fields: target.fields)
            .adding(file: file, field: "file", filename: filename, contentType: contentType)
            .encoded()

        let (_, response) = try await perform(request)

        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw .server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: String(localized: "error.upload", defaultValue: "The upload failed. Please try again.", bundle: .module))
        }
    }

    func makeURLRequest<Response>(_ request: APIRequest<Response>, token: String?) throws(KaraDeskError) -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: request.path), resolvingAgainstBaseURL: false) else {
            throw .unexpectedResponse
        }

        if !request.query.isEmpty {
            components.queryItems = request.query
        }

        guard let url = components.url else {
            throw .unexpectedResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        if let token, request.requiresSession {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = request.body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                urlRequest.httpBody = try Coding.encoder().encode(body)
            } catch {
                throw .unexpectedResponse
            }
        }

        return urlRequest
    }

    private func perform(_ request: URLRequest) async throws(KaraDeskError) -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw .network(error.code)
        } catch {
            throw .network(.unknown)
        }
    }

    static func error(status: Int, data: Data) -> KaraDeskError {
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message
            ?? HTTPURLResponse.localizedString(forStatusCode: status)

        switch status {
        case 401 where message.localizedCaseInsensitiveContains("identity") || message.localizedCaseInsensitiveContains("hash"):
            return .identityVerificationFailed(message)
        case 403, 404:
            return .unavailable(message)
        default:
            return .server(statusCode: status, message: message)
        }
    }

    private struct ErrorBody: Decodable {
        var message: String
    }
}

extension URLSession {
    static let karaDesk: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}
