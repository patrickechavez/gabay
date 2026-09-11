# Trails

The GPX files this app offers, served over GitHub Pages at
`https://patrickechavez.github.io/gabay/trails`.

## Adding a trail

1. Upload the `.gpx` file into this folder.
2. Add a block to `catalog.json`.
3. Commit. The app picks it up on the next launch with a connection.

No app release is needed.

## An entry

```json
{
  "id": "osmena-peak",
  "name": "Osmeña Peak",
  "region": "Cebu",
  "distanceM": 5200,
  "ascentM": 388,
  "difficulty": "easy | moderate | hard",
  "revision": 1,
  "gpx": "osmena.gpx",
  "bounds": { "north": 9.82, "south": 9.79, "east": 123.41, "west": 123.37 }
}
```

`id` never changes once published: it names the file on the walker's phone.
`gpx` is the bare filename, since the app's catalog URL already points here.
Raise `revision` when you replace a file, so phones holding the old one
know to fetch it again.
