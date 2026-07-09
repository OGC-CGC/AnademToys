# AnademToys

## Versioning

AnademToys uses Xcode build settings as the source of truth for app versions:

- `MARKETING_VERSION` is the user-facing version string.
- `CURRENT_PROJECT_VERSION` is the build number.

Pre-release beta versions use this format:

```text
MAJOR.MINOR.PATCH-bN
```

For example, `0.0.1-b2` means the second beta of version `0.0.1`.

The current version is:

- `MARKETING_VERSION`: `0.0.1-b2`
- `CURRENT_PROJECT_VERSION`: `2`
