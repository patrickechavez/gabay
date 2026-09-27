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

    // `value` is deliberately not escaped: it is the part's body, not a header, so a line break in
    // it is content. It cannot forge a boundary either, since the boundary is a random UUID.
    mutating func addField(_ name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(Self.headerSafe(name))\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func addFile(_ name: String, filename: String, mimeType: String, data: Data) {
        let disposition = "form-data; name=\"\(Self.headerSafe(name))\"; "
            + "filename=\"\(Self.headerSafe(filename))\""

        append("--\(boundary)\r\n")
        append("Content-Disposition: \(disposition)\r\n")
        append("Content-Type: \(Self.singleLine(mimeType))\r\n\r\n")
        body.append(data)
        append("\r\n")
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

    // A name lands inside a quoted header value, where a quote ends the value early and a line
    // break ends the header outright, letting a crafted filename forge headers or corrupt the body.
    // `%` is escaped first so the transform stays reversible: otherwise a literal `%22` in the
    // input and an escaped quote become indistinguishable. Percent-encoding rather than backslash
    // quoting because RFC 7578 tells senders not to use the latter.
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

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}
