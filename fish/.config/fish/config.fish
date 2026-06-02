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
