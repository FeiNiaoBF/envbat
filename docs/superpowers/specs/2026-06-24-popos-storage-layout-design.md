# PopOS Storage Layout Design

## Goal

Restore standard XDG behavior while keeping large, long-lived development runtimes and Flatpak installations on `/data` in purpose-specific directories.

## Target Layout

```text
/data/tools/bin/             managed command binaries
/data/tools/mise/            mise data root: installs, shims, rustup, cargo
/data/apps/flatpak/          Flatpak user installation repository
/data/cache/mise/            disposable mise cache
/data/temp/                  temporary files only
~/.config/mise/config.toml   user-owned mise selections
```

The profile does not export `XDG_DATA_HOME` or `XDG_CACHE_HOME`. Applications therefore use the standard fallbacks `~/.local/share` and `~/.cache`. `TMPDIR` remains `/data/temp`.

Mise uses explicit variables so its large runtime installations remain on `/data` without changing other applications:

```bash
MISE_DATA_DIR="$INSTALL_BASE/tools/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"
MISE_CACHE_DIR="$INSTALL_BASE/cache/mise"
MISE_RUSTUP_HOME="$MISE_DATA_DIR/rustup"
MISE_CARGO_HOME="$MISE_DATA_DIR/cargo"
```

## Live Migration

The current Pop!_OS host has one mise-managed Node installation under `/data/temp/xdg-data/mise`, an 11 GB Flatpak repository under `/data/temp/xdg-data/flatpak`, and legacy Go/nvm/pyenv/Rust/Java installations under `/data/tools`.

Migration order:

1. Preserve remote repository changes in Git before updating scripts.
2. Create `/data/tools`, `/data/apps`, `/data/cache`, and `/data/temp` targets.
3. Move mise data to `/data/tools/mise`, then leave a compatibility symlink at the old path.
4. Move the Flatpak repository to `/data/apps/flatpak`, then point both the standard XDG path and old path at it.
5. Move mise cache to `/data/cache/mise`, leaving a compatibility symlink at the old path.
6. Install the mise launcher at `/data/tools/bin/mise` while retaining `~/.local/bin/mise` during validation.
7. Generate schema 4 profile, repair selected runtimes, and verify command resolution in a fresh interactive Zsh.

Existing legacy runtime directories are not deleted. They remain available through their current `/data/tools/bin` links until mise replacements are verified and a separate cleanup is approved.

## Safety

- Every move stays within the `/data` filesystem and uses a timestamped safety record.
- Existing targets cause migration to stop instead of merge or overwrite.
- Compatibility symlinks keep already-open shells functional during transition.
- Flatpak applications are listed before and after migration.
- Remote uncommitted repository changes are committed before pulling new script changes.
- No legacy runtime or cache is deleted in this migration.

## Verification

- Generated profile contains schema 4 and no global XDG data/cache exports.
- `MISE_DATA_DIR`, `MISE_CACHE_DIR`, and shims resolve to target paths.
- `mise current`, `mise ls`, and `mise where` resolve selected tools.
- Flatpak user application IDs match before and after migration.
- Fresh interactive Zsh resolves mise-managed tools first and retains required system commands.

