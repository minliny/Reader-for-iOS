# libmobi in Reader

Reader uses the unmodified library sources from the upstream
[libmobi v0.12 release](https://github.com/bfabiszewski/libmobi/tree/v0.12).
The archive digest and source URL are recorded in `UPSTREAM.json`. `src/` retains
upstream copyright headers; `COPYING` is LGPL version 3 or later and
`COPYING.GPL` supplies the incorporated GPL version 3 text. The three files in
`tests/samples/` are upstream regression fixtures, not user book files.

## Ownership and build

The adapter is `crates/reader-local-book/src/mobi_bridge.c`, outside the upstream
source directory. It calls libmobi through its public interface. The C library
decodes PalmDOC/HUFF-CDIC records and reconstructs MOBI/KF8 markup, navigation and
resources. Rust owns admission, limits, metadata, reading order, text projection,
cache transactions and position protection. Harmony Host owns the retained
original and bounded resource access.

`crates/reader-local-book/build.rs` compiles the selected library sources and the
adapter with `cc`. It uses the internal XML writer and platform zlib. Encryption
is disabled; dictionaries and fixed-layout replica files are rejected by the
adapter. Upstream command-line tools and DRM helpers are not built. The Rust
static library contains the decoder; Harmony NAPI links it with `z` in
`bindings/harmony/native/CMakeLists.txt`.

The adapter receives bytes and emits bounded reconstructed entries through a
synchronous callback. Rust currently builds a temporary in-memory package to
reuse the EPUB spine/anchor/image projection. This package is not persisted and
does not replace the original content hash. Resource requests reconstruct from
the retained original. This implementation still needs device memory,
cancellation and repeated-image performance acceptance; it is not an incremental
or streaming decoder.

## Rebuilding with a modified library

Keep an unmodified source copy for comparison. Modify this directory's `src/`
files (or replace them with an interface-compatible version and adapt the
explicit source list). Cargo watches that directory and rebuilds the library.
From the Core repository, the native host regression command is:

```sh
cargo test -p reader-local-book --locked
```

For an OHOS build, install the Rust version in `rust-toolchain.toml` and the
Harmony SDK, then use the existing source build entry:

```sh
OHOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default \
  ./scripts/build-harmony-napi.sh
```

This rebuilds and relinks the Rust Core and NAPI with the modified decoder. It
does not install an application. Package, signing and installation instructions
are in the workspace `HAP_BUILD_SYSTEM.md`; they bind the rebuilt native library
to the HAP manifest. Signing credentials are local inputs, not library source.

## Distribution materials

The integration uses static linking. A distributed combined binary must be
accompanied by the applicable notices and the materials required to rebuild or
relink it with a modified library under LGPL section 4. For Reader's source-based
delivery, retain the exact Core and Harmony source revisions, this library and
adapter, lockfiles, build scripts, SDK/toolchain identification, and any required
installation information. A link to an unrelated upstream revision or a binary
alone is insufficient. If a source release cannot provide the corresponding
application code, prepare and verify suitable relinkable object materials before
that binary is distributed. Do not restrict modification of the library or
reverse engineering needed to debug such modifications.

Harmony includes `libmobi-NOTICE.txt`, `libmobi-LGPL-3.0.txt` and
`libmobi-GPL-3.0.txt` under `entry/src/main/resources/rawfile/licenses/`. These
notices identify the source and licensing; they do not by themselves establish
that the complete distribution and installation requirements have been met.
Any application copyright/attribution display must include libmobi and direct
users to the license copies. Verify replacement-library rebuild and installation
with the actual release materials before claiming release readiness.
