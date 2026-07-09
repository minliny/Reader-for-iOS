#!/usr/bin/env node
import fs from "fs";
import os from "os";
import path from "path";
import vm from "vm";
import { createRequire } from "module";
import { fileURLToPath, pathToFileURL } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const require = createRequire(import.meta.url);

const args = parseArgs(process.argv.slice(2));
const demoRouteContractPath = path.resolve(
  args["demo-route-contract"] || path.join(repoRoot, "../Reader UI/frontend-demo-optimized/route-contract.js")
);
const demoIndexPath = path.resolve(
  args["demo-index"] || path.join(repoRoot, "../Reader UI/frontend-demo-optimized/index.html")
);
const swiftMappingPath = path.resolve(args["swift-mapping"] || path.join(repoRoot, "iOS/Navigation/DemoRouteMapping.swift"));
const iosManifestPath = path.resolve(args["ios-manifest"] || "/tmp/reader-ios-frontend-audit-20260705-complete/manifest.json");
const outputDir = path.resolve(args["output-dir"] || "/tmp/reader-ios-frontend-pixel-parity-20260705");
const outputJsonPath = args["output-json"] ? path.resolve(args["output-json"]) : path.join(outputDir, "pixel-parity-report.json");
const outputMarkdownPath = args["output-md"] ? path.resolve(args["output-md"]) : path.join(outputDir, "pixel-parity-report.md");
const explicitRoutes = parseList(args.routes);
const routeLimit = args.limit ? Number(args.limit) : null;
const writeDiffs = args["write-diffs"] !== "false";
const colorThreshold = args["color-threshold"] ? Number(args["color-threshold"]) : 24;
const failThreshold = args["fail-threshold"] ? Number(args["fail-threshold"]) : null;

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

function parseList(value) {
  if (!value || value === true) {
    return [];
  }
  return String(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function fail(message) {
  console.error(`FAIL ${message}`);
  process.exit(1);
}

function loadDependency(name) {
  try {
    return require(name);
  } catch (firstError) {
    const bundledNodeModules = path.join(
      os.homedir(),
      ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules"
    );
    try {
      return createRequire(path.join(bundledNodeModules, "_codex_require.cjs"))(name);
    } catch {
      fail(`missing ${name}; run with NODE_PATH pointing at bundled node_modules. First error: ${firstError.message}`);
    }
  }
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

function basenameWithoutGeneratedSuffix(suggestedName) {
  const base = path.basename(String(suggestedName || ""), ".png");
  return base
    .replace(/_\d+_[0-9A-Fa-f-]{36}$/, "")
    .replace(/-\d+x\d+$/, "");
}

function parseViewport(suggestedName) {
  const match = String(suggestedName || "").match(/-(\d+)x(\d+)(?:_\d+)?_[0-9A-Fa-f-]{36}\.png$/);
  if (!match) {
    return null;
  }
  return {
    width: Number(match[1]),
    height: Number(match[2])
  };
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

function loadClassifiedAttachments(manifestPath, demoRoutes, swiftOwnedRoutes) {
  if (!fs.existsSync(manifestPath)) {
    fail(`missing iOS attachment manifest: ${manifestPath}`);
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const manifestDir = path.dirname(manifestPath);
  const attachments = [];
  for (const entry of manifest) {
    for (const attachment of entry.attachments || []) {
      const normalizedName = basenameWithoutGeneratedSuffix(attachment.suggestedHumanReadableName || "");
      const candidates = candidateRoutesForAttachment({
        suggestedName: attachment.suggestedHumanReadableName || ""
      });
      const demoRoute = candidates.find((route) => demoRoutes.has(route)) || "";
      const swiftRoute = candidates.find((route) => swiftOwnedRoutes.has(route)) || "";
      const viewport = parseViewport(attachment.suggestedHumanReadableName || "");
      attachments.push({
        testIdentifier: entry.testIdentifier || "",
        exportedFileName: attachment.exportedFileName || "",
        suggestedName: attachment.suggestedHumanReadableName || "",
        normalizedName,
        candidates,
        demoRoute,
        swiftRoute,
        viewport,
        nativePath: path.join(manifestDir, attachment.exportedFileName || "")
      });
    }
  }
  return attachments;
}

function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}

function pickAttachmentByRoute(attachments, route) {
  const matches = attachments
    .filter((item) => item.demoRoute === route && item.swiftRoute === route && item.viewport && fs.existsSync(item.nativePath))
    .sort((left, right) => {
      const leftPhone = left.viewport.width === 390 && left.viewport.height === 844 ? 0 : 1;
      const rightPhone = right.viewport.width === 390 && right.viewport.height === 844 ? 0 : 1;
      return leftPhone - rightPhone || left.suggestedName.localeCompare(right.suggestedName);
    });
  return matches[0] || null;
}

function escapeMarkdown(value) {
  return String(value).replace(/\|/g, "\\|");
}

async function ensureImageSize(sharp, imagePath, width, height) {
  const image = sharp(imagePath).ensureAlpha();
  const metadata = await image.metadata();
  if (metadata.width === width && metadata.height === height) {
    return image.raw().toBuffer();
  }
  return sharp(imagePath)
    .ensureAlpha()
    .resize(width, height, { fit: "fill" })
    .raw()
    .toBuffer();
}

async function compareImages(sharp, webPath, nativePath, diffPath) {
  const nativeMeta = await sharp(nativePath).metadata();
  if (!nativeMeta.width || !nativeMeta.height) {
    fail(`could not read native image size: ${nativePath}`);
  }
  const width = nativeMeta.width;
  const height = nativeMeta.height;
  const webBuffer = await ensureImageSize(sharp, webPath, width, height);
  const nativeBuffer = await ensureImageSize(sharp, nativePath, width, height);
  const pixelCount = width * height;
  const diffBuffer = Buffer.alloc(pixelCount * 4);
  let diffPixels = 0;
  let totalAbsDelta = 0;
  let maxChannelDelta = 0;

  for (let index = 0; index < pixelCount; index += 1) {
    const offset = index * 4;
    const dr = Math.abs(webBuffer[offset] - nativeBuffer[offset]);
    const dg = Math.abs(webBuffer[offset + 1] - nativeBuffer[offset + 1]);
    const db = Math.abs(webBuffer[offset + 2] - nativeBuffer[offset + 2]);
    const channelMax = Math.max(dr, dg, db);
    maxChannelDelta = Math.max(maxChannelDelta, channelMax);
    totalAbsDelta += dr + dg + db;
    if (channelMax > colorThreshold) {
      diffPixels += 1;
      diffBuffer[offset] = 255;
      diffBuffer[offset + 1] = 24;
      diffBuffer[offset + 2] = 72;
      diffBuffer[offset + 3] = 255;
    } else {
      diffBuffer[offset] = Math.round(webBuffer[offset] * 0.35);
      diffBuffer[offset + 1] = Math.round(webBuffer[offset + 1] * 0.35);
      diffBuffer[offset + 2] = Math.round(webBuffer[offset + 2] * 0.35);
      diffBuffer[offset + 3] = 255;
    }
  }

  if (diffPath) {
    await sharp(diffBuffer, {
      raw: {
        width,
        height,
        channels: 4
      }
    }).png().toFile(diffPath);
  }

  return {
    width,
    height,
    pixelCount,
    diffPixels,
    mismatchRatio: diffPixels / pixelCount,
    averageChannelDelta: totalAbsDelta / (pixelCount * 3),
    maxChannelDelta
  };
}

async function captureWebRoute(page, route, viewport, screenshotPath) {
  await page.setViewportSize(viewport);
  const url = new URL(pathToFileURL(demoIndexPath));
  url.searchParams.set("motionReduced", "1");
  url.searchParams.set("captureRoute", route);
  await page.goto(url.toString(), { waitUntil: "networkidle" });
  await page.waitForFunction(
    (expectedRoute) => document.querySelector("[data-current-route]")?.dataset.currentRoute === expectedRoute,
    route,
    { timeout: 5000 }
  );
  await page.waitForTimeout(120);
  await page.screenshot({ path: screenshotPath, fullPage: false });
}

function writeMarkdown(report) {
  const worst = [...report.comparisons]
    .sort((left, right) => right.metrics.mismatchRatio - left.metrics.mismatchRatio)
    .slice(0, 20);
  const lines = [
    "# iOS Frontend Pixel Parity Audit",
    "",
    `Generated: ${report.generatedAt}`,
    "",
    "## Inputs",
    "",
    `- demo index: ${report.inputs.demoIndexPath}`,
    `- demo route contract: ${report.inputs.demoRouteContractPath}`,
    `- Swift route mapping: ${report.inputs.swiftMappingPath}`,
    `- iOS attachment manifest: ${report.inputs.iosManifestPath}`,
    `- output dir: ${report.inputs.outputDir}`,
    "",
    "## Summary",
    "",
    `- routes requested: ${report.counts.routesRequested}`,
    `- comparable routes: ${report.counts.comparableRoutes}`,
    `- routes without native attachment: ${report.counts.routesWithoutNativeAttachment}`,
    `- captures completed: ${report.counts.capturesCompleted}`,
    `- capture errors: ${report.counts.captureErrors}`,
    `- average mismatch ratio: ${(report.summary.averageMismatchRatio * 100).toFixed(2)}%`,
    `- worst mismatch ratio: ${(report.summary.worstMismatchRatio * 100).toFixed(2)}%`,
    "",
    "## Boundary",
    "",
    "This is a first-pass bitmap comparison between canonical `frontend-demo` route captures and iOS XCTest native screenshots at the same route and viewport size. It highlights visual drift; it does not prove interaction completeness, Core/ViewState binding, or device-release readiness.",
    "",
    "## Worst Routes",
    "",
    "| route | viewport | mismatch | avg delta | web | native | diff |",
    "| --- | --- | ---: | ---: | --- | --- | --- |",
    ...worst.map((item) => [
      escapeMarkdown(item.route),
      `${item.viewport.width}x${item.viewport.height}`,
      `${(item.metrics.mismatchRatio * 100).toFixed(2)}%`,
      item.metrics.averageChannelDelta.toFixed(2),
      path.relative(report.inputs.outputDir, item.webPath),
      item.nativePath,
      item.diffPath ? path.relative(report.inputs.outputDir, item.diffPath) : ""
    ].map(escapeMarkdown).join(" | ")).map((line) => `| ${line} |`)
  ];
  if (report.missingNativeAttachments.length) {
    lines.push("", "## Missing Native Attachments", "", ...report.missingNativeAttachments.map((route) => `- ${route}`));
  }
  if (report.captureErrors.length) {
    lines.push("", "## Capture Errors", "", ...report.captureErrors.map((item) => `- ${item.route}: ${item.error}`));
  }
  return `${lines.join("\n")}\n`;
}

async function main() {
  const { chromium } = loadDependency("playwright");
  const sharp = loadDependency("sharp");
  const demoRoutes = loadDemoRoutes(demoRouteContractPath);
  const swiftOwnedRoutes = loadSwiftOwnedRoutes(swiftMappingPath);
  const attachments = loadClassifiedAttachments(iosManifestPath, demoRoutes, swiftOwnedRoutes);
  const routeUniverse = explicitRoutes.length
    ? explicitRoutes
    : sorted([...demoRoutes].filter((route) => swiftOwnedRoutes.has(route)));
  const routes = routeLimit ? routeUniverse.slice(0, routeLimit) : routeUniverse;

  fs.mkdirSync(outputDir, { recursive: true });
  const webDir = path.join(outputDir, "web");
  const diffDir = path.join(outputDir, "diff");
  fs.mkdirSync(webDir, { recursive: true });
  if (writeDiffs) {
    fs.mkdirSync(diffDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ deviceScaleFactor: 3 });
  await context.addInitScript(() => {
    window.localStorage.setItem("readerFrontendDemoMode", "regular");
  });
  const page = await context.newPage();
  const comparisons = [];
  const missingNativeAttachments = [];
  const captureErrors = [];

  try {
    for (const route of routes) {
      const attachment = pickAttachmentByRoute(attachments, route);
      if (!attachment) {
        missingNativeAttachments.push(route);
        continue;
      }
      const viewport = attachment.viewport;
      const webPath = path.join(webDir, `${route}-${viewport.width}x${viewport.height}.png`);
      const diffPath = writeDiffs ? path.join(diffDir, `${route}-${viewport.width}x${viewport.height}.png`) : "";
      try {
        await captureWebRoute(page, route, viewport, webPath);
        const metrics = await compareImages(sharp, webPath, attachment.nativePath, diffPath);
        comparisons.push({
          route,
          viewport,
          webPath,
          nativePath: attachment.nativePath,
          nativeSuggestedName: attachment.suggestedName,
          diffPath,
          metrics
        });
      } catch (error) {
        captureErrors.push({
          route,
          error: error.message
        });
      }
    }
  } finally {
    await browser.close();
  }

  const averageMismatchRatio = comparisons.length
    ? comparisons.reduce((sum, item) => sum + item.metrics.mismatchRatio, 0) / comparisons.length
    : 0;
  const worstMismatchRatio = comparisons.length
    ? Math.max(...comparisons.map((item) => item.metrics.mismatchRatio))
    : 0;
  const report = {
    generatedAt: new Date().toISOString(),
    inputs: {
      demoIndexPath,
      demoRouteContractPath,
      swiftMappingPath,
      iosManifestPath,
      outputDir,
      colorThreshold,
      failThreshold
    },
    counts: {
      routesRequested: routes.length,
      comparableRoutes: comparisons.length,
      routesWithoutNativeAttachment: missingNativeAttachments.length,
      capturesCompleted: comparisons.length,
      captureErrors: captureErrors.length
    },
    summary: {
      averageMismatchRatio,
      worstMismatchRatio
    },
    missingNativeAttachments,
    captureErrors,
    comparisons: comparisons.sort((left, right) => left.route.localeCompare(right.route))
  };

  fs.writeFileSync(outputJsonPath, `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(outputMarkdownPath, writeMarkdown(report));
  console.log(writeMarkdown(report));

  if (failThreshold !== null && comparisons.some((item) => item.metrics.mismatchRatio > failThreshold)) {
    process.exit(2);
  }
  if (captureErrors.length || missingNativeAttachments.length) {
    process.exit(1);
  }
}

main().catch((error) => fail(error.stack || error.message));
