#!/usr/bin/env node
import fs from "fs";
import path from "path";
import vm from "vm";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

const args = parseArgs(process.argv.slice(2));
const demoRouteContractPath = path.resolve(
  args["demo-route-contract"] || path.join(repoRoot, "../Reader UI/frontend-demo-optimized/route-contract.js")
);
const swiftMappingPath = path.resolve(args["swift-mapping"] || path.join(repoRoot, "iOS/Navigation/DemoRouteMapping.swift"));
const iosManifestPath = args["ios-manifest"] ? path.resolve(args["ios-manifest"]) : "";
const outputPath = args.output ? path.resolve(args.output) : "";

const aliasRoutes = new Map([
  ["app-shell-phone", "app-shell"],
  ["app-shell-expanded-width-bottom-nav", "app-shell"],
  ["app-shell-tablet-left-rail", "app-shell"],
  ["bookshelf-root", "bookshelf"],
  ["bookshelf-search", "book-search"],
  ["bookshelf-batch", "book-batch-management"],
  ["bookshelf-groups", "group-management"],
  ["bookshelf-book-directory", "book-directory"],
  ["reader-reader-phone", "reader"],
  ["reader-tablet-right-dock", "reader-appearance"],
  ["discover-root", "discover"],
  ["rss-root", "rss"],
  ["rss-detail", "rss-detail"],
  ["rss-original", "rss-original"],
  ["rss-original-browser", "rss-original-browser"],
  ["rss-subscription-management", "rss-subscription-management"],
  ["rss-source-actions", "rss-source-actions"],
  ["rss-search", "rss-search"],
  ["rss-empty", "rss-empty"],
  ["rss-error", "rss-error"],
  ["settings-root", "settings"],
  ["settings-live-source-management", "source-management"],
  ["settings-live-source-import", "source-import-options"],
  ["settings-live-webdav", "webdav-config"],
  ["state-error", "state-error"],
  ["state-offline", "offline-state"],
  ["state-permission", "permission-required"]
]);

const knownFamilyPrefixes = ["app-shell", "bookshelf", "discover", "reader", "rss", "search", "settings", "state"];

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (!value.startsWith("--")) {
      continue;
    }
    const key = value.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      index += 1;
    }
  }
  return parsed;
}

function fail(message) {
  console.error(`FAIL ${message}`);
  process.exit(1);
}

function loadDemoRoutes(routeContractPath) {
  if (!fs.existsSync(routeContractPath)) {
    fail(`missing demo route contract: ${routeContractPath}`);
  }
  const sandbox = { window: {} };
  vm.runInNewContext(fs.readFileSync(routeContractPath, "utf8"), sandbox, {
    filename: routeContractPath
  });
  const contract = sandbox.window.ReaderFrontendDemoDraftRouteContract;
  if (!contract?.routes) {
    fail("demo route contract did not expose window.ReaderFrontendDemoDraftRouteContract.routes");
  }
  return new Set(Object.keys(contract.routes));
}

function loadSwiftOwnedRoutes(mappingPath) {
  if (!fs.existsSync(mappingPath)) {
    fail(`missing Swift route mapping: ${mappingPath}`);
  }
  const source = fs.readFileSync(mappingPath, "utf8");
  const routes = new Set();
  const routeArrayRegex = /public static let expected[A-Za-z]+Routes: \[String\] = \[([\s\S]*?)\]/g;
  for (const match of source.matchAll(routeArrayRegex)) {
    for (const routeMatch of match[1].matchAll(/"([^"]+)"/g)) {
      routes.add(routeMatch[1]);
    }
  }
  if (routes.size === 0) {
    fail(`no Swift-owned routes parsed from ${mappingPath}`);
  }
  return routes;
}

function loadIOSAttachments(manifestPath) {
  if (!manifestPath) {
    return [];
  }
  if (!fs.existsSync(manifestPath)) {
    fail(`missing iOS attachment manifest: ${manifestPath}`);
  }
  const entries = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const attachments = [];
  for (const entry of entries) {
    for (const attachment of entry.attachments || []) {
      attachments.push({
        testIdentifier: entry.testIdentifier || "",
        exportedFileName: attachment.exportedFileName || "",
        suggestedName: attachment.suggestedHumanReadableName || "",
        deviceName: attachment.deviceName || "",
        timestamp: attachment.timestamp || 0
      });
    }
  }
  return attachments;
}

function basenameWithoutGeneratedSuffix(suggestedName) {
  const base = path.basename(String(suggestedName || ""), ".png");
  return base
    .replace(/_\d+_[0-9A-Fa-f-]{36}$/, "")
    .replace(/-\d+x\d+$/, "");
}

function candidateRoutesForAttachment(attachment) {
  const base = basenameWithoutGeneratedSuffix(attachment.suggestedName);
  const candidates = new Set();
  if (base) {
    candidates.add(base);
    if (aliasRoutes.has(base)) {
      candidates.add(aliasRoutes.get(base));
    }
    for (const prefix of knownFamilyPrefixes) {
      const marker = `${prefix}-`;
      if (base.startsWith(marker)) {
        const stripped = base.slice(marker.length);
        candidates.add(stripped);
        candidates.add(`${prefix}-${stripped}`);
        if (aliasRoutes.has(`${prefix}-${stripped}`)) {
          candidates.add(aliasRoutes.get(`${prefix}-${stripped}`));
        }
      }
    }
  }
  return [...candidates].filter(Boolean);
}

function classifyAttachment(attachment, demoRoutes, swiftOwnedRoutes) {
  const candidates = candidateRoutesForAttachment(attachment);
  const demoMatch = candidates.find((route) => demoRoutes.has(route));
  const swiftMatch = candidates.find((route) => swiftOwnedRoutes.has(route));
  return {
    ...attachment,
    normalizedName: basenameWithoutGeneratedSuffix(attachment.suggestedName),
    candidates,
    demoRoute: demoMatch || "",
    swiftRoute: swiftMatch || "",
    coverage: demoMatch && swiftMatch
      ? "demo-and-swift"
      : demoMatch
        ? "demo-only"
        : swiftMatch
          ? "swift-only"
          : "unmapped"
  };
}

function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}

function summarize({ demoRoutes, swiftOwnedRoutes, classified }) {
  const coveredDemoRoutes = new Set();
  const coveredSwiftRoutes = new Set();
  const unmappedAttachments = [];
  for (const item of classified) {
    if (item.demoRoute) {
      coveredDemoRoutes.add(item.demoRoute);
    }
    if (item.swiftRoute) {
      coveredSwiftRoutes.add(item.swiftRoute);
    }
    if (item.coverage === "unmapped") {
      unmappedAttachments.push(item);
    }
  }
  const swiftOwnedMissingNativeScreenshot = sorted([...swiftOwnedRoutes].filter((route) => !coveredSwiftRoutes.has(route)));
  const demoMissingNativeScreenshot = sorted([...demoRoutes].filter((route) => !coveredDemoRoutes.has(route)));
  const swiftOwnedNotInDemo = sorted([...swiftOwnedRoutes].filter((route) => !demoRoutes.has(route)));
  const demoNotSwiftOwned = sorted([...demoRoutes].filter((route) => !swiftOwnedRoutes.has(route)));

  return {
    generatedAt: new Date().toISOString(),
    inputs: {
      demoRouteContractPath,
      swiftMappingPath,
      iosManifestPath: iosManifestPath || null
    },
    counts: {
      demoRoutes: demoRoutes.size,
      swiftOwnedRoutes: swiftOwnedRoutes.size,
      iosAttachments: classified.length,
      coveredDemoRoutes: coveredDemoRoutes.size,
      coveredSwiftOwnedRoutes: coveredSwiftRoutes.size,
      unmappedAttachments: unmappedAttachments.length,
      swiftOwnedMissingNativeScreenshot: swiftOwnedMissingNativeScreenshot.length,
      demoMissingNativeScreenshot: demoMissingNativeScreenshot.length,
      swiftOwnedNotInDemo: swiftOwnedNotInDemo.length,
      demoNotSwiftOwned: demoNotSwiftOwned.length
    },
    coveredDemoRoutes: sorted(coveredDemoRoutes),
    coveredSwiftOwnedRoutes: sorted(coveredSwiftRoutes),
    swiftOwnedMissingNativeScreenshot,
    demoMissingNativeScreenshot,
    swiftOwnedNotInDemo,
    demoNotSwiftOwned,
    unmappedAttachments: unmappedAttachments.map((item) => ({
      suggestedName: item.suggestedName,
      normalizedName: item.normalizedName,
      candidates: item.candidates
    })),
    attachments: classified
  };
}

function writeMarkdownReport(report) {
  const lines = [
    "# iOS Frontend Visual Evidence Audit",
    "",
    `Generated: ${report.generatedAt}`,
    "",
    "## Inputs",
    "",
    `- demo route contract: ${report.inputs.demoRouteContractPath}`,
    `- Swift route mapping: ${report.inputs.swiftMappingPath}`,
    `- iOS attachment manifest: ${report.inputs.iosManifestPath || "not provided"}`,
    "",
    "## Summary",
    "",
    `- demo routes: ${report.counts.demoRoutes}`,
    `- Swift-owned routes: ${report.counts.swiftOwnedRoutes}`,
    `- iOS screenshot attachments: ${report.counts.iosAttachments}`,
    `- demo routes with native screenshot evidence: ${report.counts.coveredDemoRoutes}`,
    `- Swift-owned routes with native screenshot evidence: ${report.counts.coveredSwiftOwnedRoutes}`,
    `- Swift-owned routes missing native screenshot evidence: ${report.counts.swiftOwnedMissingNativeScreenshot}`,
    `- demo routes missing native screenshot evidence: ${report.counts.demoMissingNativeScreenshot}`,
    `- unmapped native attachments: ${report.counts.unmappedAttachments}`,
    "",
    "## Important Boundary",
    "",
    "This report verifies route-to-native screenshot evidence coverage. It does not prove pixel-level visual parity against `frontend-demo`; pixel comparison requires a matching web capture for the same route, state, and viewport.",
    "",
    "## Swift-Owned Routes Missing Native Screenshot Evidence",
    "",
    ...listBlock(report.swiftOwnedMissingNativeScreenshot),
    "",
    "## Unmapped Native Attachments",
    "",
    ...listBlock(report.unmappedAttachments.map((item) => item.normalizedName || item.suggestedName))
  ];
  return `${lines.join("\n")}\n`;
}

function listBlock(values) {
  if (values.length === 0) {
    return ["- none"];
  }
  return values.map((value) => `- ${value}`);
}

const demoRoutes = loadDemoRoutes(demoRouteContractPath);
const swiftOwnedRoutes = loadSwiftOwnedRoutes(swiftMappingPath);
const attachments = loadIOSAttachments(iosManifestPath);
const classified = attachments.map((attachment) => classifyAttachment(attachment, demoRoutes, swiftOwnedRoutes));
const report = summarize({ demoRoutes, swiftOwnedRoutes, classified });

const output = args.format === "json" ? `${JSON.stringify(report, null, 2)}\n` : writeMarkdownReport(report);
if (outputPath) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, output);
}
process.stdout.write(output);

if (args.strict && (report.counts.swiftOwnedMissingNativeScreenshot > 0 || report.counts.unmappedAttachments > 0)) {
  process.exitCode = 1;
}
