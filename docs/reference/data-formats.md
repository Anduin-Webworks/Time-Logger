# Data formats

The current UI exports derived sessions only. Export field names are intentionally technical and English even when the UI is localized.

## Sessions CSV

```text
session_id,start_unix,start_utc,start_local_dt,end_unix,end_utc,end_local_dt,duration_sec,patch,expansion,start_location,end_location,weekday,subscription,subActive,character,realm,status
```

CSV values are escaped when they contain quotes, commas, or line breaks. `subActive` is `1` or `0`.

## Sessions JSON

The output is an array of objects with these keys:

```text
id, start_unix, start_utc, start_local_dt, end_unix, end_utc,
end_local_dt, duration, patch, expansion, start_location,
end_location, weekday, subscription, subActive, char, realm, status
```

The JSON serializer uses the key `duration` for the seconds value and `char` for the character field for compatibility with the current implementation. `subActive` is boolean. JSON strings escape quotes, backslashes, and control characters.

## Raw event fields

Raw events remain in SavedVariables and are not the current UI export mode. Their fields are `unix`, `utc`, `local_dt`, `event`, `character`, `realm`, `patch`, `expansion`, `location`, `weekday`, `subscription`, `subActive`, and optional `recovery`.

