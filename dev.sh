#!/usr/bin/env bash
# Source from zsh/bash to load `dev`, `ai`, and `llama-stop`.
# Execute directly to install packages and add the source line to your rc file.

# ----------------------------- settings ---------------------------------
DEV_WORKTREES_DIR="${DEV_WORKTREES_DIR-$HOME}"
DEV_DEFAULT_REPO="${DEV_DEFAULT_REPO-}"
DEV_BRANCH_PREFIX="${DEV_BRANCH_PREFIX-${USER:-user}/}"
DEV_WORKTREE_BASE="${DEV_WORKTREE_BASE-}"
DEV_WORKTREE_UPDATE="${DEV_WORKTREE_UPDATE-pull}"  # pull, fetch, none
DEV_DIRENV_ALLOW="${DEV_DIRENV_ALLOW-1}"
DEV_SESSION_COMMAND="${DEV_SESSION_COMMAND-}"
DEV_NEW_SESSION_LABEL="${DEV_NEW_SESSION_LABEL-+ new session}"
DEV_FZF_OPTS="${DEV_FZF_OPTS---height=40% --reverse --no-sort --bind=j:down,k:up,/:toggle-search --no-info --disabled}"

DEV_REMOTE_HOST="${DEV_REMOTE_HOST-}"
DEV_REMOTE_REPOS_DIR="${DEV_REMOTE_REPOS_DIR-\$HOME}"
DEV_REMOTE_REPO_DIR="${DEV_REMOTE_REPO_DIR-}"
DEV_REMOTE_WORKTREES_DIR="${DEV_REMOTE_WORKTREES_DIR-\$HOME}"
DEV_RSYNC_EXCLUDES="${DEV_RSYNC_EXCLUDES-.git node_modules __pycache__ .venv}"

AI_AGENTS="${AI_AGENTS-claude codex pi}"
AI_DEFAULT_AGENT="${AI_DEFAULT_AGENT-claude}"
AI_LOCAL_AGENTS="${AI_LOCAL_AGENTS-pi}"
AI_STATE_FILE="${AI_STATE_FILE-$HOME/.ai_last}"
AI_MODELS_DIR="${AI_MODELS_DIR-$HOME/models}"
AI_VALUE_FLAGS="${AI_VALUE_FLAGS---resume --model --session-id --add-dir --permission-mode --settings --mcp-config --agents --system-prompt --append-system-prompt --allowed-tools --disallowed-tools}"
AI_CLAUDE_ARGS="${AI_CLAUDE_ARGS-}"
AI_CODEX_ARGS="${AI_CODEX_ARGS-}"
AI_PI_ARGS="${AI_PI_ARGS---provider llama --model local-model}"

AI_LLAMA_PORT="${AI_LLAMA_PORT-8080}"
AI_LLAMA_CONTEXT="${AI_LLAMA_CONTEXT-8192}"
AI_LLAMA_GPU_LAYERS="${AI_LLAMA_GPU_LAYERS-99}"
AI_LLAMA_LOG="${AI_LLAMA_LOG-/tmp/llama-server.log}"
AI_LLAMA_WAIT_SECONDS="${AI_LLAMA_WAIT_SECONDS-60}"
AI_LLAMA_EXTRA_ARGS="${AI_LLAMA_EXTRA_ARGS-}"
AI_LLAMA_PROCESS_MATCH="${AI_LLAMA_PROCESS_MATCH-llama-server}"

DEV_INSTALL_PACKAGES="${DEV_INSTALL_PACKAGES-tmux fzf direnv}"
DEV_INSTALL_DEPS="${DEV_INSTALL_DEPS-1}"
DEV_INSTALL_RC_FILE="${DEV_INSTALL_RC_FILE-}"
DEV_INSTALL_PATH="${DEV_INSTALL_PATH-$HOME/.dev.sh}"
DEV_INSTALL_URL="${DEV_INSTALL_URL-https://saah.as/x/dev.sh}"

# ----------------------------- small helpers ----------------------------
_dev_sourced() {
    if [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then case "$ZSH_EVAL_CONTEXT" in *:file*) return 0 ;; esac; fi
    if [ -n "${BASH_SOURCE:-}" ]; then [ "${BASH_SOURCE[0]}" != "$0" ] && return 0; fi
    return 1
}

_dev_script_path() {
    local src="$0" dir
    [ -n "${BASH_SOURCE:-}" ] && src="${BASH_SOURCE[0]}"
    case "$src" in
        /*) printf '%s\n' "$src" ;;
        *) dir=$(cd "$(dirname "$src")" && pwd -P) && printf '%s/%s\n' "$dir" "$(basename "$src")" ;;
    esac
}

_dev_words() { printf '%s\n' "$1" | tr '[:space:]' '\n' | sed '/^$/d'; }

_dev_words_to_array() {
    _DEV_WORDS=()
    local word
    while IFS= read -r word; do [ -n "$word" ] && _DEV_WORDS+=("$word"); done <<EOF
$(_dev_words "$1")
EOF
}

_dev_run_with_args() {
    local cmd="$1" extra="$2"; shift 2
    _dev_words_to_array "$extra"
    command "$cmd" "${_DEV_WORDS[@]}" "$@"
}

_dev_require() {
    local missing=0 cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || { echo "Missing dependency: $cmd" >&2; missing=1; }
    done
    [ "$missing" = 0 ]
}

_dev_path_join() {
    local base="${1%/}" name="$2"
    [ -z "$base" ] && base="/"
    [ "$base" = "/" ] && printf '/%s\n' "$name" || printf '%s/%s\n' "$base" "$name"
}

_dev_sq() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# ----------------------------- install mode -----------------------------
_dev_rc_file() {
    [ -n "$DEV_INSTALL_RC_FILE" ] && { printf '%s\n' "$DEV_INSTALL_RC_FILE"; return; }
    case "${SHELL##*/}" in
        zsh) printf '%s\n' "$HOME/.zshrc" ;;
        bash) printf '%s\n' "$HOME/.bashrc" ;;
        *) echo "Unknown shell; pass --rc-file PATH." >&2; return 1 ;;
    esac
}

_dev_rc_has_source() {
    local rc="$1" script="$2" rel tilde_char tilde_ref
    [ -f "$rc" ] || return 1
    grep -Fq "$script" "$rc" && return 0
    rel="${script#"$HOME"/}"
    tilde_char='~'
    tilde_ref="$tilde_char/$rel"
    [ "$rel" != "$script" ] && { grep -Fq "\$HOME/$rel" "$rc" || grep -Fq "$tilde_ref" "$rc"; }
}

_dev_install_packages() {
    [ "$DEV_INSTALL_DEPS" = 0 ] && return
    _dev_words_to_array "$DEV_INSTALL_PACKAGES"
    [ "${#_DEV_WORDS[@]}" -eq 0 ] && return
    if command -v brew >/dev/null 2>&1; then
        local pkg
        for pkg in "${_DEV_WORDS[@]}"; do
            if brew list --formula "$pkg" >/dev/null 2>&1; then
                echo "$pkg already installed"
            else
                brew install "$pkg"
            fi
        done
    elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y "${_DEV_WORDS[@]}"
    elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y "${_DEV_WORDS[@]}"
    elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed "${_DEV_WORDS[@]}"
    else echo "Install manually: $DEV_INSTALL_PACKAGES" >&2
    fi
}

_dev_install_script() {
    local target="$1" src tmp
    mkdir -p "$(dirname "$target")"
    tmp="${target}.tmp.$$"
    src=$(_dev_script_path 2>/dev/null || true)
    if [ -n "$src" ] && [ -f "$src" ]; then
        cp "$src" "$tmp"
    else
        _dev_require curl || return
        curl -fsSL "$DEV_INSTALL_URL" -o "$tmp"
    fi
    chmod 755 "$tmp"
    mv "$tmp" "$target"
    echo "Installed $target"
}

_dev_install() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-deps) DEV_INSTALL_DEPS=0 ;;
            --rc-file) [ "$#" -gt 1 ] || { echo "--rc-file needs a path" >&2; return 2; }; shift; DEV_INSTALL_RC_FILE="$1" ;;
            --rc-file=*) DEV_INSTALL_RC_FILE="${1#--rc-file=}" ;;
            --install-path) [ "$#" -gt 1 ] || { echo "--install-path needs a path" >&2; return 2; }; shift; DEV_INSTALL_PATH="$1" ;;
            --install-path=*) DEV_INSTALL_PATH="${1#--install-path=}" ;;
            -h|--help) echo "Usage: dev.sh [--no-deps] [--rc-file PATH] [--install-path PATH]"; return ;;
            *) echo "Unknown option: $1" >&2; return 2 ;;
        esac
        shift
    done
    local script rc line
    script="$DEV_INSTALL_PATH"
    _dev_install_script "$script" || return
    rc=$(_dev_rc_file) || return 1
    line="[ -f \"$script\" ] && . \"$script\""
    _dev_install_packages
    mkdir -p "$(dirname "$rc")"; touch "$rc"
    if _dev_rc_has_source "$rc" "$script"; then
        echo "$rc already sources $script"
    else
        printf '\n# dev: tmux + worktree session manager\n%s\n' "$line" >> "$rc"
        echo "Added source line to $rc"
    fi
    echo "Done. Open a new shell, or run: . \"$rc\""
}

if ! _dev_sourced; then set -e; _dev_install "$@"; exit $?; fi

# ----------------------------- dev helpers ------------------------------
_dev_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null && return
    [ -n "$DEV_DEFAULT_REPO" ] && [ -e "$DEV_DEFAULT_REPO/.git" ] && printf '%s\n' "$DEV_DEFAULT_REPO"
}

_dev_main_branch() {
    local head
    head=$(git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    [ -n "$head" ] && printf '%s\n' "${head#origin/}" || printf 'main\n'
}

_dev_update_repo_for_worktree() {
    case "$DEV_WORKTREE_UPDATE" in
        pull) git -C "$1" pull --ff-only ;;
        fetch) git -C "$1" fetch --prune origin ;;
        none|"") return 0 ;;
        *) echo "Unknown DEV_WORKTREE_UPDATE=$DEV_WORKTREE_UPDATE" >&2; return 1 ;;
    esac
}

_dev_worktree_known() {
    git -C "$1" worktree list --porcelain | sed -n 's/^worktree //p' | grep -Fxq "$2"
}

_dev_prepare_worktree() {
    local repo="$1" dir="$2" name="$3" branch
    local -a base_ref
    branch="${DEV_BRANCH_PREFIX}${name}"
    base_ref=(); [ -n "$DEV_WORKTREE_BASE" ] && base_ref=("$DEV_WORKTREE_BASE")
    _dev_update_repo_for_worktree "$repo" || return
    git -C "$repo" worktree add -b "$branch" "$dir" "${base_ref[@]}" ||
        git -C "$repo" worktree add "$dir" "$branch" ||
        git -C "$repo" worktree add "$dir" "origin/$branch" || return
    [ "$DEV_DIRENV_ALLOW" = 0 ] || ! command -v direnv >/dev/null 2>&1 || direnv allow "$dir"
}

_dev_start_session() {
    local name="$1" dir="${2:-}" cmd="${3-$DEV_SESSION_COMMAND}"
    if [ -n "$dir" ]; then
        tmux new-session -d -s "$name" -c "$dir"
    else
        tmux new-session -d -s "$name"
    fi
    [ -z "$cmd" ] || tmux send-keys -t "$name" "$cmd" Enter
}

_dev_list_worktrees() {
    [ -d "$DEV_WORKTREES_DIR" ] || return
    find "$DEV_WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null |
        while IFS= read -r dir; do [ -e "$dir/.git" ] && basename "$dir"; done
}

_dev_clean() {
    local repo wt_root main all=false
    local -a targets
    targets=()
    repo=$(_dev_repo_root) || { echo "Not in a git repo and DEV_DEFAULT_REPO is not valid." >&2; return 1; }
    for arg in "$@"; do
        case "$arg" in --all|--force) all=true ;; --*) echo "Unknown flag: $arg" >&2; return 1 ;; *) targets+=("${arg%/}") ;; esac
    done
    git -C "$repo" worktree prune
    wt_root="${DEV_WORKTREES_DIR%/}"; [ -z "$wt_root" ] && wt_root="/"
    if [ "${#targets[@]}" -gt 0 ]; then
        local target dir name
        for target in "${targets[@]}"; do
            case "$target" in /*) dir="$target"; name="${target##*/}" ;; *) dir=$(_dev_path_join "$wt_root" "$target"); name="$target" ;; esac
            if _dev_worktree_known "$repo" "$dir"; then
                echo "Removing $dir"; git -C "$repo" worktree remove "$dir" && tmux kill-session -t "$name" 2>/dev/null
            else
                echo "No worktree at $dir"
            fi
        done
    else
        main=$(_dev_main_branch "$repo")
        git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p' |
            while IFS= read -r wt; do
                [ "$wt" = "$repo" ] && continue
                case "$wt" in "$wt_root"/*) ;; *) continue ;; esac
                local branch merged=false name
                branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
                [ -z "$branch" ] && continue
                git -C "$repo" branch --format='%(refname:short)' --merged "$main" | grep -Fxq "$branch" && merged=true
                name="${wt##*/}"
                if $all || $merged; then
                    echo "Removing $wt ($branch${merged:+ - merged})"
                    git -C "$repo" worktree remove "$wt" && tmux kill-session -t "$name" 2>/dev/null
                else
                    echo "Skipping $wt ($branch - not merged, use --all/--force to remove)"
                fi
            done
    fi
    git -C "$repo" worktree prune
}

_dev_port() {
    local detach=false run_cmd_set=false run_cmd
    local -a port_args
    port_args=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -d|--detach|--no-attach) detach=true ;;
            -r|--run) [ "$#" -gt 1 ] || { echo "--run needs a command" >&2; return 2; }; shift; run_cmd="$1"; run_cmd_set=true ;;
            --run=*) run_cmd="${1#--run=}"; run_cmd_set=true ;;
            *) port_args+=("$1") ;;
        esac
        shift
    done
    set -- "${port_args[@]}"
    local name="$1" remote="${2:-$DEV_REMOTE_HOST}"
    [ -n "$name" ] && [ -n "$remote" ] || { echo "Usage: dev port [-d] [-r CMD] <name> [remote-host]" >&2; return 1; }
    _dev_require git ssh rsync || return
    local dir repo branch repo_name remote_repo remote_wt remote_base remote_cmd
    local q_name q_remote_base q_remote_repo q_remote_wt q_branch q_origin_branch q_run
    dir=$(_dev_path_join "$DEV_WORKTREES_DIR" "$name")
    [ -d "$dir" ] || { echo "No worktree at $dir" >&2; return 1; }
    repo=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { echo "Not a git worktree: $dir" >&2; return 1; }
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
    repo_name="${repo##*/}"
    [ -n "$DEV_REMOTE_REPO_DIR" ] && remote_repo="$DEV_REMOTE_REPO_DIR" || remote_repo=$(_dev_path_join "$DEV_REMOTE_REPOS_DIR" "$repo_name")
    remote_wt=$(_dev_path_join "$DEV_REMOTE_WORKTREES_DIR" "$name")
    remote_base="${DEV_REMOTE_WORKTREES_DIR%/}"
    q_name=$(_dev_sq "$name")
    q_remote_base=$(_dev_sq "$remote_base")
    q_remote_repo=$(_dev_sq "$remote_repo")
    q_remote_wt=$(_dev_sq "$remote_wt")
    q_branch=$(_dev_sq "$branch")
    q_origin_branch=$(_dev_sq "origin/$branch")
    echo "Pushing $branch to origin..."; git -C "$dir" push -u origin "$branch" || return
    echo "Setting up worktree on $remote..."
    remote_cmd="mkdir -p $q_remote_base && cd $q_remote_repo && git fetch origin && (git worktree add $q_remote_wt $q_branch 2>/dev/null || git worktree add -b $q_branch $q_remote_wt $q_origin_branch)"
    printf '%s\n' "$remote_cmd" | ssh "$remote" sh || return
    local -a rsync_args; local exclude
    rsync_args=()
    for exclude in $(_dev_words "$DEV_RSYNC_EXCLUDES"); do rsync_args+=("--exclude=$exclude"); done
    echo "Syncing uncommitted changes..."
    rsync -az --delete "${rsync_args[@]}" "$dir/" "$remote:$remote_wt/" || return
    if $detach; then
        echo "Setting up detached remote tmux session '$name'..."
        local remote_tmux="tmux new-session -A -d -s $q_name -c $q_remote_wt"
        if $run_cmd_set; then
            q_run=$(_dev_sq "$run_cmd")
            remote_tmux="$remote_tmux && tmux send-keys -t $q_name $q_run Enter"
        fi
        ssh "$remote" "$remote_tmux" || return
        echo "Session '$name' ready on $remote. Attach with: ssh -t $remote tmux attach -t $name"
    else
        echo "Attaching to remote tmux session '$name'..."
        if $run_cmd_set; then
            q_run=$(_dev_sq "$run_cmd")
            ssh -t "$remote" "tmux new-session -A -d -s $q_name -c $q_remote_wt && tmux send-keys -t $q_name $q_run Enter && tmux attach -t $q_name"
        else
            ssh -t "$remote" "tmux new-session -A -s $q_name -c $q_remote_wt"
        fi
    fi
}

# ----------------------------- ai command -------------------------------
_ai_load_state() {
    _ai_state_agent=""; _ai_state_model=""
    [ -f "$AI_STATE_FILE" ] || return
    local key value
    while IFS='=' read -r key value; do
        case "$key" in agent) _ai_state_agent="$value" ;; model) _ai_state_model="$value" ;; esac
    done < "$AI_STATE_FILE"
}

_ai_save_state() {
    mkdir -p "$(dirname "$AI_STATE_FILE")" 2>/dev/null || true
    { printf 'agent=%s\n' "$1"; printf 'model=%s\n' "${2:-}"; } > "$AI_STATE_FILE"
}

_ai_pick_agent() { _dev_require fzf && _dev_words "$AI_AGENTS" | fzf --prompt="ai > " --height=30% --reverse --no-info; }
_ai_pick_model() {
    _dev_require fzf || return
    [ -d "$AI_MODELS_DIR" ] || { echo "Models dir not found: $AI_MODELS_DIR" >&2; return 1; }
    find "$AI_MODELS_DIR" -maxdepth 1 -name '*.gguf' -exec basename {} \; 2>/dev/null |
        sort | fzf --prompt="model > " --height=30% --reverse --no-info
}
_ai_uses_local_model() { case " $AI_LOCAL_AGENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
_ai_arg_takes_value() { case " $AI_VALUE_FLAGS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
_ai_llama_health_url() { printf 'http://localhost:%s/health\n' "$AI_LLAMA_PORT"; }
_ai_llama_healthy() { curl -fsS "$(_ai_llama_health_url)" >/dev/null 2>&1; }
_ai_running_model() {
    local model_path
    model_path=$(ps ax -o command= | awk '
        /(^|[\/ ])llama-server([[:space:]]|$)/ {
            for (i = 1; i < NF; i++) if ($i == "-m") { print $(i + 1); exit }
        }
    ')
    [ -n "$model_path" ] && basename "$model_path"
    return 0
}

_ai_rewrite_prompt_args() {
    local arg prompt
    local -a flags words
    flags=(); words=()
    while [ "$#" -gt 0 ]; do
        arg="$1"; shift
        case "$arg" in
            --) while [ "$#" -gt 0 ]; do words+=("$1"); shift; done; break ;;
            -*) flags+=("$arg"); _ai_arg_takes_value "$arg" && [ "$#" -gt 0 ] && { flags+=("$1"); shift; } ;;
            *) words+=("$arg") ;;
        esac
    done
    prompt="${words[*]}"
    AI_ARGS=("${flags[@]}")
    [ -n "$prompt" ] && AI_ARGS+=("$prompt")
}

_llama_ensure() {
    local model="$1" model_path i
    model_path=$(_dev_path_join "$AI_MODELS_DIR" "$model")
    [ -f "$model_path" ] || { echo "Model not found: $model_path" >&2; return 1; }
    _dev_require curl llama-server || return
    _ai_llama_healthy && return
    echo "Starting llama-server with $model..."
    _dev_words_to_array "$AI_LLAMA_EXTRA_ARGS"
    llama-server -m "$model_path" -c "$AI_LLAMA_CONTEXT" -ngl "$AI_LLAMA_GPU_LAYERS" --port "$AI_LLAMA_PORT" "${_DEV_WORDS[@]}" > "$AI_LLAMA_LOG" 2>&1 &
    disown
    i=0
    while ! _ai_llama_healthy; do
        sleep 1; i=$((i + 1))
        [ "$i" -lt "$AI_LLAMA_WAIT_SECONDS" ] || { echo "llama-server failed to start. Check $AI_LLAMA_LOG" >&2; return 1; }
        printf '\rWaiting for server... %ds' "$i"
    done
    printf '\nllama-server ready.\n'
}

llama-stop() {
    pkill -f "$AI_LLAMA_PROCESS_MATCH" && echo "llama-server stopped." || echo "No llama-server running."
}

_ai_run_direct_agent() {
    local agent="$1"; shift
    case "$agent" in
        claude) _dev_require claude && _ai_save_state "$agent" && _dev_run_with_args claude "$AI_CLAUDE_ARGS" "$@" ;;
        codex) _dev_require codex && _ai_save_state "$agent" && _dev_run_with_args codex "$AI_CODEX_ARGS" "$@" ;;
        *) _dev_require "$agent" && _ai_save_state "$agent" && "$agent" "$@" ;;
    esac
}

_ai_run_local_agent() {
    local agent="$1" model="$2"; shift 2
    _llama_ensure "$model" || return
    case "$agent" in
        pi) _dev_require pi && _dev_run_with_args pi "$AI_PI_ARGS" "$@" ;;
        *) echo "No local runner configured for agent '$agent'." >&2; return 1 ;;
    esac
}

ai() {
    local pick=false agent model last_agent last_model running
    [ "${1:-}" = "-p" ] && { pick=true; shift; }
    _ai_load_state
    last_agent="${_ai_state_agent:-$AI_DEFAULT_AGENT}"; last_model="$_ai_state_model"
    if $pick || [ -z "$last_agent" ]; then agent=$(_ai_pick_agent) || return 0; else agent="$last_agent"; fi
    [ -z "$agent" ] && return 0
    _ai_rewrite_prompt_args "$@"; set -- "${AI_ARGS[@]}"
    if ! _ai_uses_local_model "$agent"; then _ai_run_direct_agent "$agent" "$@"; return; fi
    if [ -z "$last_model" ] || [ "$agent" != "$last_agent" ]; then model=$(_ai_pick_model) || return 0; else model="$last_model"; fi
    [ -z "$model" ] && return 0
    _ai_llama_healthy && running=$(_ai_running_model) || running=""
    if [ -n "$running" ] && [ "$running" != "$model" ]; then echo "Swapping model: $running -> $model"; llama-stop; sleep 1; fi
    _ai_save_state "$agent" "$model"
    _ai_run_local_agent "$agent" "$model" "$@"
}

# ----------------------------- dev command ------------------------------
dev() {
    case "${1:-}" in
        clean) shift; _dev_clean "$@"; return ;;
        port) shift; _dev_port "$@"; return ;;
        -h|--help)
            echo "Usage: dev [-w] [-d] [-r CMD] [name] | dev clean [--all|name...] | dev port [-d] <name> [remote]"
            echo "  -w, --worktree     create/use a git worktree"
            echo "  -d, --no-attach    create the session without attaching (for non-interactive callers)"
            echo "  -r, --run CMD      command to send into the new session (overrides DEV_SESSION_COMMAND)"
            return ;;
    esac

    local use_worktree=false detach=false run_cmd_set=false run_cmd name dir repo pick sessions worktrees combined
    local -a args
    args=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -w|--worktree) use_worktree=true ;;
            -d|--detach|--no-attach) detach=true ;;
            -r|--run) [ "$#" -gt 1 ] || { echo "--run needs a command" >&2; return 2; }; shift; run_cmd="$1"; run_cmd_set=true ;;
            --run=*) run_cmd="${1#--run=}"; run_cmd_set=true ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    set -- "${args[@]}"
    _dev_require tmux || return

    if [ -n "${1:-}" ]; then
        name="$1"; dir=$(_dev_path_join "$DEV_WORKTREES_DIR" "$name")
        local -a start_args
        if ! tmux has-session -t "$name" 2>/dev/null; then
            start_args=("$name")
            if $use_worktree; then
                _dev_require git || return
                repo=$(_dev_repo_root) || { echo "Not in a git repo and DEV_DEFAULT_REPO is not valid." >&2; return 1; }
                _dev_prepare_worktree "$repo" "$dir" "$name" || return
                start_args+=("$dir")
            elif [ -d "$dir" ]; then
                start_args+=("$dir")
            else
                start_args+=("")
            fi
            $run_cmd_set && start_args+=("$run_cmd")
            _dev_start_session "${start_args[@]}"
        elif $run_cmd_set; then
            tmux send-keys -t "$name" "$run_cmd" Enter
        fi
        if $detach; then
            echo "Session '$name' ready. Attach with: dev $name"
        else
            tmux attach-session -t "$name"
        fi
        return
    fi

    _dev_require fzf || return
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    worktrees=$(_dev_list_worktrees)
    combined=$(printf '%s\n%s\n%s\n' "$sessions" "$worktrees" "$DEV_NEW_SESSION_LABEL" | awk 'NF && !seen[$0]++')
    _dev_words_to_array "$DEV_FZF_OPTS"
    pick=$(printf '%s\n' "$combined" | fzf --prompt="dev > " "${_DEV_WORDS[@]}")
    [ -z "$pick" ] && return 0
    if [ "$pick" = "$DEV_NEW_SESSION_LABEL" ]; then
        printf 'Session name: '; read -r name
        [ -z "$name" ] && return 0
        if $use_worktree; then
            dev -w "$name"
        else
            dev "$name"
        fi
    else
        dev "$pick"
    fi
}
