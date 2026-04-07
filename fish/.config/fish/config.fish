if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_add_path ~/.local/bin
end

# SSH agent socket (managed by systemd)
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
