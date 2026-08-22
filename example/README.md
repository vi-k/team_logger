# team_logger examples

`example.dart` is one request through the logger, end to end: a namespace
sublogger with a tag, a trace id that follows the asynchronous flow, a
request logged as headers and body, a response object that decides how it
prints itself, a redacted `authorization` header and a failure with its
stack trace.

```bash
dart pub get
dart run example.dart
```

Also here:

- `bin/file_storage_example.dart` — the same logger writing JSONL session
  files to a temporary directory, then listing them and exporting the
  selected sessions into one gzipped JSON Lines file.
- `bin/readme_examples/` — the code behind the sections of the package's
  main README, and the source the screenshots are built from. Each file
  declares a map of picture name to the function that draws it and hands it
  to `runFrames`: `--list` prints the names, a name runs that one frame
  under a fixed clock, and no argument runs them all. Nothing is commented
  out by hand — `scripts/screenshots.sh` in the package root shoots every
  frame in its own process, so a rebuild returns the same bytes until the
  frame itself changes.
