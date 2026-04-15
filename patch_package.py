import os
import re

package_swift_path = '/workspace/Reader-Core/Core/Package.swift'
with open(package_swift_path, 'r') as f:
    content = f.read()

# Add package dependency
content = re.sub(
    r'dependencies: \[',
    'dependencies: [\n        .package(path: "../../JavaScriptCoreMock"),',
    content,
    count=1
)

# Add target dependency to ReaderCoreJSRenderer
content = re.sub(
    r'\.target\(\n\s*name: "ReaderCoreJSRenderer",\n\s*dependencies: \[([^\]]+)\]',
    r'.target(\n            name: "ReaderCoreJSRenderer",\n            dependencies: [.product(name: "JavaScriptCore", package: "JavaScriptCoreMock"), \1]',
    content
)

# Remove AutoSampleExtractorRunner executable
content = re.sub(
    r'\.executable\(name:\s*"AutoSampleExtractorRunner"[^\)]+\),',
    '',
    content
)
# Remove AutoSampleExtractorRunner target
content = re.sub(
    r'\.executableTarget\(\s*name:\s*"AutoSampleExtractorRunner"[\s\S]*?\),',
    '',
    content
)

with open(package_swift_path, 'w') as f:
    f.write(content)
