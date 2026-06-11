if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_add_path ~/.local/bin
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
if test -f /home/bacen/miniforge3/bin/conda
    eval /home/bacen/miniforge3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/bacen/miniforge3/etc/fish/conf.d/conda.fish"
        . "/home/bacen/miniforge3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/bacen/miniforge3/bin" $PATH
    end
end
# <<< conda initialize <<<


# peon-ping quick controls
function peon; bash /home/bacen/.claude/hooks/peon-ping/peon.sh $argv; end
