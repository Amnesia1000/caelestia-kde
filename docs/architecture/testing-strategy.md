# Pre-merge testing strategy

Status: in progress

This plan turns the architecture review into a test strategy aimed at catching the highest-impact bugs before merge. It is based on the current repository, its CI workflows, and the acceptance checks in [architecture-review.md](architecture-review.md).

## Executive findings

The repository has strong static and shell-contract coverage, but the highest-risk runtime boundaries are still lightly exercised:

- The 35 Bash tests cover helper functions, script decisions, install layout, rollback guards, and selected CLI behavior. Most tests use stubs or inspect source text rather than executing a complete installed workflow. Evidence: [tests/](../../tests/) and [run-tests.sh](../../tests/run-tests.sh).
- Repository integrity tests compile Python and parse shell, validate workflow/config invariants, and assert selected QML contracts. They do not execute QML, Quickshell, KDE services, or the native Qt plugins. Evidence: [test_repo_integrity.py](../../.github/scripts/test_repo_integrity.py).
- The PR workflow gates PR metadata and QML import/deployment checks, but does not build the shell or installer. Evidence: [pr-checks.yml](../../.github/workflows/pr-checks.yml).
- The validation workflow runs many useful static checks, but its QML syntax/import checks are explicitly structural substitutes because the Qt/Quickshell toolchain is absent. Markdown linting is also non-blocking. Evidence: [validate.yml](../../.github/workflows/validate.yml).
- The scheduled distro workflow compiles the TUI and runs installer steps in Arch, Fedora, and Ubuntu containers, but it is not a required pull-request gate and does not validate a real KDE/Wayland session. Evidence: [test-dependencies.yml](../../.github/workflows/test-dependencies.yml).
- The architecture review requires startup/idle budgets, lazy-component lifecycle tests, source/package parity, offline reproducibility, and failure-injection coverage. Contract, isolated-script, artifact, provenance, and focused native policy checks are now represented; runtime performance and graphical lifecycle checks are not yet represented as merge checks. Evidence: [architecture-review.md](architecture-review.md).

## Testing model

Use four layers with different costs and failure signals:

| Layer | Purpose | Merge policy |
| --- | --- | --- |
| Static and contract | Catch malformed scripts, missing files, invalid references, ownership drift, and unsafe patterns quickly | Required on every PR |
| Isolated behavior | Execute installer/update/uninstall and CLI workflows in temporary homes with fake external commands | Required on every PR for changed surfaces; full suite required before merge |
| Build and artifact | Compile C++, generate the install tree, validate manifests, and compare source/package/release layouts | Required when build, shell, installer, packaging, or release files change |
| Runtime and platform | Exercise QML/native plugin behavior in a real Qt/Quickshell/KDE environment and measure startup | Required for runtime changes; scheduled baseline/nightly for host-dependent cases |

The suite should report test duration and identify the layer that failed. A failure in a fake-command test must not be confused with a failure in a real platform test.

The deterministic layers are executed by `.github/workflows/validate.yml` on every pull request:
Python and repository checks, the Bash suite, clean offline artifact parity, strict installer build,
sanitizer build, and native CTest. The PR gates fail closed when a required job fails or is skipped.

## Highest-value gaps and improvements

### P0: Make current tests reliable and diagnostic

1. Add `--suite fast|isolated|all` to [run-tests.sh](../../tests/run-tests.sh), with `make test-fast` and `make test-isolated` entry points.
2. Add a per-test timeout and emit a final summary containing passed, failed, skipped, and elapsed time. The runner now defaults to 120 seconds per test and supports `--timeout`.
3. Capture each test's stdout/stderr on failure and preserve it as a CI artifact. CI now uploads `test-artifacts/` when the Bash suite fails.
4. Make fake command environments explicit. Several tests intentionally replace `PATH`; missing `mktemp`/`rm` diagnostics from [test_toolchain.sh](../../tests/test_toolchain.sh) demonstrate that a fake environment can obscure the actual assertion. Provide required utility paths or stubs and assert that unexpected command failures are surfaced.
5. Ensure cleanup runs on signals with a trap, and fail if a temporary directory cannot be removed. The runner now cleans up its active child and temporary directory on exit and signals.
6. Add a test-runner smoke test for missing named tests, one failing test, timeout, suite filtering, and multiline diagnostics.

Acceptance: a failed test names its suite, test, exit status, duration, and captured output; the full fast suite finishes within an agreed PR budget.

### P0: Promote isolated install/update/uninstall tests to behavior coverage

The architecture review calls for behavior tests, not only script text. Build one reusable fixture that creates temporary `HOME`, all XDG directories, a fake `systemctl`, `qdbus6`, `kwriteconfig6`, `cmake`, package managers, and network/download commands.

Cover these workflows:

- Source install into an empty home, including generated environment files, services, desktop files, shell data, and manifest.
- Package-layout install using the same fixture, then compare the runtime tree and owned manifest entries with the source install.
- Install twice and update twice; assert stable hashes, no duplicate environment/config lines, no unnecessary rebuild, and stable service state.
- Uninstall with untouched files, user-edited files, shared directories, and missing backups; assert ownership boundaries.
- Inject failure at every numbered step, during build, during deployment, during backup restore, and during manifest validation; assert non-zero status, no false success, and a recoverable state.
- Exercise interrupted atomic replacement and verify the old tree remains usable.

Existing tests such as [test_isolated_update.sh](../../tests/test_isolated_update.sh), [test_isolated_autostart.sh](../../tests/test_isolated_autostart.sh), [test_install_fs.sh](../../tests/test_install_fs.sh), and [test_uninstall.sh](../../tests/test_uninstall.sh) should become fixture consumers rather than independent one-off harnesses.

Acceptance: source and package workflows pass in isolated homes; repeated operations are idempotent; every failure path is diagnosable; no test touches the developer's real home or system services.

### P0: Add a clean build and artifact-parity PR job

Add a Linux job for changes under `shell/`, `installer/`, `scripts/`, `src/`, `packaging/`, `Makefile`, and build workflows:

1. Start with a clean checkout and empty build/cache directories.
2. Fetch pinned dependencies once using `scripts/fetch-dependencies.sh`.
3. Configure and build with network access blocked and `CAELESTIA_OFFLINE=ON`.
4. Install to a staging directory and validate the complete manifest.
5. Build the TUI installer and run its focused tests.
6. Build the release/package layout in a second clean directory.
7. Compare installed path lists and hashes, allowing only explicitly documented package-only files.
8. Verify revision, dependency revision, and generated metadata.

The reusable comparator in `.github/scripts/check_artifact_parity.py` now enforces the path and SHA-256
part of this contract, with focused tests for missing files, drift, and documented package-only paths.
The required `build-parity` job invokes it against two real staged trees after separate offline source
and package builds, then validates both CMake install manifests and the generated path-independent
build provenance manifest.

This directly enforces the P0 acceptance checks rather than relying on source assertions in [test_reproducible_build_inputs.sh](../../tests/test_reproducible_build_inputs.sh) and [test_install_fs.sh](../../tests/test_install_fs.sh).

Acceptance: a missing runtime file, network access during offline configure, mutable dependency, package-only drift, or hash mismatch fails the PR job.

### P1: Compile and test native code with sanitizers

The repository enables strict compiler warnings in [shell/CMakeLists.txt](../../shell/CMakeLists.txt), but warnings do not replace runtime tests. Add configurations for:

- Debug build with `-Werror` after measuring and fixing existing warnings.
- AddressSanitizer and UndefinedBehaviorSanitizer for the native plugin and installer.
- CTest targets for pure C++ logic, model transformations, parsers, path handling, and error mapping.
- Fuzz or property tests for input parsers and boundary-heavy helpers where practical.

Keep Qt/KDE process tests separate from pure C++ tests so sanitizer failures identify the responsible layer.

The required `installer-build` job now compiles the POSIX TUI with `-Wall -Wextra -Werror`.
The required `installer-sanitizers` job configures a Debug installer build with AddressSanitizer
and UndefinedBehaviorSanitizer enabled.
The repository now has a standalone installer step-policy CTest target. The sanitizer job provides
native build coverage and runs that test. Broader executable sanitizer tests still require
additional non-interactive native logic targets.

Acceptance: every native change runs a compile job; native logic has executable tests; sanitizer failures are required for the affected PR path.

### P1: Add real QML and plugin checks

Current Python checks in [check_qml_syntax.py](../../.github/scripts/check_qml_syntax.py), [check_qml_imports.py](../../.github/scripts/check_qml_imports.py), and [check_qml_deployment.py](../../.github/scripts/check_qml_deployment.py) are valuable structural checks, but they cannot catch binding loops, signal lifetime bugs, incorrect model updates, or plugin ABI/runtime failures.

Add a container or VM image with the supported Qt, Quickshell, KDE, and plugin dependencies. Start with smoke tests that:

- Launch the shell in a headless virtual display/session where supported.
- Load the root QML and assert shell-ready, bar, wallpaper, workspace, notification, and shortcut initialization.
- Open, close, and reopen launcher, Nexus, audio, notification, and lockscreen-related views.
- Trigger model updates and verify no duplicate rows, stale values, duplicate signal effects, or crashes.
- Exercise configuration load/save and malformed or partial configuration recovery.
- Load the installed QML import path and native plugin, not only the source tree.

Use screenshots or structured event logs only as supplementary evidence; the primary assertions should be machine-readable state and exit status.

Acceptance: runtime smoke tests run for shell changes; repeated lifecycle tests detect leaked objects, duplicate handlers, and stale model state.

### P1: Establish performance regression checks

The architecture review identifies startup as the principal performance risk but currently has no tracked budget. Add diagnostic events for process launch, first bar frame, wallpaper loaded, and shell-ready. Record cold and warm startup, resident memory, idle CPU, object count, and representative interaction latency.

Begin with three baseline runs per scenario and store benchmark artifacts outside the normal source tree or in a deliberately versioned location. Use warning thresholds first; make thresholds required only after variance is understood. Run these checks on a stable KDE/Wayland host or scheduled runner, not on every developer machine.

Required scenarios:

- cold and warm shell startup
- launcher open and search
- Nexus open and page navigation
- audio and notification updates
- repeated open/close of deferred views

Acceptance: performance-sensitive PRs include before/after structured results; regressions name the metric and scenario; runtime benchmarks are not silently skipped.

### P1: Test lazy-loading and ownership explicitly

When nonessential features move behind loaders, add lifecycle tests for every deferred component. Each test should verify construction on first use, correct first-open behavior, destruction or reuse after close, no duplicate connections after reopen, and correct state after a service update while the view is closed.

This is the test counterpart to the lazy-load workstream in [architecture-review.md](architecture-review.md), and it should be added before broad QML restructuring begins.

### P1: Add a change-aware test matrix

Use path filters only to reduce unnecessary work, never to omit the safety net for shared boundaries. Suggested required jobs:

- Every PR: fast static checks, Bash unit tests, Python tests, config validation, and test-runner diagnostics.
- `shell/` or QML changes: QML runtime smoke, import/deployment checks, and native/plugin build if imports or plugins are affected.
- `scripts/`, `src/bin/`, or installer changes: isolated install/update/uninstall matrix and CLI tests.
- `shell/CMakeLists.txt`, packaging, release workflows, or dependency files: clean offline build, manifest validation, and artifact parity.
- `installer/tui/`: C++ build, sanitizer build, and installer workflow tests.
- Scheduled: real KDE/Wayland lifecycle tests, performance benchmarks, distro install matrix, and upstream-sync checks.

The final required status should be a small explicit gate job that fails when an applicable job is skipped unexpectedly.

### P2: Test upstream boundaries and provenance

For [tools/sync-shell.py](../../tools/sync-shell.py), the deterministic fixture tests represent
upstream-only, KDE-adapted, and port-only files, and assert that existing files require an explicit
force decision.

For release artifacts, the installed provenance manifest identifies project revision, dependency
revision, build type, compiler, Qt version, and install-manifest hashes without leaking user paths.
The parity job validates it in both source and package layouts. Prebuilt archive comparison remains
dependent on the release runner.

## Proposed implementation order

1. Harden the runner and make the existing fast suite deterministic and diagnostic.
2. Consolidate isolated install/update/uninstall fixtures and add failure injection.
3. Add the clean offline build, manifest, and source/package parity job as a required PR check.
4. Add native CTest targets and sanitizer builds.
5. Build a pinned Qt/Quickshell runtime image and add shell smoke/lifecycle tests.
6. Instrument startup and collect baselines, then add scheduled performance regression checks.
7. Add upstream-boundary and artifact-provenance tests.

Each step should land with its own focused tests and measured runtime. Do not bundle a language migration or broad QML refactor into this testing work.

## Definition of done

Before merge, the repository should be able to demonstrate that:

- static checks catch malformed and structurally inconsistent changes;
- isolated tests execute source, package, update, uninstall, rollback, and failure paths;
- clean offline builds validate manifests and source/package parity;
- native code is compiled and exercised under sanitizer configurations;
- QML and plugins are loaded from an installed tree in a real or controlled runtime smoke test;
- lazy components survive repeated open/close cycles without stale state or duplicate handlers;
- startup and idle budgets have reproducible baselines and visible regression results;
- scheduled distro, KDE/Wayland, performance, upstream-sync, and provenance checks are clearly separated from required PR checks.

## Sources in this repository

- [Architecture review](architecture-review.md)
- [Test runner](../../tests/run-tests.sh)
- [Bash tests](../../tests/)
- [Repository integrity tests](../../.github/scripts/test_repo_integrity.py)
- [PR workflow](../../.github/workflows/pr-checks.yml)
- [Validation workflow](../../.github/workflows/validate.yml)
- [Distro dependency workflow](../../.github/workflows/test-dependencies.yml)
- [Shell build definition](../../shell/CMakeLists.txt)
- [Developer entry points](../../Makefile)
