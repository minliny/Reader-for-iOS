#!/usr/bin/env node
import fs from "fs";
import path from "path";
import vm from "vm";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const defaultDemoRoot = path.resolve(repoRoot, "../Reader UI/frontend-demo");
const demoRoot = process.env.READER_UI_FRONTEND_DEMO
  ? path.resolve(process.env.READER_UI_FRONTEND_DEMO)
  : defaultDemoRoot;

const sourceDir = path.join(demoRoot, "asset-library");
const iconsJsPath = path.join(sourceDir, "icons.js");
const xcassetsDir = path.join(repoRoot, "iOS/Modules/Assets/ReaderIcons.xcassets");
const generatedSwiftPath = path.join(repoRoot, "iOS/Modules/Assets/ReaderAssetIcon.swift");
const docsSnapshotDir = path.join(repoRoot, "docs/ui-handoff/ios/demo-icon-library");
const manifestPath = path.join(docsSnapshotDir, "IOS_DEMO_ICON_IMPORT_MANIFEST.json");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function readIconRegistry(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`missing demo icon registry: ${filePath}`);
  }

  const code = fs.readFileSync(filePath, "utf8");
  const sandbox = { window: {} };
  vm.runInNewContext(code, sandbox, { filename: filePath });
  const registry = sandbox.window.ReaderAssetIcons;
  if (!registry || !registry.icons || !Array.isArray(registry.names)) {
    fail(`invalid ReaderAssetIcons registry: ${filePath}`);
  }

  return {
    icons: registry.icons,
    names: registry.names.slice().sort()
  };
}

function resetDirectory(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function normalizeSvg(svg, name) {
  let result = svg.trim();
  result = result.replace(/\sclass="asset-icon"/, "");
  if (!result.includes("xmlns=")) {
    result = result.replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ');
  }
  result = result.replace(
    "<svg ",
    '<svg fill="none" stroke="#000000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" '
  );
  result = result
    .replace(/currentColor/g, "#000000")
    .replace(/stroke="#fff"/g, 'stroke="#000000"')
    .replace(/stroke="#FFF"/g, 'stroke="#000000"')
    .replace(/stroke="#ffffff"/g, 'stroke="#000000"')
    .replace(/stroke="#FFFFFF"/g, 'stroke="#000000"');

  return `<!-- Generated from Reader UI/frontend-demo/asset-library/icons.js token: ${name} -->\n${result}\n`;
}

function writeAssetCatalog(names, icons) {
  resetDirectory(xcassetsDir);
  writeJson(path.join(xcassetsDir, "Contents.json"), {
    info: {
      author: "xcode",
      version: 1
    }
  });

  for (const name of names) {
    const assetName = `reader-icon-${name}`;
    const imagesetDir = path.join(xcassetsDir, `${assetName}.imageset`);
    fs.mkdirSync(imagesetDir, { recursive: true });
    fs.writeFileSync(
      path.join(imagesetDir, `${assetName}.svg`),
      normalizeSvg(icons[name], name)
    );
    writeJson(path.join(imagesetDir, "Contents.json"), {
      images: [
        {
          filename: `${assetName}.svg`,
          idiom: "universal"
        }
      ],
      info: {
        author: "xcode",
        version: 1
      },
      properties: {
        "preserves-vector-representation": true,
        "template-rendering-intent": "template"
      }
    });
  }
}

function swiftIdentifier(name) {
  return name
    .split("-")
    .map((part, index) => {
      if (index === 0) {
        return part;
      }
      return `${part.charAt(0).toUpperCase()}${part.slice(1)}`;
    })
    .join("");
}

function writeSwiftIconAccess(names) {
  const staticProperties = names
    .map((name) => `    public static let ${swiftIdentifier(name)} = ReaderAssetIcon("${name}")`)
    .join("\n");
  const allNames = names.map((name) => `        "${name}"`).join(",\n");

  const swift = `import SwiftUI\n\n/// Generated from Reader UI frontend-demo asset-library/icons.js.\n/// Do not edit token names by hand; run scripts/import_demo_icon_assets.mjs after demo icon changes.\npublic struct ReaderAssetIcon: RawRepresentable, Hashable, Codable, Identifiable, Sendable {\n    public let rawValue: String\n\n    public init(rawValue: String) {\n        self.rawValue = rawValue\n    }\n\n    public init(_ rawValue: String) {\n        self.rawValue = rawValue\n    }\n\n    public var id: String { rawValue }\n    public var assetName: String { "reader-icon-\\(rawValue)" }\n\n    public static let demoSource = "Reader UI/frontend-demo/asset-library/icons.js"\n    public static let demoBaselineCount = ${names.length}\n\n    public static let allNames: [String] = [\n${allNames}\n    ]\n\n${staticProperties}\n}\n\npublic struct ReaderIcon: View {\n    private let icon: ReaderAssetIcon\n    private let size: CGFloat\n    private let accessibilityLabel: String?\n\n    public init(_ icon: ReaderAssetIcon, size: CGFloat = 24, accessibilityLabel: String? = nil) {\n        self.icon = icon\n        self.size = size\n        self.accessibilityLabel = accessibilityLabel\n    }\n\n    public var body: some View {\n        let image = Image(icon.assetName)\n            .renderingMode(.template)\n            .resizable()\n            .scaledToFit()\n            .frame(width: size, height: size)\n\n        if let accessibilityLabel {\n            image.accessibilityLabel(Text(accessibilityLabel))\n        } else {\n            image.accessibilityHidden(true)\n        }\n    }\n}\n`;

  fs.mkdirSync(path.dirname(generatedSwiftPath), { recursive: true });
  fs.writeFileSync(generatedSwiftPath, swift);
}

function copyFileIfExists(source, destination) {
  if (!fs.existsSync(source)) {
    return;
  }
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
}

function copyDirectory(source, destination) {
  if (!fs.existsSync(source)) {
    return;
  }
  resetDirectory(destination);
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    const sourcePath = path.join(source, entry.name);
    const destinationPath = path.join(destination, entry.name);
    if (entry.isDirectory()) {
      copyDirectory(sourcePath, destinationPath);
    } else if (entry.isFile()) {
      fs.copyFileSync(sourcePath, destinationPath);
    }
  }
}

function writeDocsSnapshot(names) {
  resetDirectory(docsSnapshotDir);
  copyFileIfExists(path.join(sourceDir, "README.md"), path.join(docsSnapshotDir, "README.md"));
  copyFileIfExists(path.join(sourceDir, "ASSET_LIBRARY.md"), path.join(docsSnapshotDir, "ASSET_LIBRARY.md"));
  copyFileIfExists(iconsJsPath, path.join(docsSnapshotDir, "icons.js"));
  copyDirectory(path.join(sourceDir, "icons"), path.join(docsSnapshotDir, "icons"));

  const manifest = {
    generatedAt: new Date().toISOString(),
    source: path.relative(repoRoot, iconsJsPath),
    demoRoot,
    output: {
      xcassets: path.relative(repoRoot, xcassetsDir),
      swift: path.relative(repoRoot, generatedSwiftPath),
      sourceSnapshot: path.relative(repoRoot, docsSnapshotDir)
    },
    iconCount: names.length,
    assetNamePrefix: "reader-icon-",
    names
  };
  writeJson(manifestPath, manifest);
}

const { icons, names } = readIconRegistry(iconsJsPath);
writeAssetCatalog(names, icons);
writeSwiftIconAccess(names);
writeDocsSnapshot(names);
console.log(`Imported ${names.length} Reader demo icons from ${iconsJsPath}`);
