# PopOS Storage Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore default XDG paths and place persistent mise runtimes, Flatpak applications, and disposable caches in explicit `/data` locations.

**Architecture:** Profile schema 4 owns only envbat and mise-specific paths. Script changes are tested locally first; the Pop!_OS host is then migrated with compatibility symlinks and before/after validation, without deleting legacy runtimes.

**Tech Stack:** Bash, mise, Flatpak, Git, SSH, existing envbat stage runner and shell tests.

---

### Task 1: Profile Schema 4

**Files:**
- Modify: `popos/profile.sh`
- Modify: `popos/tests/profile_config_test.sh`
- Modify: `popos/verify.sh`
- Modify: `popos/tests/verify_test.sh`

- [ ] Add assertions that schema 4 profiles omit `XDG_DATA_HOME` and `XDG_CACHE_HOME`.
- [ ] Add assertions for `MISE_DATA_DIR=$INSTALL_BASE/tools/mise` and `MISE_CACHE_DIR=$INSTALL_BASE/cache/mise`.
- [ ] Run profile tests and confirm they fail against schema 3.
- [ ] Bump the profile schema to 4 and update generated paths.
- [ ] Update required profile verification to schema 4 and the new shims path.
- [ ] Re-run profile and verify tests.

### Task 2: Directory Layout

**Files:**
- Modify: `popos/directories.sh`
- Modify: `popos/tests/module_contract_test.sh`

- [ ] Assert the directory module declares `tools/mise`, `apps`, and `cache/mise`.
- [ ] Add those persistent roots without changing unrelated directory layout.
- [ ] Run module contract and Bash syntax tests.

### Task 3: Mise Runtime Paths

**Files:**
- Modify: `popos/lang.sh`
- Modify: `popos/tests/mise_test.sh`
- Modify: `popos/tests/lang_test.sh`

- [ ] Change mise data root from `tools/mise/data` to `tools/mise`.
- [ ] Change mise cache from `temp/mise-cache` to `cache/mise`.
- [ ] Verify the installer and runtime-selection tests use the same path contract.

### Task 4: Documentation And Full Tests

**Files:**
- Modify: `README.md`

- [ ] Document standard XDG behavior and the persistent/cache split.
- [ ] Run `bash -n` on all PopOS scripts and tests.
- [ ] Run every `popos/tests/*_test.sh` test.
- [ ] Run `git diff --check`.

### Task 5: Preserve And Update Pop!_OS Repository

**Files:**
- Remote repository: `~/Code/envbat`

- [ ] Commit existing remote changes before updating.
- [ ] Commit and push the tested local implementation without `.claude/`.
- [ ] Rebase the remote commit over the updated main branch and resolve conflicts by preserving valid shell behavior.
- [ ] Re-run remote Bash syntax checks.

### Task 6: Migrate Live Storage

**Files:**
- Runtime paths on Pop!_OS under `/data` and `$HOME`.

- [ ] Record current mise and Flatpak state.
- [ ] Create target parent directories.
- [ ] Move mise data, Flatpak repository, and mise cache only when each target is absent.
- [ ] Create compatibility symlinks at old paths.
- [ ] Install the managed mise launcher at `/data/tools/bin/mise`.
- [ ] Run `./popos/setup.sh --repair` with schema 4.
- [ ] Verify paths, selected tools, Flatpak application IDs, and fresh Zsh command resolution.
- [ ] Leave all legacy runtime directories untouched and report them for later cleanup.

