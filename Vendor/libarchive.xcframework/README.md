# libarchive.xcframework

Place the prebuilt, redistributable `libarchive.xcframework` contents in this directory.

The app's archive reader loads libarchive dynamically, preferring the app bundle's
`Contents/Frameworks/libarchive.framework/libarchive` or `Contents/Frameworks/libarchive.dylib`.

The first archive feature only needs these libarchive APIs:

- `archive_read_new`
- `archive_read_support_filter_all`
- `archive_read_support_format_zip`
- `archive_read_support_format_tar`
- `archive_read_support_format_7zip`
- `archive_read_open_filename`
- `archive_read_next_header`
- `archive_read_data_skip`
- `archive_read_close`
- `archive_read_free`
- `archive_error_string`
- `archive_entry_pathname`
- `archive_entry_filetype`
- `archive_entry_size_is_set`
- `archive_entry_size`
- `archive_entry_mtime_is_set`
- `archive_entry_mtime`
