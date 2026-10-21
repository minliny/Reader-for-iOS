# Reader ebook dependency notices

This resource bundle preserves notices for the admitted EPUB/MOBI path covered
by `IOS-V3-02`. It is copied into the App as one folder so upstream filenames
such as `COPYING` and `LICENSE` retain their package boundaries.

`MANIFEST.json` maps each included file to its original source and SHA-256. The
Core source identity is `1411965a65a0f3098c02679be5ef979ae9462867`.
`Provenance/core-oss-reuse-manifest.json` is an unchanged copy of that Core
revision's existing license manifest; its selected package names are recorded
in `MANIFEST.json`. The accompanying package license texts are unchanged.
`Provenance/registry-supplement.json` records ZIP/encoding license texts copied
from already available registry archives whose complete SHA-256 values matched
that revision's `Cargo.lock`. No dependency was downloaded to assemble this
bundle.

`libmobi/` contains its upstream license texts and provenance, a Reader notice,
and iOS-specific integration information. Where the existing Core registration
offers MIT or Apache-2.0, Reader uses its recorded MIT option. All copied license
files are retained. The encoding library also carries the separately required
WHATWG/BSD notice; that original text is included alongside its MIT/Apache
texts. MPL packages retain their full license texts and exact upstream source
identities in the copied Core manifest. These dependencies are unmodified as
registered by Core; Reader's adaptation is in Reader-owned files.

The actual iOS XHTML/CSS renderer and image decoder are Apple's system WebKit
and ImageIO. The App links system zlib. They are not copied third-party
renderer implementations in this bundle. Bundled Reader font and UI-asset
notices remain in their existing resource locations.

This is a scoped addition, not a complete Reader dependency inventory or a
claim of release readiness. A repository URL identifies an upstream project;
it is not a promise that an unpublished Reader revision is publicly available.
This bundle does not itself supply the complete Reader/Core source or an
application-object relinking distribution. Source provision, replacement-library
rebuild/relink, and any required installation information must be checked
against the actual distribution materials and channel. See
`libmobi/READER_INTEGRATION.md` for the available local path and remaining
verification boundary.

The containing App's immutable artifact manifest must establish that this
bundle was actually packaged. The previously inspected ordinary App29
`f2656b33-6689-49dc-b5dc-3fd19f31ed61` predates this resource change; its successful
build and license copies do not establish the presence of this new bundle.
