#!/usr/bin/env node
import fs from "fs";
import path from "path";
import vm from "vm";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const mappingPath = path.join(repoRoot, "docs/ui-handoff/ios/IOS_DEMO_BASELINE_ROUTE_MAPPING.md");
const swiftMappingPath = path.join(repoRoot, "iOS/Navigation/DemoRouteMapping.swift");
const defaultDemoRouteContractPath = path.resolve(repoRoot, "../Reader UI/frontend-demo-optimized/route-contract.js");
const demoRouteContractPath = process.env.READER_UI_ROUTE_CONTRACT
  ? path.resolve(process.env.READER_UI_ROUTE_CONTRACT)
  : defaultDemoRouteContractPath;

const requiredSliceFields = [
  "demo route",
  "platform page/View",
  "state model",
  "navigation entry",
  "motion IDs",
  "acceptance tests"
];

const requiredGlobalMarkers = [
  "`route-contract.js.routes`",
  "`Route` + `AppTab`",
  "`tokens.css`, `styles/*.css`",
  "`ReaderDesignTokens`",
  "`motion-tokens.css`, `MOTION_CONTRACT.md`",
  "`AppMotion`, `ReaderMotion`, `MotionEnvironment`",
  "`asset-library/icons.js`",
  "`ReaderAssetIcon`, `ReaderIcon`, `ReaderIcons.xcassets`, `AppTab.assetIcon`",
  "Cross-Cutting Implementation Bridges",
  "ReaderIconAssetAlignmentTests",
  "MotionTokenAlignmentTests",
  "AppShellAlignmentTests",
  "DemoRouteMappingTests"
];

const highPriorityDemoRoutes = [
  "bookshelf",
  "discover",
  "discover-control",
  "discover-sort",
  "discover-entry-ranking",
  "discover-entry-bestseller",
  "discover-entry-category",
  "discover-entry-finished",
  "discover-entry-latest",
  "discover-entry-new",
  "discover-entry-booklist",
  "discover-filter-keyword",
  "discover-filter-male",
  "discover-filter-female",
  "discover-sort-popularity",
  "discover-sort-update",
  "discover-sort-collection",
  "discover-sort-finished",
  "discover-sort-words",
  "discover-no-results",
  "discover-loading",
  "discover-refreshing",
  "discover-infinite-loading",
  "discover-page-two",
  "discover-cache-confirm",
  "discover-cache-toast",
  "discover-login-return",
  "discover-switching-source",
  "discover-switched-source",
  "discover-entry-error",
  "discover-empty",
  "discover-error",
  "rss",
  "settings",
  "bookshelf-empty",
  "sort-filter",
  "book-search",
  "book-detail",
  "book-directory",
  "book-batch-management",
  "discover-source-login",
  "rss-all",
  "rss-starred",
  "rss-source-feed",
  "rss-source-category-releases",
  "rss-source-category-issues",
  "rss-source-category-discussions",
  "rss-refreshing",
  "rss-detail",
  "rss-original",
  "rss-original-browser",
  "rss-subscription-management",
  "rss-source-actions",
  "rss-source-edit",
  "rss-source-debug",
  "rss-source-vars",
  "rss-source-login",
  "rss-source-login-web",
  "rss-source-login-cookie",
  "rss-source-login-clear",
  "rss-source-groups",
  "rss-source-group-edit",
  "rss-source-batch",
  "rss-source-export",
  "rss-source-export-detail",
  "rss-source-export-result",
  "rss-source-pin",
  "rss-source-disable",
  "rss-source-batch-disable",
  "rss-source-import",
  "rss-source-import-detail",
  "rss-source-import-result",
  "rss-search",
  "rss-read-record",
  "rss-record-clear",
  "rss-rule-subscription",
  "rss-rule-subscription-detail",
  "rss-rule-subscription-edit",
  "rss-rule-subscription-test",
  "rss-rule-subscription-apply",
  "rss-favorite-groups",
  "rss-favorite-group-edit",
  "rss-favorite-clear",
  "rss-empty",
  "rss-error",
  "group-management",
  "local-import",
  "immersive-reading",
  "reader",
  "toc-bookmarks",
  "reader-appearance",
  "tts",
  "reader-settings",
  "reader-full-directory",
  "reader-full-tts",
  "reader-full-appearance",
  "reader-full-settings",
  "reader-book-cache",
  "reader-debug-info",
  "auto-page",
  "content-search",
  "content-replacement",
  "discover-rule-test",
  "discover-source-bulk",
  "settings-general",
  "bookshelf-search-settings",
  "about-feedback",
  "sync-backup",
  "webdav-config",
  "restore-confirm",
  "restore-progress",
  "restore-conflict",
  "restore-result",
  "source-management",
  "source-import-options",
  "source-import-preview",
  "source-batch",
  "source-groups",
  "source-detail",
  "source-detect",
  "source-rule-edit",
  "source-debug",
  "source-debug-search-result",
  "source-debug-detail-result",
  "source-debug-catalog-result",
  "source-debug-content-log",
  "source-edit-debug",
  "source-logs",
  "source-code-view",
  "source-delete-confirm",
  "source-switch"
];

function fail(message) {
  console.error(`FAIL ${message}`);
  process.exitCode = 1;
}

if (!fs.existsSync(mappingPath)) {
  fail(`missing mapping document: ${mappingPath}`);
  process.exit();
}

if (!fs.existsSync(swiftMappingPath)) {
  fail(`missing Swift route mapping: ${swiftMappingPath}`);
  process.exit();
}

const markdown = fs.readFileSync(mappingPath, "utf8");
const swiftMapping = fs.readFileSync(swiftMappingPath, "utf8");

for (const marker of requiredGlobalMarkers) {
  if (!markdown.includes(marker)) {
    fail(`mapping document missing global marker: ${marker}`);
  }
}

const sliceHeadingRegex = /^### Slice (\d+) - .+$/gm;
const headings = [...markdown.matchAll(sliceHeadingRegex)].map((match) => ({
  number: Number(match[1]),
  start: match.index,
  heading: match[0]
}));

if (headings.length !== 8) {
  fail(`expected 8 slice headings, found ${headings.length}`);
}

for (let expected = 0; expected <= 7; expected += 1) {
  if (!headings.some((heading) => heading.number === expected)) {
    fail(`missing Slice ${expected}`);
  }
}

for (let index = 0; index < headings.length; index += 1) {
  const current = headings[index];
  const next = headings[index + 1];
  const body = markdown.slice(current.start, next ? next.start : markdown.length);
  for (const field of requiredSliceFields) {
    if (!body.includes(`| ${field} |`)) {
      fail(`${current.heading} missing field: ${field}`);
    }
  }
}

let swiftRouteCount = 0;

if (!fs.existsSync(demoRouteContractPath)) {
  fail(`missing demo route contract: ${demoRouteContractPath}`);
} else {
  const sandbox = { window: {} };
  vm.runInNewContext(fs.readFileSync(demoRouteContractPath, "utf8"), sandbox, {
    filename: demoRouteContractPath
  });
  const contract = sandbox.window.ReaderFrontendDemoDraftRouteContract;
  if (!contract?.routes) {
    fail(`demo route contract did not expose ReaderFrontendDemoDraftRouteContract.routes`);
  } else {
    const routeNames = new Set(Object.keys(contract.routes));
    for (const route of highPriorityDemoRoutes) {
      if (!routeNames.has(route)) {
        fail(`demo route contract missing high-priority route: ${route}`);
      }
      if (!markdown.includes(`\`${route}\``) && !markdown.includes(route)) {
        fail(`mapping document missing high-priority route text: ${route}`);
      }
    }

    const swiftRoutes = new Set();
    const routeArrayRegex = /public static let expected[A-Za-z]+Routes: \[String\] = \[([\s\S]*?)\]/g;
    for (const match of swiftMapping.matchAll(routeArrayRegex)) {
      const body = match[1];
      for (const routeMatch of body.matchAll(/"([^"]+)"/g)) {
        swiftRoutes.add(routeMatch[1]);
      }
    }
    swiftRouteCount = swiftRoutes.size;

    const missingFromSwift = [...routeNames].filter((route) => !swiftRoutes.has(route)).sort();
    const extraInSwift = [...swiftRoutes].filter((route) => !routeNames.has(route)).sort();
    if (swiftRoutes.size !== routeNames.size || missingFromSwift.length || extraInSwift.length) {
      fail(
        `Swift expected route ownership mismatch: swift=${swiftRoutes.size}; demo=${routeNames.size}; missing=${missingFromSwift.length}; extra=${extraInSwift.length}`
      );
      if (missingFromSwift.length) {
        console.error(`missing from Swift: ${missingFromSwift.join(", ")}`);
      }
      if (extraInSwift.length) {
        console.error(`extra in Swift: ${extraInSwift.join(", ")}`);
      }
    }
  }
}

if (!process.exitCode) {
  console.log(
    `PASS demo slice mapping: ${headings.length} slices, ${requiredSliceFields.length} required fields each, ${highPriorityDemoRoutes.length} high-priority demo routes present, ${swiftRouteCount} Swift-owned routes`
  );
}
