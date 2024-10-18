# ~/.bashrc

# Add user bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Set Alacritty as default terminal
export TERMINAL=alacritty

# Enable colorful prompt
export PS1='\e[1;32m\u@\h:\w\$\e[0m '

# Aliases
alias ll='ls -la --color=auto'
alias vim='nvim'
alias update='sudo pacman -Syu'
alias cls='clear'

# NVM and NodeJS (if used)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Start Wayland session if not already running
[ -z "$WAYLAND_DISPLAY" ] && export XDG_SESSION_TYPE=wayland && export MOZ_ENABLE_WAYLAND=1
