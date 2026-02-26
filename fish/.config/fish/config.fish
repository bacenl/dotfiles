if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_add_path ~/.local/bin
end
if type -q keychain
    SHELL=(which fish) keychain --quiet --eval id_ed25519 | source
end
