# PopOS Mise Runtime Migration Design

## Goal

Use mise as the only active manager for Go, Node.js, Python, Rust, and Java while preserving envbat's existing install base, backup model, staged status reporting, and rollback safety.

## Decisions

- Migrate profile schema from 2 to 3.
- Keep per-language install choices.
- Use global dynamic selectors:
  - Go: `latest`
  - Node.js: `lts`
  - Python: `latest`
  - Rust: `stable`
  - Java: `temurin-11`, `temurin-17`, or `temurin-21`
- Keep uv independently managed in `$INSTALL_BASE/tools/bin`.
- Keep legacy runtime directories on disk, but remove them from active profile and PATH configuration.
- Use interactive activation plus shims for non-interactive shells and IDEs.

## Paths

Existing envbat paths remain valid. Mise uses:

```text
$INSTALL_BASE/tools/bin/mise
$INSTALL_BASE/tools/mise/data
$INSTALL_BASE/tools/mise/data/rustup
$INSTALL_BASE/tools/mise/data/cargo
$INSTALL_BASE/temp/mise-cache
$HOME/.config/mise/config.toml
```

The profile exports `MISE_DATA_DIR`, `MISE_CONFIG_DIR`, `MISE_CACHE_DIR`, `MISE_RUSTUP_HOME`, and `MISE_CARGO_HOME`. Rust uses mise-specific rustup and Cargo homes, leaving the legacy Cargo directory inactive. PATH order is mise shims, mise Cargo bin, envbat tools bin, then inherited PATH. Interactive Bash and Zsh evaluate `mise activate` for the current shell.

## Profile Migration

Schema 2 fields map conservatively:

```text
INSTALL_NVM_NODE -> INSTALL_NODE
INSTALL_PYENV    -> INSTALL_PYTHON
INSTALL_RUSTUP   -> INSTALL_RUST
INSTALL_GO       -> INSTALL_GO
INSTALL_JAVA     -> INSTALL_JAVA
INSTALL_UV       -> INSTALL_UV
```

`INSTALL_MISE` becomes true when any managed runtime is selected. Old profiles are backed up before atomic rewrite. New profiles no longer source nvm, initialize pyenv, or prepend legacy Cargo runtime paths. Legacy fields are omitted from schema 3 output.

## Setup Flow

1. Install mise to `$INSTALL_BASE/tools/bin/mise` with `MISE_INSTALL_PATH`.
2. Verify the binary before marking the optional mise stage `OK`.
3. If mise is unavailable, record runtime stages as `SKIP`; never call legacy installers.
4. For enabled runtimes, run `mise use --global <tool>@<selector>` in separate optional stages.
5. For disabled runtimes, remove the global selection with `mise unuse --global <tool>` without deleting downloaded versions.
6. Verify selected runtime resolution through the managed mise binary.

No fallback to nvm, pyenv, rustup, manual Go tarballs, or Oracle JDK is allowed.

## Backup And Restore

Add `$HOME/.config/mise` to the dotfiles archive and safety snapshot. Restore it with the existing atomic directory replacement helper. Mise data and downloaded runtimes are not backed up because setup repair can reinstall them.

## Failure Policy

- Mise download, marker, or execution failure: optional `WARN`.
- Selected runtime with unavailable mise: `SKIP` with explicit reason.
- Individual runtime install failure: optional `WARN`; other runtimes continue.
- Profile migration or shell loading failure: required `FAIL`.
- No legacy installer fallback.

## Tests

- Schema 2 to 3 migration preserves language selections and disables old loaders.
- Fresh profile writes new field names and mise environment paths.
- Mise installer uses the managed binary path and detects false success.
- Runtime selectors map to expected mise commands.
- Disabled tools are removed from global config without deleting legacy directories.
- Shell profile remains idempotent and orders shims before inherited PATH.
- Backup and restore roundtrip includes mise config.
- Existing uv, setup, backup, restore, and verification tests continue to pass.

## User Outcome

`$INSTALL_BASE`, `~/Code`, `~/Data`, `~/Tools`, caches, backups, and model paths remain unchanged. Mise only changes which runtime executable wins on PATH. Project `mise.toml` files can override global versions without moving envbat data directories.
