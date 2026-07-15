# AGENTS.md

Guidance for AI agents and humans working in this Unreal Engine repository.

## Instruction Priority

- Follow the user's current request first, then the nearest applicable `AGENTS.md`, then repository documentation and established code patterns.
- A nested `AGENTS.md` may add or override guidance for its subtree.
- Do not invent project facts, commands, engine versions, platforms, plugins, or asset paths. Discover them from the repository or ask when the choice materially affects the result.
- Keep this file accurate. If a command or path changes, update it in the same change.

## Project Facts

Complete this section when the repository is initialized. Agents must verify these values instead of guessing.

- Project: `<PROJECT_NAME>`
- Project file: `<PROJECT_FILE>.uproject`
- Unreal Engine version or association: `<UE_VERSION_OR_ASSOCIATION>`
- Primary game module: `<GAME_MODULE>`
- Editor target: `<PROJECT_NAME>Editor`
- Supported development platforms: `<PLATFORMS>`
- Source control: `<GIT_LFS_OR_PERFORCE>`
- Canonical build script: `<PATH_OR_COMMAND>`
- Canonical test script: `<PATH_OR_COMMAND>`
- Canonical package script: `<PATH_OR_COMMAND>`
- Architecture documentation: `<PATH>`

If any placeholder remains relevant to a task, inspect the `.uproject`, `Source/**/.Target.cs`, `Source/**/.Build.cs`, `.uplugin` files, CI configuration, and repository scripts before proceeding.

## First Principles

- Read `docs/DESIGN-PHILOSOPHY.md` before substantive gameplay, systems, tools, UX, or architecture work. It governs player experience, product boundaries, and design tradeoffs.
- Preserve the intended player or creator experience before optimizing implementation convenience.
- Treat C++, Blueprints, assets, configuration, maps, editor tooling, and build infrastructure as one product. A feature is not complete when only its C++ compiles.
- Prefer explicit, inspectable behavior over hidden editor state, unexplained Blueprint wiring, or undocumented asset dependencies.
- Keep runtime behavior deterministic where practical and designer-facing behavior tunable where useful.
- Make the smallest change that proves the intended behavior. Avoid speculative framework building.
- Protect authored content and existing user work. Binary assets are not disposable build output.

If `docs/DESIGN-PHILOSOPHY.md` does not exist, do not invent its contents. Use established project behavior and ask the human lead about material product decisions.

## Planning and Milestones

Milestones use semantic versioning under `planning/vX.Y/`:

- Major (`v1.0`, `v2.0`): significant releases, major gameplay changes, architectural changes, or compatibility breaks.
- Minor (`v1.1`, `v1.2`): bounded features, content drops, tooling improvements, or grouped fixes.
- Patch (`v1.0.1`, `v1.0.2`): urgent regressions, packaging fixes, or narrowly scoped hotfixes.

Recommended structure:

```text
planning/
├─ README.md                 # Active milestone and planning index
├─ WORKLOG.md                # Work explicitly outside a milestone
├─ REFACTOR.md               # Approved technical-debt backlog
├─ PLAN-FUTURE.md            # Work beyond the current release line
└─ vX.Y/
   ├─ PLAN.md                # Scope, player/tool contract, risks, non-goals
   └─ IMPLEMENTATION.md      # Execution checklist, evidence, findings, deferrals
```

Key project documents, when present:

- `docs/DESIGN-PHILOSOPHY.md`: governing game and tool design principles.
- `docs/ARCHITECTURE.md`: module boundaries, runtime ownership, data flow, and important systems.
- `planning/README.md`: identifies the active milestone; never hard-code `v1.0` when a newer milestone is active.
- `planning/<ACTIVE_MILESTONE>/IMPLEMENTATION.md`: authoritative execution checklist and worklog.
- `implement/RELEASE-CLOSE.md`: release preflight and evidence requirements.
- `status/STATUS-*.md`: reproducible release-line reports, not a substitute for implementation evidence.

When starting a milestone, create its directory and update `planning/README.md` in the same change. Do not create planning bureaucracy for a trivial edit; scale documentation to risk and scope.

## Development Lifecycle

Use **Spec → Plan → Test → Implement → Validate → Review → Commit** for non-trivial work:

1. **Spec:** Define the player-facing or tool-facing contract, acceptance criteria, non-goals, compatibility expectations, and affected platforms.
2. **Plan:** Record the affected C++ modules, Blueprints, assets, maps, config, plugins, save data, networking, tooling, and build paths.
3. **Test:** Add the smallest useful automated test first when the behavior is testable. Otherwise define exact PIE, editor, device, multiplayer, or packaged-build checks before implementation.
4. **Implement:** Make the smallest cohesive source and content changes that satisfy the contract.
5. **Validate:** Compile, load, run tests, exercise editor/content wiring, and escalate to cook/package/device validation according to risk.
6. **Review:** Inspect code, Blueprint/API exposure, binary asset paths, logs, performance implications, and validation evidence.
7. **Commit:** Commit one complete logical unit with explicit files and truthful evidence.

### Interactive and Ad-hoc Work

- Small fixes still require a tracked objective and proportional validation.
- If work belongs to the active milestone, add a brief checklist/worklog entry. If explicitly unscoped, use `planning/WORKLOG.md` when the repository uses it.
- Test first where practical. For asset or visual work, record a reproducible pre-change failure or acceptance procedure before editing.
- Escalate to a full spec when work crosses several systems, changes save/network compatibility, affects security or online services, introduces a plugin, or cannot fit in one focused commit.
- Ad-hoc work receives an independent review before release even when it did not need a full milestone spec.

### Definition of Ready

Before implementation begins, establish:

- intended player, designer, artist, or operator outcome;
- authoritative acceptance criteria and non-goals;
- affected files, modules, assets, maps, platforms, and build targets;
- runtime ownership, world/lifecycle context, and networking authority where relevant;
- save, serialization, asset-reference, Blueprint API, and migration risks;
- validation ladder: targeted tests, editor/PIE checks, multiplayer checks, cook/package, and device checks;
- likely deferrals and dependencies;
- a clean enough source-control state to isolate changes.

Record this pre-analysis in the active implementation document for milestone work.

## Repository Purpose

This repository contains the authored source, configuration, plugins, tests, and game content needed to develop and reproduce the Unreal project.

Track:

- The `.uproject` file and intentional project descriptors.
- `Source/`, project-owned `Plugins/`, `Config/`, tests, build scripts, and documentation.
- Intentional assets under `Content/`, including `.uasset` and `.umap` files, through the configured large-file or locking workflow.
- Project-specific input, packaging, target, platform, and default configuration.

Do not track unless repository policy explicitly says otherwise:

- `Binaries/`, `DerivedDataCache/`, `Intermediate/`, or `Saved/`.
- IDE state such as `.vs/`, `.idea/`, workspace caches, user files, and generated solution/project files.
- Local build products, cooked output, staging output, logs, crash dumps, profiler captures, screenshots, and test reports.
- Marketplace or engine content that licensing or the dependency workflow does not permit redistributing.
- Secrets, signing keys, service credentials, tokens, private endpoints, or machine-specific SDK paths.
- Per-user editor settings, local device profiles, AI transcripts, task state, or tool caches.

When adopting a generated file, first determine whether it is an authored source of truth or a reproducible output. Prefer reproducible generation.

## Repository Layout

- `Config/`: Project-owned `.ini` defaults. Do not confuse them with generated or per-user config under `Saved/Config/`.
- `Content/`: Binary Unreal assets and maps. These normally require Unreal Editor to inspect or modify safely.
- `Source/`: C++ modules, targets, and build rules.
- `Plugins/`: Project-owned or pinned plugins. Each plugin may contain its own `Source`, `Content`, `Config`, and tests.
- `Build/`: Intentional build metadata and platform resources, when present.
- `Scripts/` or `Tools/`: Maintained automation. Prefer these scripts over ad hoc command lines.
- `Tests/`: Non-module-specific test fixtures or automation, when present.
- `.uproject`, `.uplugin`, `.Build.cs`, and `.Target.cs`: Authored project, plugin, module, and target definitions; edit carefully.

Do not traverse engine source, generated code, dependency caches, or large asset trees without a task-specific reason.

## Core Safety Rules

- Never edit `.uasset`, `.umap`, bulk data, or other Unreal binary packages as text or with generic file-rewrite tools.
- Do not rename, move, duplicate, or delete assets outside Unreal Editor or an approved commandlet. Unreal references and redirectors must be handled by the engine.
- Do not create fake placeholder assets with an Unreal extension.
- Do not modify engine installation files or engine source unless the task explicitly targets an engine fork.
- Do not delete redirectors blindly. Fix them through Unreal Editor and validate referencers first.
- Do not change project engine association, enabled plugins, target platforms, default maps, rendering backend, replication model, or packaging settings incidentally.
- Do not run cook, package, shader rebuild, full rebuild, Derived Data Cache invalidation, or broad asset resave unless justified by the task.
- Do not launch multiple editors or commandlets against the same project when either could write assets.
- Before any editor or commandlet operation that can save content, confirm that source control is clean enough to identify its changes.

## Working With Binary Assets

- Treat `.uasset` and `.umap` files as opaque unless an authorized Unreal-aware tool exposes their structured state.
- If an asset change is required but no Unreal-aware editor tool is available, implement the source-code portion and provide exact editor steps for the remaining work.
- Before changing an asset, check source-control status and locking or checkout state. Do not overwrite another user's binary work.
- Keep asset changes narrowly scoped. Saving an asset or map can update metadata or dependencies beyond the visible change.
- After moving or renaming assets, fix redirectors, inspect referencers, load affected maps, and review every changed binary path.
- Never claim a Blueprint, material, animation, Niagara system, widget, or map is correct based only on its filename.

## Roles and Review Lanes

Use separate lanes when the task is large enough to benefit from them:

- **Planner:** defines contracts, scope, affected systems/assets, risks, acceptance checks, and the implementation checklist. Does not silently expand product scope.
- **Implementer:** owns code, Blueprint/editor changes, tests, build fixes, documentation, and validation evidence.
- **Reviewer:** analysis-only unless explicitly reassigned. Reviews source, asset-change inventory, plans, tests, and supplied evidence; does not edit, stage, commit, or claim to have run validation.
- **Human lead:** resolves product choices, accepts risk, approves deferrals and destructive/broad asset operations, and decides release scope.

Role rules:

- State the active role when it is not obvious from the request.
- Review findings include location, impact, rationale, and a concrete suggested resolution.
- The implementer records valid findings in the active worklog before remediation.
- Every factual finding is fixed, explicitly rejected as `NOTABUG`, deferred with approval, or marked `Superseded by <contract>`.
- Severity controls priority, not whether a valid finding may be ignored.
- Scope-expanding preferences that are not required by the spec belong in `planning/REFACTOR.md`, the next milestone, or `planning/PLAN-FUTURE.md`.
- A review is green only when no valid in-scope finding remains open. “Non-blocking” is not the same as resolved.
- Reviewer follow-up confirms resolved/unresolved status; it does not make remediation edits.

For small tasks, one agent may plan and implement sequentially. Do not perform an “independent review” of your own work while presenting it as independent.

## Before Editing

- Run `git status --short --branch`, or the source-control equivalent, and notice staged, unstaged, untracked, checked-out, and locked work.
- Do not overwrite, revert, reformat, resave, or reconcile unrelated user changes.
- Read the `.uproject`, relevant module or plugin descriptor, applicable `.Build.cs`, nearby headers and implementations, tests, and any nested `AGENTS.md`.
- Search for existing types, interfaces, subsystems, gameplay tags, input actions, settings, log categories, and patterns before creating new ones.
- Identify whether the task affects C++, reflection, Blueprints, assets, config, networking, save compatibility, editor-only code, cooking, or packaging.
- Check the active implementation checklist and `planning/REFACTOR.md` when those files exist. Opportunistic cleanup is limited to directly touched files and must not broaden the task.
- For milestone work, record threat/crash hotspots, runtime wiring checkpoints, content dependencies, validation scope, and likely deferrals before implementation.
- State important assumptions when repository evidence cannot settle them.

## Change Discipline

- Keep changes minimal, cohesive, and limited to the requested behavior.
- Prefer established project architecture and naming over introducing a new pattern.
- Separate runtime code from editor-only code. Runtime modules must not depend on editor modules.
- Avoid unrelated cleanup, mass formatting, include reordering, asset resaves, or generated-file churn.
- Update tests and documentation when behavior, public APIs, setup, config, or editor workflow changes.
- If a generated file must change, change its source or generator and regenerate it through the canonical workflow.
- Preserve compatibility unless the task explicitly authorizes a breaking change.
- Keep the active implementation checklist and worklog synchronized with actual progress; do not pre-check work.
- Document security-, privacy-, monetization-, moderation-, online-service-, and supply-chain-relevant decisions.
- Remove dead code or stale imports in an already-touched file only when the cleanup is obvious, safe, and validated. Defer cross-file cleanup.

## Unreal C++ Standards

- Follow Epic's current C++ coding standard and the stricter local convention when one exists.
- Use Unreal type prefixes and PascalCase consistently: `U`, `A`, `F`, `E`, `I`, `T`, `S`, and `b` for booleans where applicable.
- Use Unreal integer types such as `int32` and `uint8` when width matters. Use `TCHAR`/`FString`/`FName`/`FText` according to engine semantics.
- Use `FText` for user-facing localized text, `FName` for stable names and identifiers, and `FString` for mutable string processing.
- Prefer one reflected type per appropriately named header when practical.
- Keep public interfaces small. Prefer private members and expose only intentional designer or caller surfaces.
- Use `const`, references, move semantics, and Unreal containers intentionally; avoid needless copies in hot paths.
- Keep functions focused and make ownership, lifetime, thread, and authority expectations clear.
- Do not add speculative abstractions or defensive branches unsupported by a real requirement.
- Do not copy engine implementation code when a public engine API already provides the behavior.

## Reflection, UObject Lifetime, and Serialization

- Changes involving `UCLASS`, `USTRUCT`, `UENUM`, `UINTERFACE`, `UPROPERTY`, or `UFUNCTION` require Unreal Header Tool awareness and a normal build, not only textual validation.
- Keep every generated-header include in the correct form and as the final include in its header.
- Do not manually edit generated headers or reflection output.
- Use reflected properties and Unreal-supported pointer types when garbage collection, serialization, replication, editor exposure, or Blueprint access requires them.
- In UE5 code, follow local engine/project practice for `TObjectPtr`, `TWeakObjectPtr`, `TSoftObjectPtr`, `TSubclassOf`, and `TScriptInterface`; choose based on ownership and loading semantics, not habit.
- Never retain a raw pointer to a garbage-collected object without proving that its lifetime is protected and its use is valid.
- Validate nullable object references before use. Use `IsValid` when pending-kill state matters.
- Do not create UObjects with `new` or destroy them with `delete`. Use engine creation and lifecycle APIs.
- Use constructors for default object setup. Defer world-dependent work to the appropriate lifecycle function.
- Treat changes to reflected names, property types, save-game fields, asset paths, config names, RPCs, or serialized structs as compatibility-sensitive.
- Add redirects or migrations when renaming reflected symbols or moving serialized content, and document the compatibility impact.

## Headers, Modules, and Dependencies

- Include what the file uses and prefer forward declarations when correct and readable.
- Do not depend on transitive includes or broad umbrella headers.
- Place dependencies in the correct public or private section of `.Build.cs`.
- Keep editor-only dependencies in editor modules or editor-only guarded build rules.
- Do not add a module, plugin, third-party library, or engine dependency without checking platform, cook, licensing, maintenance, and packaging consequences.
- After changing `.Build.cs`, `.Target.cs`, `.uproject`, `.uplugin`, module structure, or plugin enablement, perform project-file refresh or regeneration when required and run a normal build.
- Preserve module API export macros on types that cross module boundaries.

## Blueprint and Designer-Facing APIs

- Expose C++ to Blueprint only when designers or content workflows need it.
- Choose `BlueprintCallable`, `BlueprintPure`, `BlueprintImplementableEvent`, and `BlueprintNativeEvent` deliberately; do not expose everything by default.
- Give exposed properties intentional categories, tooltips, edit scopes, clamps, units, and metadata where useful.
- Prefer components, data assets, interfaces, gameplay tags, and settings objects over hard-coded level references.
- Avoid expensive Blueprint-pure functions, hidden world scans, per-frame allocations, or repeated asset loads.
- Keep authoritative game rules and performance-sensitive reusable systems in C++ when appropriate; keep tuning and composition designer-friendly.
- When changing a Blueprint-facing signature or reflected property, identify affected assets and describe required recompilation, migration, or resave steps.

## Gameplay Architecture

- First reuse the project's existing framework: components, subsystems, ability system, gameplay tags, data assets, interfaces, messaging, save system, and dependency-injection patterns.
- Avoid unnecessary `Tick`. Prefer events, timers, delegates, latent actions, or subsystem updates when they express the behavior better.
- When `Tick` is necessary, disable it by default where possible, set an intentional tick group or interval, and avoid allocations or global searches.
- Avoid `GetAllActorsOfClass`, repeated component searches, synchronous loads, or expensive casts in hot paths unless measured and justified.
- Do not put unrelated global behavior into GameMode, GameInstance, PlayerController, or a monolithic singleton merely because they are easy to access.
- Make world-context assumptions explicit. Account for editor worlds, PIE, dedicated servers, clients, seamless travel, and teardown when relevant.

## Networking

- Treat server authority, client prediction, ownership, relevancy, and late joining as explicit design concerns.
- Never trust client-provided gameplay-critical state. Validate requests on the authoritative side.
- Declare replicated properties and RPCs using the project's established Unreal pattern and test both server and client behavior.
- Keep RPCs coarse enough to avoid excessive traffic; do not send cosmetic or derivable state unnecessarily.
- Consider ordering, packet loss, dormancy, relevancy, join-in-progress, and listen-server versus dedicated-server behavior.
- Do not mark a feature networking-safe without a multiplayer PIE or equivalent test when networking is affected.

## Threading and Async Work

- Assume UObject and Actor mutation is game-thread-only unless an API explicitly guarantees otherwise.
- Do not capture raw UObject pointers in delayed or background work without a safe lifetime strategy and game-thread handoff.
- Keep blocking I/O, heavy computation, and synchronous asset loading off latency-sensitive paths where practical.
- Document cancellation, shutdown, world cleanup, and ownership behavior for asynchronous tasks.
- Treat engine delegates, timers, latent actions, and callbacks as lifetime-sensitive; unregister or invalidate them appropriately.

## Configuration and Data

- Edit authored defaults under `Config/`, never generated values under `Saved/Config/`.
- Preserve `.ini` hierarchy and platform override behavior. Do not duplicate a setting across layers without a reason.
- Do not write secrets or environment-specific absolute paths into config.
- Prefer data assets, data tables, developer settings, gameplay tags, or config for intentional designer-controlled data according to existing project patterns.
- Treat changes to collision channels, object channels, input mappings, gameplay tags, maps, redirects, packaging lists, and network settings as project-wide changes requiring focused validation.

## Logging and Diagnostics

- Use project-specific log categories rather than `LogTemp` in committed code.
- Choose log verbosity intentionally and avoid per-frame log spam.
- Never log credentials, personal data, authentication tokens, or sensitive service payloads.
- Use assertions according to recoverability: `check` for impossible fatal invariants, `ensure` for unexpected recoverable conditions, and normal validation for expected input failures.
- Error messages should identify the failing object or context and suggest the next useful diagnostic step.
- Remove temporary debug drawing, on-screen messages, console commands, and verbose instrumentation unless they are intentional supported tools.

## Build Policy

Prefer maintained repository scripts or CI commands. If none exist, derive commands from the actual engine association, project path, platform, and target; do not guess an engine installation path.

### Validation Cadence

- During implementation and remediation, run the smallest targeted compile, automation test, functional test, or editor check that directly covers the change.
- Do not run full cooks, packaged builds, all-map validation, shader rebuilds, broad content resaves, multiplayer matrices, or device suites after every small edit.
- Escalate validation at milestone close, when affected risk demands it, and at release close.
- Record exact commands, configuration, platform, relevant editor mode, test filter, result, and material warnings in the active worklog.
- PIE is useful development evidence, but it is not packaged-build or target-device evidence.
- Live Coding is useful iteration evidence, but it is not a final clean-build result.
- Blueprint compile success is necessary for affected Blueprints but does not prove runtime behavior.
- A successful cook does not prove packaging, launch, networking, save compatibility, performance, or gameplay behavior.
- Live user testing happens after deterministic targeted checks are green, unless the task specifically concerns a behavior that only a live session can represent.
- Run stateful editor, server, device, or live-evaluation lanes sequentially when parallel execution could share ports, saves, caches, accounts, maps, or editor state.

Use the lightest validation that can prove the change, then escalate when risk requires it:

| Change | Minimum expected validation |
| --- | --- |
| Documentation or comments only | Review diff and links/format |
| `.cpp` implementation only | Compile affected module or editor target; Live Coding may be used for local iteration |
| Reflected header, constructor, class layout, or default subobject | Close-editor normal build; reopen and validate affected assets |
| `.Build.cs`, `.Target.cs`, module, plugin, `.uproject`, or `.uplugin` | Refresh/regenerate project metadata if needed; normal editor-target build |
| Blueprint-facing API | Normal build plus load and compile affected Blueprints |
| Asset/config/map change | Load affected content and run targeted validation in Unreal Editor |
| Networking | Build plus server/client functional validation |
| Cooking, packaging, platform, or serialization | Targeted cook/package and launch test on the affected platform |
| Release-critical or cross-module change | Clean CI-equivalent build and relevant automated/functional tests |

Live Coding is an iteration tool, not final proof:

- It is appropriate mainly for supported C++ implementation changes while the editor is running.
- Do not rely on it as the only verification for reflection changes, header layout changes, constructor/default changes, module rules, plugin changes, serialization, or packaging.
- If editor behavior appears stale or inconsistent, stop the editor and perform a normal build before debugging further.
- Do not fall back to legacy Hot Reload as a correctness strategy.

## Canonical Command Templates

Replace these templates with repository-owned scripts as soon as possible. Never execute the angle-bracket placeholders literally.

Windows editor build:

```powershell
& "<UE_ROOT>\Engine\Build\BatchFiles\Build.bat" <PROJECT_NAME>Editor Win64 Development -Project="<ABSOLUTE_PROJECT_FILE>" -WaitMutex
```

Generate Visual Studio project files when required:

```powershell
& "<UE_ROOT>\Engine\Build\BatchFiles\GenerateProjectFiles.bat" -project="<ABSOLUTE_PROJECT_FILE>" -game -engine
```

Headless automation-test shape:

```powershell
& "<UE_ROOT>\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "<ABSOLUTE_PROJECT_FILE>" -unattended -nop4 -NullRHI -ExecCmds="Automation RunTests <PROJECT_TEST_FILTER>; Quit" -TestExit="Automation Test Queue Empty"
```

Packaging must use the project's maintained BuildGraph, UAT, or CI command. Do not invent shipping flags, signing settings, maps, cultures, or target platforms.

## Testing

- Add or update the smallest test that would have caught the defect or protects the new behavior.
- Prefer fast deterministic unit or automation tests for pure logic, functional tests for world behavior, and Gauntlet or platform workflows for end-to-end scenarios when the project uses them.
- Follow Epic's automation guidance: tests must not assume execution order or pre-existing editor/game state, and must restore files and state they change.
- Tests must be safe to rerun and should clean stale output before starting when practical.
- Avoid timing-based sleeps. Wait on explicit conditions with bounded timeouts.
- Name tests under the project's existing namespace and apply suitable context and product flags.
- Separate editor-only tests from runtime or packaged-build tests.
- New player-facing or tool-facing capabilities require at least one contract-level behavioral or functional check unless the active plan records why automation is disproportionate or impossible.
- Fixes should reproduce the failure before the fix when practical, then demonstrate the corrected behavior.
- For visual, animation, audio, input-feel, or level-design work, supplement automation with explicit human acceptance criteria and stable capture/reproduction conditions.
- For multiplayer work, define topology, player count, authority, latency assumptions, and listen-versus-dedicated coverage.
- For save or migration work, keep representative old-version fixtures and verify load, migrate, save, and reload behavior.
- For fixes that cannot be automated, provide exact manual reproduction and verification steps.

## Performance

- Do not claim an optimization without measurement relevant to the target platform.
- Avoid premature low-level changes that reduce clarity without evidence.
- For performance-sensitive changes, record the scenario, build configuration, hardware/platform, capture method, and before/after result.
- Consider CPU, GPU, memory, allocation rate, streaming, shader compilation, loading, networking, and package size as distinct budgets.
- Debug or Development Editor performance is not a substitute for an appropriate standalone or target-platform profile.

## Editor Automation and MCP Tools

- Treat editor automation, Python, commandlets, remote control, and MCP tools as privileged project-writing capabilities.
- Inspect tool scope and current editor selection/world before invoking mutating actions.
- Prefer read-only inspection first. Preview or enumerate intended changes before batch operations.
- Require explicit user approval for broad asset creation, deletion, renaming, migration, map edits, redirector cleanup, resaves, or plugin installation.
- Keep the editor and tool bound to local interfaces unless remote access is explicitly required and secured.
- After automated asset operations, review source-control changes, editor logs, referencers, map load, and validation results.
- Do not report success solely because a tool call returned successfully; verify the resulting project state.

## Dependencies and Plugins

- Do not install or enable plugins, SDKs, packages, or external services without explicit approval.
- Before proposing a dependency, check Unreal-version compatibility, target platforms, source availability, licensing, security, binary distribution, build-agent setup, cook/package behavior, and maintenance status.
- Pin versions or commits using the repository's established dependency mechanism.
- Keep third-party code isolated from project code and document required setup.
- Never silently modify marketplace plugin source. Prefer a project adapter, subclass, or clearly maintained fork.

## Source-Control Practices

- Respect the repository's Git LFS or Perforce policy and binary locking rules.
- When a complete logical task is finished, validated, and authorized by repository policy, commit it without waiting for a separate reminder. Do not commit partial, failing, or mixed-scope work.
- Never use `git add .`, `git add -A`, or `git commit -a`.
- Stage explicit paths only and verify with `git diff --staged --name-only`.
- Review the staged patch with `git diff --staged` before committing.
- Review text patches with `git diff` and binary path changes with source-control status plus Unreal-aware inspection.
- Make atomic commits: one logical task per commit.
- Use conventional prefixes when the repository does not define another style: `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `perf`, `chore`, or `meta`.
- Do not add AI bylines, generated-agent signatures, or co-author footers.
- Do not push, tag, reset, rebase, clean, force-update, unlock, revert, or delete user work unless explicitly asked.
- Never resolve a binary asset conflict by choosing a side without user direction and Unreal-aware validation.

## Commit Message Style

Use a short imperative subject. Add a body only when it explains behavior, migration, risk, or validation that the diff does not make obvious.

```text
fix prevent stale target retention

- Clear weak target references during world teardown
- Cover target destruction with an automation test
```

For review remediation, include the milestone and finding IDs when the repository uses them.

## External Contributions and Public Communication

- Preserve external contributor credit. Accepted contributions still require a maintainer quality/security pass and proportional Unreal-aware validation.
- When permitted, prefer maintainer fixup commits on the contributor's branch over replacing authorship.
- Follow `planning/DEV-pull-requests.md` when present.
- Prefer the authenticated hosting CLI for public comments and PR writes; use connectors for structured reads when appropriate.
- Before public posts, remove private-process leakage: internal paths, worklogs, reviewer identities/models, private branches, run IDs, unpublished hashes, credentials, internal issue IDs, or private tool names.
- Public claims cite public code, issues, commits, builds, and player-visible behavior—not private planning evidence.

## Documentation and Claim Integrity

- Keep design, architecture, setup, Blueprint/editor steps, controls, compatibility notes, planning checklists, and actual runtime behavior synchronized.
- Fix documentation drift in the same task, especially for networking authority, save compatibility, security, online-service behavior, required plugins, and packaging prerequisites.
- Do not claim “done,” “shipped,” “complete,” “fixed,” “safe,” or “supported” without evidence proportional to the claim.

Completion evidence has four layers when applicable:

1. **Runtime wiring:** where the behavior is actually connected in C++, Blueprint, assets, maps, config, subsystems, or tools.
2. **Content/editor state:** which assets were created, compiled, saved, migrated, referenced, or manually configured.
3. **Validation:** exact builds, test filters, PIE scenarios, multiplayer topology, cooks, packages, devices, or performance captures and their outcomes.
4. **Documentation parity:** active checklist/worklog and user/developer documentation reflect the final behavior and limitations.

Truth-scope every claim:

- Prefer “in Development Editor on Win64,” “with plugin X enabled,” “in two-client dedicated-server PIE,” or “for newly created saves” over universal language.
- A source-only review cannot establish asset wiring, Blueprint compilation, map state, packaged behavior, or target-device performance.
- Missing evidence narrows the claim; it does not become assumed success.

When reporting metrics such as test count, cook time, package size, memory, frame time, or code churn, record the exact commit/tag, platform, configuration, scenario, hardware when relevant, and command or capture method.

## Findings, Deferrals, and Review Trace

- Assign stable IDs to formal review findings, for example `M2.R1.3` or the repository's existing format.
- Record each valid finding as fixed, `NOTABUG`, `WONTFIX`, deferred, or `Superseded by <contract>`, with a concise rationale.
- `NOTABUG` and `WONTFIX` require human-lead approval when they leave meaningful product, data, content, security, or release risk.
- Do not spend a re-review cycle on a batch containing only approved no-change dispositions and no changed artifacts; record that closure explicitly.
- Surface all carried no-change dispositions to the release-close review. Nothing silently escapes the release.
- Commit remediation with the applicable milestone/finding IDs and record the exact validation evidence.

Every deferral includes:

- stable ID;
- concrete unfinished work;
- reason for deferral;
- player/developer/content risk;
- current mitigation or non-claim;
- destination milestone or backlog;
- owner or decision authority when known.

Keep milestone deferrals in the active `IMPLEMENTATION.md`. Use `planning/PLAN-FUTURE.md` only beyond the current release line. No orphan deferrals: update both source and destination records together.

## Milestone and Release Closure

Ordinary tasks use proportional validation. The following checklist applies only when closing a milestone or release; tailor it to the project's actual platforms and feature scope.

- [ ] Active milestone acceptance criteria and non-goals are reconciled with the implementation.
- [ ] All intended runtime and editor/content wiring is present and reviewed.
- [ ] Editor target builds normally from a non-Live-Coding state.
- [ ] Unreal Header Tool and build logs contain no unexplained new warnings or errors.
- [ ] Targeted automation/unit tests pass with exact command and result recorded.
- [ ] Relevant functional, editor, Blueprint, and content-validation tests pass.
- [ ] Affected Blueprints compile and affected maps/assets load without new errors.
- [ ] Required manual PIE/Standalone scenarios pass with steps and outcome recorded.
- [ ] Relevant multiplayer topology passes when networking changed.
- [ ] Representative legacy saves/assets migrate successfully when serialization changed.
- [ ] Relevant cook succeeds for every release platform affected by the milestone.
- [ ] Packaged build launches and completes the release smoke path on required target platforms.
- [ ] Crash, ensure, warning, asset-reference, redirector, and packaging logs are reviewed.
- [ ] Performance/memory/load-time budgets are checked when risk or acceptance criteria require them.
- [ ] New player/tool capabilities have contract-level test or explicit approved manual evidence.
- [ ] Documentation, controls, setup, credits/licenses, changelog, and planning state match reality.
- [ ] Dependency/plugin versions, licensing, security posture, and supply-chain pins are reviewed when changed.
- [ ] All valid review findings are fixed or have approved recorded dispositions.
- [ ] All deferrals have risk, mitigation/non-claim, and an executable destination.
- [ ] All `WONTFIX`/`NOTABUG` dispositions are included in the release-close packet.
- [ ] Release statistics and metrics identify exact refs and reproducible measurement methods.
- [ ] Explicit task paths only are staged; staged names and patches are reviewed.
- [ ] Release commit evidence is recorded. Tag and push occur only with explicit human-lead approval.

If a required lane cannot run, record why, identify what remains unproven, and narrow the closure/release claim. Do not turn “environment unavailable” into a passing result.

## Before Declaring Completion

- Re-read the request and confirm that each requested outcome is addressed.
- Review source-control status and ensure every changed file is intentional.
- Review the diff for accidental generated files, absolute paths, secrets, noisy formatting, debug code, and unrelated asset churn.
- Run the applicable validation from the build matrix, starting targeted and escalating according to risk.
- Check build, Unreal Header Tool, editor, cook, and test logs for new warnings as well as errors.
- For asset-facing changes, identify every manual editor step and every asset that must be compiled, resaved, migrated, or checked out.
- Update the active plan, implementation checklist, worklog, finding dispositions, and deferrals to match the actual result.
- Obtain an independent review before milestone or release closure. Small task completion may precede that review when the repository workflow permits it.
- Report exactly what was changed, what was validated, what was not run, and any remaining risk or manual step.
- Never say “build passes,” “tests pass,” “Blueprint works,” “replication works,” or “package succeeds” unless that exact check was run successfully.

## When Blocked

- Exhaust safe read-only inspection and targeted local checks first.
- Report the exact blocker, relevant evidence, and the smallest user action needed.
- If Unreal Editor or a platform SDK is unavailable, continue with source-level work where safe, but clearly separate verified results from unverified editor/platform behavior.
- If a binary asset must change and no Unreal-aware editing path is available, stop before fabricating or corrupting it and provide precise editor instructions.

## When in Doubt

Protect authored content, preserve user work, follow established project patterns, and prefer a small verifiable change over a broad speculative one. Unreal projects combine source code with stateful binary assets; correctness requires both code validation and Unreal-aware validation.

## Evolving This File

This is a living operational document. Update it when:

- an agent or human repeats the same avoidable mistake;
- a new module, platform, plugin, build lane, source-control rule, or content workflow is introduced;
- a command, path, milestone process, or validation expectation changes;
- a retrospective identifies a concise rule that would prevent recurrence.

Keep additions concrete and verifiable. Put detailed project design in `docs/`, milestone state in `planning/`, and repeatable automation in scripts or CI. Remove obsolete rules instead of accumulating contradictory history.
