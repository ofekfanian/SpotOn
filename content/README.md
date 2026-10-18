# Weekly word packs

The app downloads `weekly.json` from this folder (via raw.githubusercontent.com)
at most every 6 hours and caches it on the device. To publish a new pack, add an
entry to `packs` and push to `main`. No app update is needed.

```json
{
  "id": "2026-w43-travel",
  "title": "On the Road",
  "description": "Words for airports, hotels and getting around.",
  "icon": "airplane",
  "publishedAt": "2026-10-25",
  "words": [
    { "en": "layover", "he": "עצירת ביניים", "level": "intermediate" }
  ]
}
```

- `id` must be unique. `icon` is any SF Symbol name.
- `publishedAt` (`yyyy-MM-dd`): the pack stays hidden until that date, so packs
  can be scheduled ahead of time. The dashboard shows the newest published pack.
- `level` is `beginner`, `intermediate` or `advanced`. Pack words also join the
  offline flashcard pool for that level.
