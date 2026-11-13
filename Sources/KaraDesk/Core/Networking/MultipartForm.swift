import Foundation

struct MultipartForm: Sendable {
    let boundary: String
    private var data = Data()

    init(boundary: String) {
        self.boundary = boundary
    }

    func adding(fields: [String: String]) -> MultipartForm {
        var form = self

        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            form.append("--\(boundary)\r\n")
            form.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            form.append("\(value)\r\n")
        }

        return form
    }

    func adding(file: Data, field: String, filename: String, contentType: String) -> MultipartForm {
        var form = self
        let safeName = filename.replacingOccurrences(of: "\"", with: "")
        form.append("--\(boundary)\r\n")
        form.append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(safeName)\"\r\n")
        form.append("Content-Type: \(contentType)\r\n\r\n")
        form.data.append(file)
        form.append("\r\n")
        return form
    }

    func encoded() -> Data {
        var result = data
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }

    private mutating func append(_ string: String) {
        data.append(Data(string.utf8))
    }
}
