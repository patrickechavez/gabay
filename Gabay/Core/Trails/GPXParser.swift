//
//  GPXParser.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// What a GPX file turned out to hold.
struct GPXDocument: Equatable, Sendable {

    var name: String?

    var tracks: [Track]

    // Every point in the file, in order, across all tracks.
    var points: [TrackPoint] { tracks.flatMap(\.points) }
}

enum GPXError: Error, Equatable {
    case notXML
    case noPoints
}

// Reads GPX into points. A track and a route are both a line to follow.
struct GPXParser {

    func parse(_ data: Data) throws -> GPXDocument {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader

        // A truncated file parses up to the break, so what was read still counts.
        let finished = parser.parse()

        let document = reader.document()
        guard finished || !document.points.isEmpty else { throw GPXError.notXML }
        guard !document.points.isEmpty else { throw GPXError.noPoints }
        return document
    }
}

private extension GPXParser {

    // GPX is small and read once, so streaming beats loading a DOM.
    final class Reader: NSObject, XMLParserDelegate {

        private var tracks: [Track] = []
        private var documentName: String?

        private var currentTrack: Track?
        private var currentPoint: PartialPoint?
        private var text = ""

        // Depth matters: <name> means different things inside <gpx> and <trk>.
        private var elements: [String] = []

        private struct PartialPoint {
            let latitude: Double
            let longitude: Double
            var elevation: Double?
            var time: Date?
        }

        // Per reader: a formatter is not safe across threads.
        private let timeFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        private let plainTimeFormatter = ISO8601DateFormatter()

        func document() -> GPXDocument {
            GPXDocument(name: documentName, tracks: finishedTracks())
        }

        private func finishedTracks() -> [Track] {
            var all = tracks
            // A file cut off mid track still has the points read so far.
            if let currentTrack, !currentTrack.points.isEmpty { all.append(currentTrack) }
            return all.filter { !$0.points.isEmpty }
        }

        func parser(
            _ parser: XMLParser,
            didStartElement element: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            elements.append(element)
            text = ""

            switch element {
            case "trk", "rte":
                currentTrack = Track(name: nil, points: [])

            case "trkpt", "rtept", "wpt":
                guard let latitude = Double(attributes["lat"] ?? ""),
                      let longitude = Double(attributes["lon"] ?? "") else { return }
                currentPoint = PartialPoint(latitude: latitude, longitude: longitude)

            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters characters: String) {
            text += characters
        }

        func parser(
            _ parser: XMLParser,
            didEndElement element: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            defer {
                if elements.last == element { elements.removeLast() }
                text = ""
            }

            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

            switch element {
            case "ele":
                currentPoint?.elevation = Double(value)

            case "time":
                currentPoint?.time = date(from: value)

            case "name":
                name(value)

            case "trkpt", "rtept":
                append(currentPoint)
                currentPoint = nil

            case "wpt":
                // A landmark is not part of the line, so it is dropped.
                currentPoint = nil

            case "trk", "rte":
                if let currentTrack, !currentTrack.points.isEmpty { tracks.append(currentTrack) }
                currentTrack = nil

            default:
                break
            }
        }

        private func name(_ value: String) {
            guard !value.isEmpty else { return }

            // The first name inside a track wins, anything outside names the file.
            if var track = currentTrack {
                if track.name == nil {
                    track.name = value
                    currentTrack = track
                }
            } else if documentName == nil {
                documentName = value
            }
        }

        private func append(_ point: PartialPoint?) {
            guard let point else { return }

            let track = TrackPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                elevation: point.elevation,
                time: point.time
            )

            // Points outside any track still count: some writers omit <trk>.
            if currentTrack == nil { currentTrack = Track(name: nil, points: []) }
            currentTrack?.points.append(track)
        }

        private func date(from value: String) -> Date? {
            timeFormatter.date(from: value) ?? plainTimeFormatter.date(from: value)
        }
    }
}
