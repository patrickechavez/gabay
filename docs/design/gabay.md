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

Two stages, and the first one ships.

### Now: MapKit, with the route and the dot

`MKMapView` draws the basemap, the route as a polyline, and the user's
position. No dependency, no tile files, nothing to build or host.

Apple serves those tiles from Apple's servers and offers no way to download
them ahead of time, so **the basemap disappears when the signal does.** What
survives is everything that matters most: the route line and the current
position are drawn by the app from data already on the phone, so on a mountain
with no bars the screen is a magenta line on grey with a dot on it.

That is a deliberate trade, not an oversight. The question a lost hiker asks is
"am I still on the trail", and a line with a dot on it answers that. What is
lost is context: no terrain, no ridges, no rivers, and no way to see that the
path in front of you is the one on the screen.

MapKit caches tiles it has already drawn, so a map opened at the trailhead may
persist for a while. That is undocumented and unpredictable, and no claim rests
on it.

**What this means for the README.** The route works offline. The map does not.
Those are two different sentences and the app must not blur them.

### Later: MapLibre and downloaded region packs

The upgrade is a real offline basemap, and the design for it stands:

Tiles built from OpenStreetMap data with contour lines from open elevation
data, because a hiking map without contours is a road map with a green
background. Public tile servers forbid bulk downloading and free tier API keys
are a network dependency in disguise, so the app carries its own.

A nationwide overview ships in the app, a few megabytes, so it is never blank.
Detail arrives as **region packs**, one file each, listed in the same catalog as
the trails and fetched the same way. Cebu first. A trail knows which pack it
needs, so the trail screen says "needs the Cebu map, 24 MB" and offers to fetch
it, and the user never has to think in regions.

This is the shape Strava and AllTrails use without the part that costs money,
and it is what OsmAnd and Organic Maps have done for a decade with their own
formats. Region packs are static files on a CDN: no tile server, no per request
billing, no free tier to outgrow.

The spike proved MapLibre reads such a file from the app bundle. A downloaded
pack lives in Application Support instead, so its source URL becomes a file
path rather than `asset://`, and that variant is unproven.

**Why it is not first.** Producing a pack needs tooling to run somewhere, and
that somewhere is a build machine. Until that exists, MapKit gets a working
follow screen into people's hands, and the geometry underneath it, distance
remaining, progress along the line, off route detection, belongs to the app
rather than to the map, so it survives the swap.

**Attribution.** Apple's attribution is built into MapKit. When the packs
arrive, OpenStreetMap's credit goes on the map screen and in About, since the
data is ODbL.

## Data

**The catalog** is published from this repository, under a `trails/` folder
served over GitHub Pages. `catalog.json` lists two things: trails, each with
its name, region, distance, ascent, difficulty, bounding box, revision and GPX
URL, and region packs, each with its name, bounds, size and file URL.

Adding a trail, or a whole province, is therefore a commit rather than a
release: drop in the file, add its block to the catalog, push. The app picks it
up on the next launch that has a connection.

**No trails ship inside the app.** A fresh install is empty until it either
reaches the catalog or is handed a file. That is deliberate: the library is
meant to grow without releases, and a set of trails baked into the binary would
be stale the moment it shipped, as well as carrying megabytes nobody in another
province wants.

The consequence, stated plainly: the first run needs either a connection or a
GPX file. The empty state says so, and offers the import button rather than
apologising.

Three rules keep the refresh from eroding the offline promise:

- **Silent.** It never blocks a screen, never spins, never raises an error. A
  trail app that complains about connectivity at a trailhead has missed the
  point.
- **Cheap.** The app sends the ETag it holds and does nothing on a 304. Only
  new or revised GPX files are fetched.
- **Additive.** Nothing is ever deleted from under a user. A trail removed from
  the catalog stays on the phone of anyone who already has it. They downloaded
  it, and they might be standing on it.

**Coverage.** A trail names the region pack it needs. If that pack is not on
the phone, the trail screen says so and offers to fetch it, with the size
stated. Better learned in the car park than at the trailhead.

**Downloads on disk.** Region packs and GPX files both land in Application
Support, excluded from iCloud backup: they are large, they are replaceable, and
backing up a province of map tiles helps nobody.

**GPX parsing** uses `XMLParser` from Foundation. No dependency. It handles
tracks, routes and waypoints, and it is written against fixture files including
malformed ones, because a file picker will eventually be handed something
strange.

**Imported trails** are copied into Application Support and read back from
there. They are files, so the file system is the database. Once imported, a
user's own file is indistinguishable from one of ours.

### Where things live on disk

```
Application Support/
├── Trails/        downloaded and imported GPX
├── Activities/    one GPX per recorded walk
└── Packs/         region packs, when the map exists
```

Not `Caches`. iOS empties that folder whenever storage runs low, without
warning. A recorded walk disappearing because the phone was full is the kind of
bug that loses a user permanently.

All three are excluded from iCloud backup: they are large and replaceable, and
a backup full of map tiles helps nobody. Activities are the arguable exception,
and they leave through the share sheet instead.

### Recorded activities

Every walk is written as a real GPX file, one per activity, in the same format
the app reads. Beside it, a SwiftData row holds only the summary: name, date,
type, distance, moving time, ascent, and which file it belongs to.

That split does three jobs. The history list is a cheap query over small rows,
so it opens instantly with hundreds of walks behind it. Export is a file copy
rather than a conversion, because the GPX already exists. And the durable
artifact is a standard file, readable by anything, so a lost database is an
inconvenience rather than a loss.

Storing every point as a database row was the alternative: thousands of rows
per activity, and a conversion on every share.

The file is written as the walk happens, not at the end. A crash or a battery
death partway through leaves a shorter walk rather than nothing, which is the
same reasoning that makes the parser keep what it read from a truncated file.

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

Three tabs: **Trails**, **Record**, **History**. The offline basemap arrives
later and changes none of this: the route line and the position are drawn by
the app, so every screen below already works without a connection.

### Trails

The whole catalog in one list, with distance, ascent and region. Trails already
on the phone and trails still to download look the same, except for a small
tag on the ones that need fetching. There is no downloads screen and no manage
storage screen: downloading is a consequence of opening a trail, not a chore of
its own.

Importing a GPX is a `+` in the navigation bar, through `.fileImporter`, and
the empty list offers the same button in the middle of the screen. An imported
trail joins the same list and is indistinguishable afterwards.

The catalog is cached on disk beside the trails, so the list is there before
the network is, and a 304 or a failed refresh leaves it standing.

### Trail detail

The map, full bleed: the route in magenta over a white casing, your position,
the heading cone, and a line saying how far the start is. The stats panel that
used to sit here was removed deliberately; the numbers are already in the list
row, and on this screen the line is the point.

A floating **Start** sits above the bottom edge, where the stats bar appears
once recording begins, so the screen grows rather than changes.

### Record

The same Start without a trail. Nothing to follow, just track where you go. A
line says whether the GPS has a fix yet, and that is the whole tab. It exists
so a plain walk is one tap from anywhere rather than buried behind a trail.

### Recording

One screen for both cases, because they differ by one element.

The map fills it, drawing the trail if there is one, the track growing behind
you, your dot and the cone. Following the line is why the app exists, so the
line is never hidden behind numbers.

The bar across the bottom reads "2.4 of 6.2 km" with a thin progress bar on a
trail, because there the only question is how much further. Without a trail
there is no fraction, so the bar goes and it reads "3.8 km". Underneath:
elapsed time, ascent, and battery.

Battery is there deliberately. The app holds the GPS open for hours in places
where a flat phone is a real problem, and showing the number is a small
honesty. The screen is allowed to sleep; recording does not depend on it being
awake.

Type is larger than a normal app throughout. This is read while moving and out
of breath.

**Stopping takes two taps.** The bar shows Pause while recording, and Resume
and Finish once paused. A single Stop is too easy to catch in a pocket, and a
walk cannot be un-ended.

"2.4 of 6.2" is distance walked against the trail's total length, not progress
projected onto the line. Honest and cheap. Projecting onto the polyline is
better and can come later.

**Where am I** is a button here, not a screen: coordinates in a form that can
be read aloud over a radio or typed into a message if a single bar appears.
This is the feature that earns the phrase "hike safely without a guide", and it
costs almost nothing to build.

### Finished

An editable name, prefilled with the trail's name or the time of day. The type,
walk, run or hike, chosen here rather than before starting, so nothing stands
between a cold trailhead and Start. Then what was actually walked: distance,
elapsed time, ascent and pace, over a small preview of the route.

Discard throws it away. Save keeps it.

A recording with no trail is named for its type and time, "Morning walk", and
can be renamed here or later. The app cannot do better: naming it "Budlaan"
would need offline geocoding, which is map data the phone may not have.

### History

Every saved walk with its date, type, distance and time, newest first. Tapping
one opens the track on the map with the numbers beneath it, a share button in
the toolbar, and Delete at the bottom.

### Export

A finished activity leaves as a GPX file through the share sheet, which is how
it reaches Strava, which accepts activity uploads for free. No API integration,
no OAuth, no account, and nothing to maintain when somebody else's API changes.
The GPX carries the activity type, so it arrives as a run rather than as
something unlabelled.

The About screen says it plainly: Gabay uploads nothing, your activity is a
file on your phone, take it wherever you like.

### How a walk is written

Points are appended to the GPX as they arrive, not held in memory until the
end. A crash or a flat battery therefore leaves a file without its closing
tags, and the parser already keeps what it read from a truncated file. On the
next launch an unfinished file becomes a saved walk rather than a prompt, and
it can be deleted like any other.

Fixes worse than thirty metres are dropped rather than drawn, and
`pausesLocationUpdatesAutomatically` stays off so iOS never decides on the
walker's behalf that they have stopped.

### What the activity type actually does

It is a label and an export stamp, so a run arrives at Strava as a run. It does
not change how often the app asks for a position, because it is chosen after
the walk rather than before it. Varying the sampling rate by type was the
alternative, and it costs the one thing worth protecting: a start button with
nothing in front of it.

### Later, when the map exists

The recording screen gains nothing structurally; the basemap underneath it
simply survives losing signal. Off route warning with a banner and a haptic at
roughly fifty metres from the line, debounced hard enough that a GPS wobble
under tree cover does not cry wolf.

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
TrailLibrary · LocationTracker · ActivityStore · TrailCatalogClient
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
- A recording driven end to end by the replaying location tracker, with and
  without a trail attached
- Writing a recorded activity back out as GPX, and reading it in again
- Trail library loading from a fixture bundle
- Off route detection against a synthetic track that leaves and rejoins, once
  that exists

## Build order

Each slice is usable on its own. The first three already make the app worth
carrying up a mountain.

1. Spike the offline tiles, done
2. GPX parsing, the trail collection, the list and detail with its elevation
   profile
3. The map: route drawn on MapKit, current position, follow
4. Recording, both ways in, with the summary screen
5. History, saving, and export as GPX
6. Where am I
7. Catalog refresh, and downloading trails that are not yet on the phone
8. The Cebu pack and the nationwide overview, built on CI rather than a laptop
9. Swap MapKit for MapLibre and the packs, so the basemap survives losing
   signal

The map is third because it is the point: a downloaded trail, drawn on screen,
with your position on the line. Only the offline half of it is deferred, to the
end, because that half needs tooling and hosting that the rest of the app does
not.

## Repository

One, holding both the app and the trails it serves.

- **The app.** Released through the App Store, changes rarely.
- **The trails.** GPX files and `catalog.json` under `trails/`, served over
  GitHub Pages, changing whenever a trail is walked. A commit publishes a
  trail without shipping a release.

## Not in this version

- A second region
- Turn by turn or voice guidance
- Sharing, social features, leaderboards
- Apple Watch
- Trail conditions, comments, or anything else that needs a server

## Spike result: local tiles

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

The spike proved the bundle case. A downloaded pack sits in Application Support
rather than the bundle, so the source URL becomes a file path rather than
`asset://`. That variant is unproven and is the first thing to check when the
Cebu pack exists.

The dependency is `maplibre-gl-native-distribution`, BSD licensed, added
through SPM. It is the only third-party code in the app.

Still to do, and a separate job: producing the nationwide overview and the
Cebu pack with contour lines, rather than a sample of an Italian city.
