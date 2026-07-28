# Social Brain shared contracts

This directory is the source of truth for data exchanged between Android, iOS,
and Firebase. The payloads are encrypted before they reach Firestore; the
envelope schema intentionally contains no user-created values.

Contract changes require a new versioned directory, cross-platform fixtures,
and backward-compatibility tests before either client ships it. `v1` uses
camelCase JSON names; clients must not emit legacy snake_case extraction fields.
