set quiet := true

masonPath := "$HOME/.local/share/nvim/mason/bin/"

#───────────────────────────────────────────────────────────────────────────────

stylua:
    #!/usr/bin/env zsh
    {{ masonPath }}/stylua --check --output-format=summary . && return 0
    {{ masonPath }}/stylua .
    echo "\nFiles formatted."

lua_ls_check:
    {{ masonPath }}/lua-language-server --check .
