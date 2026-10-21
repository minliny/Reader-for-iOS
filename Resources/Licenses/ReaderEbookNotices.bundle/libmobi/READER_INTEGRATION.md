# libmobi in Reader for iOS

Reader Core revision `1411965a65a0f3098c02679be5ef979ae9462867` uses libmobi
v0.12 from the upstream project recorded in `UPSTREAM.json`. That file records
the release tag and archive SHA-256, not an upstream Git commit. The selected
library sources are unmodified, retain their copyright headers, and are
licensed LGPL-3.0-or-later. `COPYING` and `COPYING.GPL` are the exact texts
retained in that Core revision.

## Existing iOS integration

Core's `crates/reader-local-book/build.rs` compiles the selected library C files
and the separate Reader adapter `crates/reader-local-book/src/mobi_bridge.c`.
The library reconstructs MOBI markup, navigation and resources. Reader owns
admission, byte/resource limits, canonical positions and the retained original.
Encryption, DRM helpers and upstream command-line tools are not enabled.

The C decoder is statically linked into Rust's `libreader_core.a`, packaged by
`scripts/build-ios-xcframework.sh` in Core, and linked into the iOS App through
`ReaderCore.xcframework`. The iOS project links system `libz`; WebKit renders
the original XHTML and ImageIO handles platform image decoding. There is no
separately replaceable libmobi dynamic library in the current App.

The inspected Core141 artifact contains the `aarch64-apple-ios-sim` slice. The
iOS App's declared minimum is 17.0; its inspected build used the iPhoneSimulator
27.1 SDK. The observed simulator runtime was 26.5, which is distinct from the
build SDK and does not prove operation on an iOS 17 or physical device. Core's
fixed Rust toolchain is 1.97.1. Use the actual containing artifact's Core
receipt and input snapshot for its source, ABI and toolchain identity.

## Local source materials and rebuilding with a modified library

The development assembly had the exact Core source available at the private
checkout `.build/core-source/1411965a65a0f3098c02679be5ef979ae9462867`, relative
to Reader-for-iOS. This is a local build path, not a public source download.
The Host's artifact input snapshot records its actual application inputs;
`scripts/core-dependency.json` records the fixed Core and binding identity.
Neither this notice bundle nor a URL to an upstream project supplies the
complete corresponding Reader application source or relinkable object package.

For a source-based local rebuild, first obtain the matching Core and iOS
application sources, lockfiles, build scripts and required tools from the
material provider. Work in recipient-owned copies, not in the installed App,
retained original books, or the publisher's protected checkout:

1. Keep an unmodified copy of Core141 for comparison. Modify
   `third_party/libmobi-0.12/src/` in the separate Core copy. The explicit file
   list and compilation flags are in `crates/reader-local-book/build.rs`;
   changing its public interface may also require adapting `mobi_bridge.c`.
2. Commit the modified Core inputs locally. In the separate iOS source copy,
   set `scripts/core-dependency.json` to that local commit. Preserve the binding
   hashes when the binding is unchanged; an intentional binding change requires
   the matching files and hashes. The existing dependency tool deliberately
   refuses altered inputs under the old Core pin. Do not relabel a modified
   framework as the original Core141 receipt.
3. From the iOS source copy, use the existing simulator entries below. Replace
   the example Core path with the actual recipient-owned repository. The first
   entry rebuilds the modified Core and records its new framework identity; the
   second regenerates the project and relinks the App with that framework.

```sh
READER_CORE_ROOT=/absolute/path/to/modified-Core \
  bash scripts/build-core.sh --platform simulator
READER_CORE_ROOT=/absolute/path/to/modified-Core \
  bash scripts/build.sh --skip-core
```

These are the existing source build paths; they are not executed by reading
this material and do not install or launch an App. They do not implicitly run
tests. They require macOS, the matching Xcode/Apple SDK and Rust target. Core's
underlying entry is `scripts/build-ios-xcframework.sh`; the Host wrapper supplies
the simulator target, minimum deployment setting and isolated output paths.
The ordinary `scripts/build.sh` lane builds a simulator App, not a signed
physical-device distribution.

## Distribution and verification boundary

The existing Core integration requires a statically linked distribution to
carry the applicable notices and the materials needed to rebuild or relink
with a modified library under LGPL section 4. Retain the exact library,
adapter, Core/application source identities, lockfiles, build scripts and
toolchain information, and provide the applicable corresponding source or
suitable relinkable application materials. Any required installation
information must match the actual distribution channel. Library modification
and reverse engineering needed to debug those modifications must not be
restricted by the combined work's terms.

This bundle makes the scoped license texts and provenance available. It does
not establish public availability of unpublished Reader commits, complete
source/object delivery, successful replacement-library rebuilding/relinking,
or installation and execution of a modified App. Those steps have not been
verified for this material change. Physical-device signing, App Store/channel
terms and any jurisdiction-dependent questions remain outside the evidence
available here; no claim of complete compliance or release readiness is made.
