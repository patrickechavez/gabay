//
//  MultipartFormData.swift
//  Gabay
//

import UIKit

struct MultipartFormData {
    let boundary: String
    private var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(_ name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(Self.headerSafe(name))\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func addFile(_ name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n")
        append("""
            Content-Disposition: form-data; name="\(Self.headerSafe(name))"; \
            filename="\(Self.headerSafe(filename))"\r\n
            """)
        append("Content-Type: \(Self.singleLine(mimeType))\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    // Names land inside a quoted header value, so a quote ends the value early and a newline ends
    // the header outright, letting a crafted name forge headers or corrupt the body. Escaping `%`
    // first keeps the transform injective.
    private static func headerSafe(_ value: String) -> String {
        singleLine(
            value
                .replacingOccurrences(of: "%", with: "%25")
                .replacingOccurrences(of: "\"", with: "%22")
                .replacingOccurrences(of: "\\", with: "%5C")
        )
    }

    // A media type is not a quoted value and may carry parameters such as `charset="utf-8"`, so
    // only the line break is dangerous here. Percent-escaping it would corrupt a valid type.
    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    mutating func addImage(_ image: UIImage,
                           name: String,
                           filename: String = "image.jpg",
                           compression: ImageCompression = .fullScreen) {
        guard let data = image.jpegData(for: compression) else { return }
        addFile(name, filename: filename, mimeType: "image/jpeg", data: data)
    }

    func encoded() -> Data {
        var data = body
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}
