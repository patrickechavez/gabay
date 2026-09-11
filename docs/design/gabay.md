# Gabay

An iPhone app that shows you a trail on a map that works with no signal, shows
where you are on it, and tells you when you have left it. Everything else in
this document serves those three things.

## Why

Hiring a guide prices people out of hiking their own mountains. The trails are
public, the maps are public, and a phone already carries a GPS receiver that
works without a cell tower.

The software is where it stops being free. Strava and AllTrails both charge for
the one thing a hiker on an unfamiliar trail actually needs: loading a route
somebody else made and following it offline. Recording is free on both.
Uploading a finished activity is free on Strava. Following a line up a mountain
is not.

So the gap is narrow and specific: **follow a GPX you did not create, offline,
without paying.** Nobody serves it because there is no business in it.

Gabay, Filipino for guide, fills it from the other end. The trails are curated and given away, the
app follows them offline, the activity is saved on the phone, and it can be
exported as a GPX to Strava or anywhere else. My file in, your walk out, your
data yours.

## Constraints

These are decisions, not wishes. Each one closes off work as much as it opens
it.

- **iPhone only.** Landscape is irrelevant on a trail, and an iPad does not
  come up a mountain.
- **No account, no analytics, no server to run.** Nothing to sign up for,
  nothing to leak, no bill. Where somebody walks is not information this app
  sends anywhere.
- **Offline is the normal case, not a fallback.** The app is developed and
  tested in aeroplane mode. The only network call in the app is the trail
  catalog refresh, which is best effort and invisible when it fails.
- **Free.** No subscription, no tier, no advertisements.

## The map

The renderer is MapLibre, wrapped for SwiftUI in a `UIViewRepresentable`.
MapKit is not an option: Apple offers no way for a third party app to download
map data for offline use, and a map that is only offline by accident of caching
is not a map you take into the backcountry.

Tiles are the harder half. Public tile servers, including OpenStreetMap's own
and OpenTopoMap, forbid bulk downloading, so their tiles cannot be shipped
inside an app. A free tier API key is worse: it is a network dependency wearing
a disguise.

So the app bundles its own tiles, built from OpenStreetMap data, with contour
lines derived from open elevation data. A hiking map without contours is a road
map with a green background.

**Extent.** One contiguous region: the day hike belt around Metro Manila,
covering Rizal, Batangas and Quezon. Roughly fifty megabytes with contours.
Everything inside that boundary has a map, so an imported trail anywhere in the
region works without special handling. A second region is a later release, not
a re-architecture.

**Attribution.** OpenStreetMap data is ODbL. The credit goes on the map screen
and in the About screen, not buried in a settings list.

### The risk this design turns on

MapLibre does not open a local tile archive by itself. Reading a PMTiles or
MBTiles file straight from the app bundle needs a custom source, and whether
the current approaches work on iOS without running a local server is unproven
here.

That is step one of the build: a throwaway spike that renders one bundled tile
file on screen with the device in aeroplane mode. Nothing else starts until it
does.

If it resists, the fallback is `MKTileOverlay` with `canReplaceMapContent`,
pointed at local raster tiles. Apple renders it, it is provably offline, and it
costs styling and storage rather than capability.

## Data

**The trail library** is published separately from the app, in its own public
repository served over GitHub Pages. A `catalog.json` lists every trail with
its name, region, distance, ascent, difficulty, bounding box, revision and the
URL of its GPX file.

Adding a trail is therefore a commit, not a release: drop in the GPX, add its
block to the catalog, push. The app picks it up on the next launch that has a
connection.

A seed catalog and its GPX files ship inside the app, so a fresh install on a
phone that has never had signal still has trails to walk.

Three rules keep the refresh from eroding the offline promise:

- **Silent.** It never blocks a screen, never spins, never raises an error. A
  trail app that complains about connectivity at a trailhead has missed the
  point.
- **Cheap.** The app sends the ETag it holds and does nothing on a 304. Only
  new or revised GPX files are fetched.
- **Additive.** Nothing is ever deleted from under a user. A trail removed from
  the catalog stays on the phone of anyone who already has it. They downloaded
  it, and they might be standing on it.

**Coverage.** Tiles cover Rizal, Batangas and Quezon. A trail published outside
that box still downloads and still draws its route line, but the detail screen
says plainly that there is no map underneath. Better learned in the car park
than at the trailhead.

**GPX parsing** uses `XMLParser` from Foundation. No dependency. It handles
tracks, routes and waypoints, and it is written against fixture files including
malformed ones, because a file picker will eventually be handed something
strange.

**Imported trails** are copied into Documents and read back from there. They
are files, so the file system is the database.

**Recorded activities** go in SwiftData, which is the one thing worth querying:
by date, by trail, by distance.

## Location

The location background mode is on, with `allowsBackgroundLocationUpdates`,
`activityType = .fitness`, and `pausesLocationUpdatesAutomatically = false`.

That last setting matters more than it looks. Left at its default, iOS decides
on its own that you have stopped moving and quietly ends the track, which is
one of the two ways a recorded route turns into a straight line across a
valley. The other is the app being suspended when the screen locks, which the
background mode prevents.

Foreground only tracking was considered and rejected. Nobody runs twenty
kilometres holding an unlocked phone, so foreground only guarantees the exact
defect it was meant to avoid.

The app still says plainly on first run that it keeps tracking with the screen
off. Battery is the user's to manage, and they can only manage what they are
told.

## Screens

**Trail list.** Bundled and imported together, each with distance, ascent and
difficulty.

**Trail detail.** Map preview, elevation profile, and a Start button.

**Navigate.** The screen that matters. Full screen map, route drawn in magenta
over a white casing so it reads against forest and rock alike, current
position, follow mode, and a bottom bar with distance remaining and ascent
left. Type is larger than a normal app throughout: this is read while moving
and out of breath.

**Off route.** A banner and a haptic at roughly fifty metres from the line,
debounced hard enough that a GPS wobble under tree cover does not cry wolf.

**Where am I.** One tap from the map. Coordinates in a form that can be read
aloud over a radio or typed into a message if a single bar appears. This is the
feature that earns the phrase "hike safely without a guide", and it costs
almost nothing to build.

**Import.** The native file picker through `.fileImporter`.

**History.** Recorded activities, with the route and the numbers.

**Export.** A finished activity leaves as a GPX file through the share sheet,
which is how it reaches Strava, which accepts activity uploads for free. No API
integration, no OAuth, no account, and nothing to maintain when somebody else's
API changes. The About screen says so in as many words: Gabay uploads nothing,
your activity is a file on your phone, take it wherever you like.

## Look

- Accent: magenta, `#E5007E`. The map already owns green, blue and brown, and
  nothing in terrain is magenta, which is why cartographers reach for it when a
  line has to be unmistakable. It is also nowhere near Strava's orange or
  AllTrails' green.
- Route line: accent over a white casing.
- Surfaces: near black with warm grey text. Easier on an OLED battery, and
  easier at night.
- Icon: a switchback climbing to a summit dot, off white on dark slate with the
  dot in magenta. Legible at forty pixels, and not another compass rose.

## Architecture

```
View (SwiftUI, no logic)
  ↕ @Observable
ViewModel (@MainActor)
  ↕ protocol
TrailLibrary · LocationTracker · ActivityStore
  ↕
Bundle files · CoreLocation · SwiftData
```

Three seams carry protocols. The trail library, so previews and tests read
fixtures rather than the bundle. The location tracker, so a simulated one can
replay a GPX file as fake GPS and the whole flow can be tested sitting down.
The activity store, so recording can be tested without touching a database.

## Testing

- GPX parsing against real files, including truncated and malformed ones
- Distance and ascent calculations against known routes
- Off route detection against a synthetic track that leaves and rejoins
- Trail library loading from a fixture bundle
- The navigate flow driven by the replaying location tracker

## Build order

Each slice is usable on its own. The first three already make the app worth
carrying up a mountain.

1. Spike the offline tiles
2. GPX parsing, the bundled seed library, list and detail with elevation profile
3. Map, route, position, follow mode
4. Off route, where am I, battery warning
5. Catalog refresh from the trail repository
6. Custom import
7. Recording, history, and export as GPX

## Repositories

Two, with different lifecycles.

- **The app.** Released through the App Store, changes rarely.
- **The trails.** GPX files and `catalog.json`, served over GitHub Pages,
  changes whenever a trail is walked. Public, so the files are useful to
  somebody even if they never install the app.

## Not in this version

- A second region
- Turn by turn or voice guidance
- Sharing, social features, leaderboards
- Apple Watch
- Trail conditions, comments, or anything else that needs a server

## Spike result: bundled tiles

Answered on 11 September 2026, on the `spike/offline-tiles` branch.

**MapLibre reads a tile archive from the app bundle.** No local server, no
custom source, no third-party PMTiles reader. MapLibre iOS 6.10 added PMTiles
support and range requests to its asset file source, so a style can point
straight at a file that shipped with the app:

```json
"sources": {
  "protomaps": { "type": "vector", "url": "pmtiles://asset://spike.pmtiles" }
}
```

The style itself is written to a temporary file at launch and loaded from
there, because MapLibre takes a style URL rather than a style object.

Proven with a 6.3MB Protomaps extract of Florence: it rendered earth, water,
landuse, roads and buildings. Renaming the file inside the installed app made
the map fall back to MapLibre's built-in world style instead, which is what
proves the pixels came from the bundle rather than from the network.

So the plan in this document holds, and `MKTileOverlay` stays unused.

The dependency is `maplibre-gl-native-distribution`, BSD licensed, added
through SPM. It is the only third-party code in the app.

Still to do, and a separate job: producing the real extract for Rizal,
Batangas and Quezon with contour lines, rather than a sample of an Italian
city.
