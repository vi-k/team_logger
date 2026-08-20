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
  files to a temporary directory, then listing and archiving them.
- `bin/readme_examples/` — the code behind the sections of the package's
  main README. These are not standalone programs: the screenshots in the
  README were taken frame by frame, with the surrounding lines commented
  out by hand, so the pictures are the source of truth and this code is the
  material they were shot from.
