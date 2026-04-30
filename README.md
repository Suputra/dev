# dev.sh

A small shell helper for tmux-based development sessions, git worktrees, and
optional AI agent launchers.

`dev.sh` can be sourced from `zsh` or `bash` to load:

- `dev`: create, pick, and attach to tmux sessions, optionally backed by git worktrees
- `dev clean`: remove merged or named worktrees and matching tmux sessions
- `dev port`: push and rsync a worktree to a remote host, then attach there
- `ai`: launch a remembered coding agent (`claude`, `codex`, or local `pi`)
- `llama-stop`: stop the local `llama-server`

## Install

Run the installer:

```sh
curl -fsSL https://saah.as/x/dev.sh | bash
```

The installer writes `dev.sh` to `~/.dev.sh`, adds a source line to your
shell rc file, and installs the default dependencies when a supported package
manager is available.

To skip dependency installation:

```sh
curl -fsSL https://saah.as/x/dev.sh | bash -s -- --no-deps
```

To target a specific rc file:

```sh
curl -fsSL https://saah.as/x/dev.sh | bash -s -- --rc-file ~/.zshrc
```

## Usage

```sh
dev                 # pick an existing tmux session or worktree with fzf
dev api                       # attach to/create a tmux session named api
dev -w api                    # create/use a git worktree and attach to it
dev -w -d api                 # create the worktree + session without attaching (for scripts/agents)
dev -w -d -r 'ai "fix X"' api # same, but run a specific command inside (e.g. launch an agent with a mission)
dev clean                     # remove merged managed worktrees
dev clean --all               # remove all managed worktrees
dev port api host             # push/sync the api worktree to host and attach remotely
dev port -d api host          # push/sync without attaching; pair with -r 'ai "..."' to run on the remote

ai                  # launch the last used agent
ai -p               # pick an agent
ai fix this test    # pass an unquoted prompt as one argument
llama-stop          # stop llama-server
```

## Configuration

Defaults live in `dev.sh`. To override them, set variables before the installer
source line in your `~/.zshrc` or `~/.bashrc`.

```sh
export DEV_DEFAULT_REPO="$HOME/my-project"
export DEV_WORKTREES_DIR="$HOME/worktrees"
export DEV_BRANCH_PREFIX="$USER/"
export DEV_SESSION_COMMAND=""        # e.g. "ai" to auto-start an agent
export DEV_REMOTE_HOST="devbox"

export AI_AGENTS="claude codex pi"
export AI_DEFAULT_AGENT="claude"
export AI_MODELS_DIR="$HOME/models"
export AI_CLAUDE_ARGS=""
export AI_CODEX_ARGS=""
export AI_LLAMA_CONTEXT="8192"

[ -f "$HOME/.dev.sh" ] && . "$HOME/.dev.sh"
```

Common settings live at the top of `dev.sh`, so you can scan the file for the
full list.
