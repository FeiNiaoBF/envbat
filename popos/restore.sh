#!/usr/bin/env bash
# === envbat validated restore ===
set -euo pipefail

RESTORE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/interactive.sh
source "$RESTORE_SCRIPT_DIR/interactive.sh"
# shellcheck source=popos/runner.sh
source "$RESTORE_SCRIPT_DIR/runner.sh"

BACKUP_BASE="${ENVBAT_BACKUP_BASE:-${BACKUP_BASE:-/data/backups/envbat}}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
INTERACTIVE=false
SHOW_HELP=false
RESTORE_DATE=""
RESTORE_DIR=""
RESTORE_DIR_REAL=""
RESTORE_INSTALL_BASE=""
RESTORE_WORK_DIR=""
SAFE_DIR=""

declare -A RESTORE_MODULE_STATUS=()
declare -A RESTORE_MODULE_PATH=()

show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -i            高级交互模式（系统配置和包恢复）"
    echo "  -d <时间戳>   指定备份日期"
    echo "  --help        显示帮助"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -i) INTERACTIVE=true; shift ;;
            -d)
                if [ $# -lt 2 ]; then
                    fail "-d 需要时间戳参数"
                    return 1
                fi
                RESTORE_DATE="$2"
                shift 2
                ;;
            --help|-h) SHOW_HELP=true; shift ;;
            *) fail "未知参数: $1"; return 1 ;;
        esac
    done
}

module_is_ok() {
    [ "${RESTORE_MODULE_STATUS[$1]:-skip}" = ok ]
}

module_path() {
    printf '%s' "${RESTORE_MODULE_PATH[$1]:-}"
}

restore_precheck() {
    local modules_output name status path requirement _sensitivity
    RESTORE_MODULE_STATUS=()
    RESTORE_MODULE_PATH=()

    if [ -n "$RESTORE_DATE" ]; then
        RESTORE_DIR="$BACKUP_BASE/$RESTORE_DATE"
    else
        RESTORE_DIR="$BACKUP_BASE/latest"
    fi
    if [ ! -d "$RESTORE_DIR" ]; then
        fail "备份目录不存在: $RESTORE_DIR"
        return 1
    fi
    if [ ! -f "$RESTORE_DIR/manifest.json" ]; then
        fail "缺少 manifest.json；恢复只接受 schema v2 备份"
        return 1
    fi
    if ! "$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" validate "$RESTORE_DIR" >/dev/null; then
        fail "manifest v2、required 模块或校验和验证失败"
        return 1
    fi
    if ! RESTORE_DIR_REAL=$(cd "$RESTORE_DIR" && pwd -P); then
        fail "无法解析备份目录"
        return 1
    fi
    if ! RESTORE_INSTALL_BASE=$("$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" get "$RESTORE_DIR" install_base); then
        fail "无法读取 install_base"
        return 1
    fi
    if ! modules_output=$("$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" modules "$RESTORE_DIR"); then
        fail "无法读取 manifest 模块"
        return 1
    fi
    while IFS=$'\t' read -r name status path requirement _sensitivity; do
        [ -n "$name" ] || continue
        RESTORE_MODULE_STATUS["$name"]="$status"
        [ "$path" = - ] && path=""
        RESTORE_MODULE_PATH["$name"]="$path"
        printf '  [%-4s] %-16s %s\n' "${status^^}" "$name" "$requirement"
    done <<< "$modules_output"

    if ! module_is_ok dotfiles; then
        fail "required dotfiles 模块不可用"
        return 1
    fi
    info "恢复来源: $RESTORE_DIR_REAL"
    info "目录基准: $RESTORE_INSTALL_BASE"
    if ! ask_yes_no "开始恢复用户态内容?" "Y"; then
        info "已取消"
        return 1
    fi
}

create_safety_snapshot() {
    local safe_root="${ENVBAT_SAFE_ROOT:-${TMPDIR:-/tmp}}" item rel dest
    if ! mkdir -p "$safe_root"; then
        fail "无法准备安全快照目录: $safe_root"
        return 1
    fi
    if ! SAFE_DIR=$(mktemp -d "$safe_root/envbat-restore-snapshot.XXXXXX") || ! chmod 700 "$SAFE_DIR"; then
        fail "无法创建安全快照"
        return 1
    fi
    if ! mkdir -p "$SAFE_DIR/home" || ! chmod 700 "$SAFE_DIR/home"; then
        rm -rf -- "$SAFE_DIR"
        SAFE_DIR=""
        return 1
    fi

    for item in \
        "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.p10k.zsh" \
        "$HOME/.gitconfig" "$HOME/.gitignore_global" "$HOME/.ssh" \
        "$HOME/.config/nvim" "$HOME/.config/envbat/profile.sh" \
        "$HOME/.oh-my-zsh/custom"; do
        [ -e "$item" ] || [ -L "$item" ] || continue
        rel="${item#$HOME/}"
        dest="$SAFE_DIR/home/$rel"
        if ! mkdir -p "$(dirname "$dest")" || ! cp -a "$item" "$dest"; then
            rm -rf -- "$SAFE_DIR"
            SAFE_DIR=""
            fail "安全快照复制失败: $item"
            return 1
        fi
    done
    if ! find "$SAFE_DIR" -type d -exec chmod 700 {} + || ! find "$SAFE_DIR" -type f -exec chmod 600 {} +; then
        rm -rf -- "$SAFE_DIR"
        SAFE_DIR=""
        fail "安全快照权限设置失败"
        return 1
    fi
    ok "安全快照: $SAFE_DIR"
}

prepare_restore_payload() {
    local archive
    archive="$(module_path dotfiles)"
    if [ -z "$archive" ]; then
        fail "dotfiles 模块没有归档路径"
        return 1
    fi
    if ! RESTORE_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/envbat-restore.XXXXXX") || ! chmod 700 "$RESTORE_WORK_DIR"; then
        fail "无法创建恢复临时目录"
        return 1
    fi
    if ! "$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" extract-tar "$RESTORE_DIR/$archive" "$RESTORE_WORK_DIR"; then
        rm -rf -- "$RESTORE_WORK_DIR"
        RESTORE_WORK_DIR=""
        fail "dotfiles 归档不安全或无法解压"
        return 1
    fi
}

atomic_replace_file() {
    local source="$1" target="$2" mode="${3:-600}" parent temporary
    parent=$(dirname "$target")
    if ! mkdir -p "$parent"; then
        return 1
    fi
    if ! temporary=$(mktemp "$parent/.envbat-$(basename "$target").XXXXXX"); then
        return 1
    fi
    if ! cp "$source" "$temporary" || ! chmod "$mode" "$temporary" || ! mv -f "$temporary" "$target"; then
        rm -f -- "$temporary"
        return 1
    fi
}

atomic_replace_dir() {
    local source="$1" target="$2" mode="${3:-700}" parent name staged previous had_previous=false
    parent=$(dirname "$target")
    name=$(basename "$target")
    if ! mkdir -p "$parent" || ! staged=$(mktemp -d "$parent/.envbat-$name.new.XXXXXX"); then
        return 1
    fi
    if ! cp -a "$source/." "$staged/" || ! chmod "$mode" "$staged"; then
        rm -rf -- "$staged"
        return 1
    fi
    previous="$parent/.envbat-$name.old.$$"
    if [ -e "$target" ] || [ -L "$target" ]; then
        if ! mv "$target" "$previous"; then
            rm -rf -- "$staged"
            return 1
        fi
        had_previous=true
    fi
    if ! mv "$staged" "$target"; then
        $had_previous && mv "$previous" "$target"
        rm -rf -- "$staged"
        return 1
    fi
    if $had_previous && ! rm -rf -- "$previous"; then
        return 1
    fi
}

restore_user_state() {
    local item
    for item in .bashrc .zshrc .p10k.zsh .gitconfig .gitignore_global; do
        if [ -f "$RESTORE_WORK_DIR/$item" ]; then
            atomic_replace_file "$RESTORE_WORK_DIR/$item" "$HOME/$item" 600 || {
                fail "恢复失败: ~/$item"
                return 1
            }
        fi
    done
    if [ -f "$RESTORE_WORK_DIR/envbat/profile.sh" ]; then
        atomic_replace_file "$RESTORE_WORK_DIR/envbat/profile.sh" "$HOME/.config/envbat/profile.sh" 600 || return 1
    fi
    if [ -d "$RESTORE_WORK_DIR/nvim" ]; then
        atomic_replace_dir "$RESTORE_WORK_DIR/nvim" "$HOME/.config/nvim" 700 || return 1
    fi
    if [ -d "$RESTORE_WORK_DIR/oh-my-zsh-custom" ]; then
        atomic_replace_dir "$RESTORE_WORK_DIR/oh-my-zsh-custom" "$HOME/.oh-my-zsh/custom" 700 || return 1
    fi
    ok "用户配置已恢复"
}

restore_ssh_files() {
    if ! atomic_replace_dir "$RESTORE_WORK_DIR/ssh" "$HOME/.ssh" 700; then
        fail "SSH 原子恢复失败"
        return 1
    fi
    if ! find "$HOME/.ssh" -type d -exec chmod 700 {} + || \
        ! find "$HOME/.ssh" -type f -exec chmod 600 {} + || \
        ! find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} +; then
        fail "SSH 权限校验失败"
        return 1
    fi
    ok "SSH 已恢复"
}

restore_directory_tree() {
    local tree_file validated dir
    tree_file="$(module_path directory_tree)"
    if ! validated=$("$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" tree-list "$RESTORE_INSTALL_BASE" "$RESTORE_DIR/$tree_file"); then
        fail "目录树包含越界路径"
        return 1
    fi
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        if ! mkdir -p "$dir"; then
            fail "目录创建失败: $dir"
            return 1
        fi
    done <<< "$validated"
    ok "目录结构已恢复"
}

restore_git_repos() {
    local repos_file entries relative_path remote_url target failures=0 cloned=0
    repos_file="$(module_path git_repos)"
    if ! command -v git >/dev/null 2>&1; then
        fail "git 不可用"
        return 1
    fi
    if ! entries=$("$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" repos-list "$RESTORE_DIR/$repos_file"); then
        fail "Git 仓库清单无效"
        return 1
    fi
    while IFS=$'\t' read -r relative_path remote_url; do
        [ -n "$relative_path" ] || continue
        target="$HOME/$relative_path"
        if [ -e "$target" ] || [ -L "$target" ]; then
            echo "  [SKIP] $relative_path 已存在，不 pull"
            continue
        fi
        if ! mkdir -p "$(dirname "$target")" || ! git clone "$remote_url" "$target"; then
            warn "克隆失败: $relative_path"
            failures=$((failures + 1))
        else
            cloned=$((cloned + 1))
        fi
    done <<< "$entries"
    echo "  cloned=$cloned failed=$failures"
    [ "$failures" -eq 0 ]
}

restore_system_config_advanced() {
    local archive work failures=0
    archive="$(module_path sysconfig)"
    if ! work=$(mktemp -d "${TMPDIR:-/tmp}/envbat-sysconfig.XXXXXX") || \
        ! "$PYTHON_BIN" "$RESTORE_SCRIPT_DIR/manifest.py" extract-tar "$RESTORE_DIR/$archive" "$work"; then
        [ -z "${work:-}" ] || rm -rf -- "$work"
        return 1
    fi

    if ask_yes_no "恢复 apt sources?" "N"; then
        if [ -f "$work/sources.list" ] && ! sudo install -m 644 "$work/sources.list" /etc/apt/sources.list; then
            failures=$((failures + 1))
        fi
        if [ -d "$work/sources.list.d" ] && ! sudo cp -a "$work/sources.list.d/." /etc/apt/sources.list.d/; then
            failures=$((failures + 1))
        fi
    fi
    if ask_yes_no "恢复 hostname 和 hosts?" "N"; then
        if [ -f "$work/hostname" ] && ! sudo install -m 644 "$work/hostname" /etc/hostname; then failures=$((failures + 1)); fi
        if [ -f "$work/hosts" ] && ! sudo install -m 644 "$work/hosts" /etc/hosts; then failures=$((failures + 1)); fi
    fi
    if ask_yes_no "恢复用户 crontab?" "N"; then
        if [ -s "$work/crontab.txt" ] && ! crontab "$work/crontab.txt"; then failures=$((failures + 1)); fi
    fi
    if [ -d "$work/netplan" ]; then
        warn "netplan 不会自动恢复；请从 system-config.tar.gz 手工检查"
    fi
    rm -rf -- "$work"
    [ "$failures" -eq 0 ]
}

restore_packages() {
    local packages_file
    packages_file="$(module_path packages)"
    if ! sudo dpkg --clear-selections || \
        ! sudo dpkg --set-selections < "$RESTORE_DIR/$packages_file" || \
        ! sudo apt-get dselect-upgrade -y; then
        fail "apt 包选择恢复失败"
        return 1
    fi
}

run_setup_repair() {
    "$RESTORE_SCRIPT_DIR/setup.sh" --repair
}

restore_cleanup() {
    if [ -n "$RESTORE_WORK_DIR" ] && [ -d "$RESTORE_WORK_DIR" ]; then
        rm -rf -- "$RESTORE_WORK_DIR"
    fi
    RESTORE_WORK_DIR=""
}

restore_required_or_stop() {
    local name="$1"
    shift
    if stage_required "$name" "$@"; then
        return 0
    fi
    restore_cleanup
    stage_finish "restore" || true
    return 1
}

restore_main() {
    if ! parse_args "$@"; then
        return 1
    fi
    if $SHOW_HELP; then
        show_help
        return 0
    fi
    STAGE_NAMES=(); STAGE_STATUSES=(); STAGE_REQUIRED=(); STAGE_MESSAGES=()

    echo ""
    echo "################################################"
    echo "#  envbat 安全恢复                             #"
    echo "################################################"

    restore_required_or_stop "restore precheck" restore_precheck || return 1
    restore_required_or_stop "safety snapshot" create_safety_snapshot || return 1
    restore_required_or_stop "dotfiles payload" prepare_restore_payload || return 1
    restore_required_or_stop "user state" restore_user_state || return 1

    if [ -d "$RESTORE_WORK_DIR/ssh" ]; then
        if ask_yes_no "单独恢复 ~/.ssh? 这会替换当前 SSH 目录" "N"; then
            stage_optional "ssh" restore_ssh_files
        else
            stage_skip "ssh" "user declined"
        fi
    else
        stage_skip "ssh" "backup missing"
    fi

    if module_is_ok directory_tree; then
        stage_optional "directory tree" restore_directory_tree
    else
        stage_skip "directory tree" "manifest status ${RESTORE_MODULE_STATUS[directory_tree]:-skip}"
    fi
    if module_is_ok git_repos; then
        stage_optional "git repos" restore_git_repos
    else
        stage_skip "git repos" "manifest status ${RESTORE_MODULE_STATUS[git_repos]:-skip}"
    fi

    if $INTERACTIVE && module_is_ok sysconfig; then
        stage_optional "system config advanced" restore_system_config_advanced
    else
        stage_skip "system config advanced" "advanced mode only"
    fi
    if $INTERACTIVE && module_is_ok packages; then
        if ask_yes_no "完整恢复 apt 包选择?" "N"; then
            stage_optional "packages advanced" restore_packages
        else
            stage_skip "packages advanced" "user declined"
        fi
    else
        stage_skip "packages advanced" "advanced mode only"
    fi

    if ask_yes_no "运行 ./popos/setup.sh --repair 补装依赖?" "N"; then
        stage_optional "setup repair" run_setup_repair
    else
        stage_skip "setup repair" "user declined"
    fi
    stage_optional "cleanup" restore_cleanup

    if ! stage_finish "restore"; then
        return 1
    fi
    echo "  来源: $RESTORE_DIR_REAL"
    echo "  安全快照: $SAFE_DIR"
    echo "  回滚命令: cp -a '$SAFE_DIR/home/.' '$HOME/'"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap restore_cleanup EXIT
    restore_main "$@"
fi
