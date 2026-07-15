zvm_after_init() {
  autoload -Uz compinit && compinit

  eval "$(@atuin@ init zsh --disable-up-arrow)"

  # IntelliShell setup
  export GIST_TOKEN="$(cat /run/secrets/gh-gist-token 2>/dev/null || true)"
  _is_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/intelli-shell"
  mkdir -p "$_is_cfg"
  ln -sf /etc/intellishell/config.toml "$_is_cfg/config.toml"
  unset _is_cfg
  eval "$(@intelli_shell@ init zsh)"

  source @zsh_fzf_tab@/share/fzf-tab/fzf-tab.plugin.zsh

  zstyle ':completion:*' list-dirs-first true
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
  zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
  zstyle ':completion:*' group-name ''
  zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'
  zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
  zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
  zstyle ':completion:*:corrections' format '%F{yellow}-- %d (errors: %e) --%f'

  source @zsh_autosuggestions@/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh

  eval "$(@zoxide@ init zsh)"

  if [[ "$(hostname)" == "mab" || "$(hostname)" == "thoth" ]]; then
    clip-paste() { LBUFFER+="$(cat /tmp/clipboard)"; }
    zle -N clip-paste
    bindkey '^V' clip-paste
  fi
}

alias gaa='git add .'
alias gcb='git checkout -b'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcom='git checkout main'
alias gp='git push'
alias gl='git pull'
alias gsv='git status -vv'
alias glg='git lg'
alias gd='git diff'
alias cht='cht.sh'
alias ouroboros='uvx --from "ouroboros-ai[mcp]" ouroboros'
alias ooo='uvx --from "ouroboros-ai[mcp]" ouroboros'
alias agentmemory='npx -y @agentmemory/agentmemory@latest'
alias chub='npx @aisuite/chub'
alias gh-axi='npx gh-axi'
alias chrome-devtools-axi='npx chrome-devtools-axi'
alias pi='python3 -i'
alias zld='zellij --layout dev'
alias ll='ls -al'
alias codegraph='npx @colbymchenry/codegraph'

# ── Codex exec shortcuts ───────────────────────────────────
# cxi: generate a command from a prompt and save to intelli-shell
# cxh: mine recent atuin history for bookmarkable commands
# cxg: just generate a shell command, output only the command

cxi() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: cxi <description of command to bookmark>"
    return 1
  fi
  codex exec --skip-git-repo-check \
    --add-dir "$HOME/.local/share/intelli-shell" \
    "You are a shell command expert on NixOS with zsh.
The user wants to bookmark a reusable command template in intelli-shell.

Description: $*

Generate the shell command and record it using intelli-shell new. Rules:
- Use {{variable}} syntax for parameters the user fills in at runtime.
- Use {{opt1|opt2}} for choices. Use {{{name}}} for secrets or ephemeral values.
- Keep commands generalized — replace concrete paths/IDs/names with variables.
- Run: intelli-shell new \"<command>\" --description \"<concise description with #hashtags>\" [--alias \"<alias>\"]
- Only add --alias if a natural 2-4 char alias exists.
- If a similar command already exists (search first with: intelli-shell search \"<keyword>\"), skip it.
Print a one-line confirmation of what you saved."
}

cxh() {
  local limit="${1:-100}"
  codex exec --skip-git-repo-check \
    --add-dir "$HOME/.local/share/intelli-shell" \
    "You are helping curate a shell command library in intelli-shell on NixOS with zsh.

First, look at recent shell history by running: atuin search --limit $limit --format '{command}'

From that history, identify 5-15 commands worth bookmarking. Look for:
- Non-trivial, reusable commands (infrastructure, dev workflows, git ops, nix commands)
- Commands with varying arguments that would benefit from {{variable}} templating

Skip: trivial commands (cd, ls, cat, echo), one-off commands, duplicates, and commands that are already simple.

For each command:
1. Check if a similar one exists: intelli-shell search \"<keyword>\"
2. If new, generalize into a template and record:
   intelli-shell new \"<command>\" --description \"<desc with #hashtags>\" [--alias \"<alias>\"]
3. Only add --alias if a natural 2-4 char alias exists.

Print a summary of what you bookmarked (or skipped as duplicates)."
}

cxg() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: cxg <description of command>"
    return 1
  fi
  local tmpfile=$(mktemp /tmp/cxg-XXXXXX)
  codex exec --skip-git-repo-check \
    -o "$tmpfile" \
    "Generate ONLY the shell command for the following request.
Output nothing but the raw command — no explanation, no markdown, no backticks.

Request: $*"
  cat "$tmpfile"
  rm -f "$tmpfile"
}

get_cht() {
  PATH_DIR="$HOME/.local/bin"
  mkdir -p "$PATH_DIR"
  curl https://cht.sh/:cht.sh > "$PATH_DIR/cht.sh"
  chmod +x "$PATH_DIR/cht.sh"
}

tre() { command tre "$@" -e && source "/tmp/tre_aliases_$USER" 2>/dev/null; }

eval "$(@starship@ init zsh)"
source @zsh_syntax_highlighting@/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source @zsh_vi_mode@/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
