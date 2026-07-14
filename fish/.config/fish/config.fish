if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_add_path "$HOME/.local/bin"
end

if not set -q TMUX
    tmux start-server
    tmux new-session -d -s main 2>/dev/null
    true
end

# SSH agent socket (managed by systemd)
if test -S "$XDG_RUNTIME_DIR/ssh-agent.socket"
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
set -l miniforge_dir "$HOME/miniforge3"
if test -f "$miniforge_dir/bin/conda"
    eval "$miniforge_dir/bin/conda" "shell.fish" hook $argv | source
else
    if test -f "$miniforge_dir/etc/fish/conf.d/conda.fish"
        . "$miniforge_dir/etc/fish/conf.d/conda.fish"
    else
        fish_add_path "$miniforge_dir/bin"
    end
end
# <<< conda initialize <<<

# Supply chain: 7-day freshness gate for uv dependency resolution
set -gx UV_EXCLUDE_NEWER (date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z 2>/dev/null; or date -u -v-7d +%Y-%m-%dT00:00:00Z 2>/dev/null)

# peon-ping quick controls
function peon
    bash "$HOME/.claude/hooks/peon-ping/peon.sh" $argv
end
