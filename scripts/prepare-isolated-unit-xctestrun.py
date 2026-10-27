#!/usr/bin/env python3
"""Prepare an explicit physical-iPhone unit-host plan without executing it.

Accepts the FormatVersion 1 plist emitted by Reader's Debug-iphoneos build.
Only the selected ReaderTests methods and the mandatory isolation self-check
are retained. No build, signing, installation, device query, scheme edit, or
test execution occurs. An existing output is never replaced.

Product references remain bound to the INPUT plist's test root even when the
output is elsewhere. --use-installed-host explicitly replaces those references
with the destination-artifact structure of a prior real App-hosted run. It
does not verify or assert that any host is installed. The planned .free host
identifier does not change any product's Info.plist or signature. Before
execution, verify the exact physical target, host signature and installation,
and the admitted DEBUG host containing the selected test methods.
"""

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import sys
import tempfile
import uuid


MODE_KEY = "READER_ISOLATED_UNIT_TEST_MODE"
RUN_KEY = "READER_ISOLATED_UNIT_TEST_RUN_ID"
MODE = "physical-unit-tests-v1"
PACKAGE_KEY = "READER_REAL_SUBSCRIPTION_PACKAGE_PATH"
HOST_ID = "io.reader.minliny.free"
HOST_CHECK = (
    "ReaderRuleSubscriptionLifecycleTests/"
    "testPhysicalIsolatedUnitHostRejectsSharedProductionLibrary"
)
SELECTOR = re.compile(r"[A-Za-z_][A-Za-z_0-9]*/test[A-Za-z_0-9]+\Z")


class PreparationError(Exception):
    """A diagnostic that never contains caller-provided paths or values."""


class UniqueDict(dict):
    def __setitem__(self, key, value):
        if key in self:
            raise PreparationError("Input contains duplicate plist dictionary keys.")
        super().__setitem__(key, value)


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise PreparationError("Invalid arguments; use --help for the accepted options.")


class StoreOnce(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        if getattr(namespace, self.dest, None) is not None:
            raise PreparationError("Each input, output, run-id and package option is allowed once.")
        setattr(namespace, self.dest, values)


class FlagOnce(argparse.Action):
    def __init__(self, option_strings, dest, **kwargs):
        super().__init__(option_strings, dest, nargs=0, default=False, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        require(not getattr(namespace, self.dest), "Each flag is allowed once.")
        setattr(namespace, self.dest, True)


def parse_arguments():
    parser = SafeParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--input", required=True, action=StoreOnce,
                        help="Existing Reader Debug-iphoneos .xctestrun (read only).")
    parser.add_argument("--output", required=True, action=StoreOnce,
                        help="New .xctestrun in an existing directory; created with mode 0600.")
    parser.add_argument("--run-id", required=True, action=StoreOnce,
                        help="Canonical lowercase UUID for this planned isolated launch.")
    parser.add_argument("--only", required=True, action="append", metavar="Class/testMethod",
                        help="Exact ReaderTests method; repeat for distinct methods. No classes or patterns.")
    parser.add_argument("--real-subscription-package-path", action=StoreOnce,
                        help="Optional original input: bundle:resource or an absolute path on the iPhone. "
                             "No copying, existence, corpus, or device check is performed.")
    parser.add_argument("--use-installed-host", action=FlagOnce,
                        help="Explicitly plan destination-artifact execution against the .free host. "
                             "Requires separate target, signature and installation verification; "
                             "does not query or install anything.")
    return parser.parse_args()


def require(condition, message):
    if not condition:
        raise PreparationError(message)


def clean_string(value):
    return isinstance(value, str) and bool(value) and not any(ord(c) < 32 or ord(c) == 127 for c in value)


def plain_containers(value):
    # UniqueDict rejects duplicate keys while decoding, not intentional edits
    # to a subsequently validated target dictionary.
    if isinstance(value, dict):
        return {key: plain_containers(item) for key, item in value.items()}
    if isinstance(value, list):
        return [plain_containers(item) for item in value]
    return value


def inspect_input(value):
    """Reject ambiguous launch/selection fields before dropping the UI target."""
    if isinstance(value, dict):
        require(all(isinstance(key, str) for key in value), "Plist dictionary keys must be strings.")
        names = [key.casefold() for key in value]
        require(len(names) == len(set(names)), "Input contains conflicting plist field spellings.")
        for key, item in value.items():
            name = key.casefold()
            require(name != "usedestinationartifacts", "UseDestinationArtifacts is not accepted.")
            require(not name.startswith(("onlytest", "skiptest", "testselection"))
                    and name not in {"teststorun", "teststoskip"},
                    "Input must not already contain test-selection fields.")
            if name.endswith("commandlinearguments"):
                require(item == [], "Input launch arguments must be empty.")
            if name.endswith("environmentvariables"):
                require(isinstance(item, dict), "Environment fields must be dictionaries.")
                for env_key, env_value in item.items():
                    require(clean_string(env_key) and isinstance(env_value, str),
                            "Environment entries must be string pairs.")
                    env_name = env_key.upper()
                    require(not env_name.startswith(("READER_", "SIMULATOR_"))
                            and "CLEANUP" not in env_name,
                            "Input contains a pre-existing Reader, cleanup, or simulator environment.")
                    require(not any(c in env_value for c in ("\x00", "\n", "\r")),
                            "Input environment values contain unsupported controls.")
                    require("READER_" not in env_value.upper()
                            and "CLEANUP" not in env_value.upper(),
                            "Input contains a pre-existing Reader or cleanup launch value.")
            inspect_input(item)
    elif isinstance(value, list):
        for item in value:
            inspect_input(item)


def product_path(value, test_root):
    require(clean_string(value) and ".." not in PurePosixPath(value).parts,
            "Product paths must be explicit and must not traverse directories.")
    if value.startswith("__TESTROOT__/"):
        return str(test_root) + value[len("__TESTROOT__"):]
    if value.startswith("__TESTHOST__/"):
        return value
    require(value.startswith("/") and "__" not in value,
            "Product paths must use the source test root, test host, or an absolute path.")
    return value


def package_path(value):
    require(clean_string(value) and value == value.strip(),
            "The optional package path must be nonempty and free of controls or surrounding whitespace.")
    resource = value[len("bundle:"):] if value.startswith("bundle:") else value
    parts = resource.split("/")
    require(resource and ".." not in parts and "." not in parts,
            "The optional package path must not traverse directories.")
    if value.startswith("bundle:"):
        require(not resource.startswith("/") and all(parts) and ":" not in resource,
                "bundle: requires a relative resource name.")
    else:
        require(resource.startswith("/") and all(parts[1:]) and ":" not in resource,
                "The optional package path must be bundle:resource or an absolute iPhone path.")
    return value


def prepare(document, source_root, selectors, run_id, package, use_installed_host=False):
    require(isinstance(document, dict), "The input plist must be a dictionary.")
    inspect_input(document)
    require(set(document) in ({"ReaderTests", "ReaderUITests", "__xctestrun_metadata__"},
                              {"ReaderTests", "__xctestrun_metadata__"}),
            "Only the Reader FormatVersion 1 target layout is supported.")
    metadata = document["__xctestrun_metadata__"]
    require(isinstance(metadata, dict) and type(metadata.get("FormatVersion")) is int
            and metadata["FormatVersion"] == 1, "Only xctestrun FormatVersion 1 is supported.")
    target = copy.deepcopy(document["ReaderTests"])
    require(isinstance(target, dict), "ReaderTests must be a target dictionary.")
    require(target.get("BlueprintName") == "ReaderTests"
            and target.get("ProductModuleName") == "ReaderTests"
            and target.get("IsAppHostedTestBundle") is True,
            "ReaderTests must be the real App-hosted unit-test target.")
    require("TestBundleDestinationRelativePath" not in target
            and not any(key.startswith("UITarget") for key in target)
            and not target.get("IsUITestBundle") and not target.get("IsXCTRunnerHostedTestBundle")
            and target.get("IsEnabled", True) is True,
            "ReaderTests has conflicting target or launch fields.")
    require(target.get("TestHostBundleIdentifier") in {"io.reader.minliny", HOST_ID},
            "The input host identifier is outside the Reader host identities.")
    host = product_path(target.get("TestHostPath"), source_root)
    require(host.startswith("/") and PurePosixPath(host).name == "Reader.app"
            and "Debug-iphoneos" in PurePosixPath(host).parts,
            "The host must reference Reader.app from a Debug-iphoneos product directory.")
    bundle = product_path(target.get("TestBundlePath"), source_root)
    require(bundle.replace("__TESTHOST__", host) == host + "/PlugIns/ReaderTests.xctest",
            "ReaderTests must reference the unit-test bundle inside its real host.")
    dependencies = target.get("DependentProductPaths")
    require(isinstance(dependencies, list) and all(clean_string(item) for item in dependencies)
            and len(dependencies) == len(set(dependencies)),
            "DependentProductPaths must be a distinct list of product references.")
    dependencies = [product_path(item, source_root) for item in dependencies
                    if not {"ReaderUITests-Runner.app", "ReaderUITests.xctest"}
                    .intersection(PurePosixPath(item).parts)]
    resolved = [item.replace("__TESTHOST__", host) for item in dependencies]
    require(len(resolved) == len(set(resolved))
            and host in resolved and host + "/PlugIns/ReaderTests.xctest" in resolved,
            "Dependencies must retain the distinct real host and unit-test product references.")
    target["DependentProductPaths"] = dependencies
    target["TestHostPath"] = host
    target["TestBundlePath"] = bundle
    target["TestHostBundleIdentifier"] = HOST_ID
    for key in ("BundleIdentifiersForCrashReportEmphasis", "ProcessNamesForCrashReportCollection"):
        if key in target:
            require(isinstance(target[key], list) and all(clean_string(item) for item in target[key]),
                    "Crash-collection lists must contain strings.")
            target[key] = [item for item in target[key] if "uitests" not in item.casefold()]
    if use_installed_host:
        # This is the structure in the preserved real App-hosted receipt. It
        # avoids giving the test client source products to install. These are
        # planned references, never evidence that the destination has them.
        for key in ("TestHostPath", "TestBundlePath", "DependentProductPaths"):
            del target[key]
        target["UseDestinationArtifacts"] = True
        target["TestBundleDestinationRelativePath"] = "__TESTHOST__/PlugIns/ReaderTests.xctest"
        target["UITargetAppBundleIdentifier"] = HOST_ID
        target["BundleIdentifiersForCrashReportEmphasis"] = [HOST_ID]
    environment = target.get("EnvironmentVariables")
    require(isinstance(environment, dict), "ReaderTests.EnvironmentVariables is required.")
    environment[MODE_KEY] = MODE
    environment[RUN_KEY] = run_id
    if package is not None:
        environment[PACKAGE_KEY] = package
    target["OnlyTestIdentifiers"] = [HOST_CHECK] + [item for item in selectors if item != HOST_CHECK]
    result = {"ReaderTests": target, "__xctestrun_metadata__": copy.deepcopy(metadata)}
    require("readeruitests" not in plistlib.dumps(result).decode("utf-8").casefold(),
            "Input contains an unsupported UI-test reference after target pruning.")
    return result


def publish(output, encoded):
    require(not os.path.lexists(output), "The output already exists; nothing was replaced.")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix=".isolated-unit-plan-", dir=output.parent,
                                         delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), 0o600)
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
            require(stat.S_IMODE(os.fstat(stream.fileno()).st_mode) == 0o600,
                    "The output file could not be restricted to mode 0600.")
        # A hard link publishes the complete file atomically and refuses even a
        # dangling symlink at the destination. No replace/rename-overwrite call.
        os.link(temporary, output, follow_symlinks=False)
    except FileExistsError:
        raise PreparationError("The output already exists; nothing was replaced.") from None
    except OSError:
        raise PreparationError("Cannot publish the output in its existing parent directory.") from None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    args = parse_arguments()
    try:
        require(str(uuid.UUID(args.run_id)) == args.run_id,
                "Run-id must be a canonical lowercase UUID.")
    except (ValueError, AttributeError):
        raise PreparationError("Run-id must be a canonical lowercase UUID.") from None
    require(all(SELECTOR.fullmatch(item) for item in args.only),
            "Every --only must be one exact Class/testMethod without a target prefix or pattern.")
    require(len(args.only) == len(set(args.only)), "Duplicate --only methods are not accepted.")
    package = package_path(args.real_subscription_package_path) if args.real_subscription_package_path is not None else None
    source, output = Path(args.input), Path(os.path.abspath(args.output))
    require(source.suffix == ".xctestrun" and output.suffix == ".xctestrun",
            "Input and output must have the .xctestrun suffix.")
    require(not source.is_symlink(), "The input must be a regular plist, not a symlink.")
    require(not os.path.lexists(output), "The output already exists; nothing was replaced.")
    try:
        require(source.is_file(), "The input must be an existing regular plist.")
        source_root = source.resolve(strict=True).parent
        document = plain_containers(plistlib.loads(source.read_bytes(), dict_type=UniqueDict))
    except PreparationError:
        raise
    except (OSError, ValueError, TypeError, OverflowError, plistlib.InvalidFileException):
        raise PreparationError("Cannot read a valid input plist.") from None
    result = prepare(document, source_root, args.only, args.run_id, package, args.use_installed_host)
    encoded = plistlib.dumps(result, fmt=plistlib.FMT_XML, sort_keys=False)
    require(plistlib.loads(encoded, dict_type=UniqueDict) == result,
            "Generated plist failed its offline structural round-trip.")
    publish(output, encoded)
    print(json.dumps({
        "status": "PLANNED", "execution": "NOT_RUN", "target": "ReaderTests",
        "only_test_identifiers": result["ReaderTests"]["OnlyTestIdentifiers"],
        "run_id": args.run_id, "environment_keys_added": [MODE_KEY, RUN_KEY] + ([PACKAGE_KEY] if package else []),
        "product_paths": ("OMITTED_FOR_EXPLICIT_INSTALLED_HOST_PLAN" if args.use_installed_host
                          else "BOUND_TO_SOURCE_TESTROOT"),
        "host_reference_mode": "USE_INSTALLED_HOST" if args.use_installed_host else "SOURCE_PRODUCTS",
        "planned_host_bundle_identifier": HOST_ID,
        "required_before_execution": ["VERIFY_EXACT_PHYSICAL_TARGET", "VERIFY_HOST_SIGNATURE_AND_INSTALLATION",
                                      "VERIFY_ADMITTED_DEBUG_HOST_AND_SELECTED_METHODS"],
        "host_product_identity": "NOT_RUN", "signing": "NOT_RUN", "installation": "NOT_RUN",
        "device_identity": "NOT_RUN", "host_isolation": "NOT_RUN", "tests": "NOT_RUN",
        "package_input_validation": "NOT_RUN" if package else "NOT_SELECTED",
        "output_sha256": hashlib.sha256(encoded).hexdigest(),
    }, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except PreparationError as error:
        print(json.dumps({"status": "REJECTED", "execution": "NOT_RUN", "error": str(error)}), file=sys.stderr)
        sys.exit(2)
    except Exception:
        # Malformed plists and filesystem diagnostics must not print private
        # source, product, output, or corpus paths in an exception traceback.
        print(json.dumps({"status": "REJECTED", "execution": "NOT_RUN",
                          "error": "Unsupported input or filesystem condition; no execution was attempted."}),
              file=sys.stderr)
        sys.exit(2)
