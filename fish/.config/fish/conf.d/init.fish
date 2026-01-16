if status is-interactive
    # Use vi keybindings

    if command -v mise &>/dev/null
        mise activate fish | source
    end

    if command -v zoxide &>/dev/null
        zoxide init fish | source
    end

    if command -v starship &>/dev/null
        starship init fish | source
    end
end
