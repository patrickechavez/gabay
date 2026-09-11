//
//  GPXWriter.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import Foundation

// Writes a walk as it happens. A crash leaves a shorter walk, never nothing.
actor GPXWriter {

    private let url: URL
    private let handle: FileHandle
    private let formatter: ISO8601DateFormatter

    private var isOpen = true

    init(url: URL, name: String, kind: Activity.Kind, startedAt: Date) throws {
        self.url = url

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        self.formatter = formatter

        let header = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Gabay" xmlns="http://www.topografix.com/GPX/1/1">
         <metadata><time>\(formatter.string(from: startedAt))</time></metadata>
         <trk>
          <name>\(GPXWriter.escape(name))</name>
          <type>\(kind.gpxType)</type>
          <trkseg>

        """

        try Data(header.utf8).write(to: url, options: .atomic)
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    func append(_ point: TrackPoint) {
        guard isOpen else { return }

        var element = String(
            format: "   <trkpt lat=\"%.7f\" lon=\"%.7f\">",
            point.latitude, point.longitude
        )
        if let elevation = point.elevation {
            element += String(format: "<ele>%.1f</ele>", elevation)
        }
        if let time = point.time {
            element += "<time>\(formatter.string(from: time))</time>"
        }
        element += "</trkpt>\n"

        try? handle.write(contentsOf: Data(element.utf8))
    }

    // Closes the tags a reader expects. Not reaching here is survivable.
    func finish() {
        guard isOpen else { return }
        isOpen = false

        try? handle.write(contentsOf: Data("  </trkseg>\n </trk>\n</gpx>\n".utf8))
        try? handle.close()
    }

    // Swaps the name and type a walk was started with for the ones it was saved with.
    nonisolated static func relabel(
        _ url: URL,
        from old: (name: String, kind: Activity.Kind),
        to new: (name: String, kind: Activity.Kind)
    ) {
        guard var text = try? String(contentsOf: url, encoding: .utf8) else { return }

        text = text.replacingOccurrences(
            of: "<name>\(escape(old.name))</name>",
            with: "<name>\(escape(new.name))</name>"
        )
        text = text.replacingOccurrences(
            of: "<type>\(old.kind.gpxType)</type>",
            with: "<type>\(new.kind.gpxType)</type>"
        )

        try? Data(text.utf8).write(to: url, options: .atomic)
    }

    // A trail called "Bonita & Lhuillier" must not break the file.
    nonisolated static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
