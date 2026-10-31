# PopOS Mise Runtime Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mise the only active manager for Go, Node.js, Python, Rust, and Java while preserving envbat paths and safe backup/restore.

**Architecture:** Profile schema 3 maps legacy runtime choices to implementation-neutral fields and activates a managed mise installation. Runtime setup calls mise per selected language; legacy files remain on disk but leave PATH. Mise config joins the existing atomic backup/restore flow.

**Tech Stack:** Bash, mise standalone installer, existing PopOS stage runner, shell tests.

---

### Task 1: Profile Schema 3 Migration

**Files:**
- Modify: `popos/profile.sh`
- Modify: `popos/tests/profile_config_test.sh`

- [ ] Add a failing migration test using schema 2 values `INSTALL_NVM_NODE`, `INSTALL_PYENV`, and `INSTALL_RUSTUP`.
- [ ] Assert migrated values become `INSTALL_NODE`, `INSTALL_PYTHON`, and `INSTALL_RUST`, while `INSTALL_MISE=true` when any runtime is selected.
- [ ] Run `bash popos/tests/profile_config_test.sh`; expect failure because schema remains 2.
- [ ] Set `PROFILE_SCHEMA_CURRENT=3` and map legacy fields before conservative defaults.
- [ ] Replace legacy fields in initial defaults and serialized profile output.
- [ ] Generate mise environment configuration:

```bash
export MISE_DATA_DIR="$INSTALL_BASE/tools/mise/data"
export MISE_CONFIG_DIR="$HOME/.config/mise"
export MISE_CACHE_DIR="$INSTALL_BASE/temp/mise-cache"
export MISE_RUSTUP_HOME="$MISE_DATA_DIR/rustup"
export MISE_CARGO_HOME="$MISE_DATA_DIR/cargo"
export RUSTUP_HOME="$MISE_RUSTUP_HOME"
export CARGO_HOME="$MISE_CARGO_HOME"
export PATH="$MISE_DATA_DIR/shims:$CARGO_HOME/bin:$TOOLS_HOME/bin:$PATH"
```

- [ ] Remove generated nvm sourcing, pyenv initialization, and legacy Cargo PATH entries.
- [ ] Add interactive Bash/Zsh activation using the managed mise binary.
- [ ] Run profile and shell config tests; expect pass.

### Task 2: Managed Mise Installer

**Files:**
- Modify: `popos/lang.sh`
- Create: `popos/tests/mise_test.sh`

- [ ] Add a failing test that mocks `https://mise.run`, requires `MISE_INSTALL_PATH=$INSTALL_BASE/tools/bin/mise`, and creates a fake executable.
- [ ] Add a false-success case where installer exits zero without creating mise; expect function failure.
- [ ] Implement `popos_install_mise`:

```bash
curl -LsSf https://mise.run | env MISE_INSTALL_PATH="$INSTALL_BASE/tools/bin/mise" sh
```

- [ ] Verify executable marker and `mise --version`; export mise path variables for current setup process.
- [ ] Re-run `mise_test.sh`; expect pass.

### Task 3: Runtime Selection Through Mise

**Files:**
- Modify: `popos/lang.sh`
- Modify: `popos/tests/lang_test.sh`

- [ ] Replace Java installer test with command mapping tests for:

```text
go@latest
node@lts
python@latest
rust@stable
java@temurin-11|17|21
```

- [ ] Run test; expect failure because legacy installers remain.
- [ ] Add `popos_mise_use <tool> <selector>` using `mise use --global` and post-install resolution validation.
- [ ] Add `popos_mise_unuse <tool>` using `mise unuse --global` when a global selection exists.
- [ ] Delete legacy Go tarball, nvm, pyenv, rustup, and Oracle Java installer functions.
- [ ] Run language tests; expect pass.

### Task 4: Setup Stages And Selection Migration

**Files:**
- Modify: `popos/setup.sh`
- Modify: `popos/tests/setup_cli_test.sh`

- [ ] Rename setup fields to `INSTALL_NODE`, `INSTALL_PYTHON`, and `INSTALL_RUST`.
- [ ] Add `INSTALL_MISE`; automatically enable it when any managed runtime is selected.
- [ ] Install mise as one optional stage and store `MISE_READY=true` only on success.
- [ ] If mise is unavailable, record selected runtime stages as `SKIP` with `mise unavailable`.
- [ ] Run enabled runtime stages through `popos_mise_use`.
- [ ] Run one optional cleanup stage that removes disabled tools from global mise config without deleting installed files.
- [ ] Update config summary and CLI tests.

### Task 5: Verification

**Files:**
- Modify: `popos/verify.sh`
- Modify: `popos/tests/verify_test.sh`

- [ ] Add failing assertions for managed mise binary, shims directory, and selected runtime resolution.
- [ ] Remove nvm, pyenv, and rustup marker checks.
- [ ] Add optional mise marker checks under `$INSTALL_BASE/tools`.
- [ ] For each enabled runtime, query the managed mise binary; report missing selections as `WARN` without failing required verification.
- [ ] Run `verify_test.sh`; expect pass.

### Task 6: Mise Config Backup And Restore

**Files:**
- Modify: `popos/backup.sh`
- Modify: `popos/restore.sh`
- Modify: `popos/tests/backup_test.sh`
- Modify: `popos/tests/restore_test.sh`
- Modify: `popos/tests/roundtrip_test.sh`

- [ ] Add a failing roundtrip test containing `$HOME/.config/mise/config.toml`.
- [ ] Copy mise config into `dotfiles.tar.gz` as `mise/`.
- [ ] Add current mise config to safety snapshot targets.
- [ ] Restore mise config with `atomic_replace_dir`.
- [ ] Run backup, restore, and roundtrip tests; expect pass.

### Task 7: Documentation And Full Verification

**Files:**
- Modify: `README.md`
- Modify: `popos/tests/uv_test.sh` only if profile path expectations change

- [ ] Document mise ownership, paths, dynamic versions, project overrides, and retained legacy directories.
- [ ] Confirm uv remains independent.
- [ ] Run:

```bash
for file in popos/*.sh popos/tests/*.sh; do bash -n "$file"; done
for test in popos/tests/*_test.sh; do bash "$test"; done
git diff --check
```

- [ ] Expected: all commands exit 0; no nvm/pyenv/rustup initialization remains in generated schema 3 profiles.
