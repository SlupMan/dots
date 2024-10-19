# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Enable bash completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# Enable sudo command completion
if [ -f /usr/share/bash-completion/completions/sudo ]; then
    . /usr/share/bash-completion/completions/sudo
fi

# Set up prompt to include git branch if in a git directory
parse_git_branch() {
    git branch 2>/dev/null | grep '^*' | colrm 1 2
}

export PS1='\u@\h:\w$( [ "$(parse_git_branch)" ] && echo " (git:$(parse_git_branch))" )\$ '

# Aliases for common applications
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias vim='nvim'
alias vi='nvim'
alias editor='nvim'

alias term='alacritty'
alias filemgr='thunar'

alias update='sudo pacman -Syu'
alias yayupdate='yay -Syu --devel'

# Alias for system monitoring
alias htop='htop'

# Clipboard aliases
alias copy='wl-copy'
alias paste='wl-paste'

# Network management
alias wifi='nmcli device wifi'
alias connect='nmcli device wifi connect'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Export environment variables for GTK and QT applications
export GTK_THEME=Adwaita:dark
export QT_QPA_PLATFORM=wayland
export XDG_CURRENT_DESKTOP=Hyprland

# Source user-specific environment variables
if [ -f ~/.bashrc_local ]; then
    . ~/.bashrc_local
fi

# Set language and locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Set up user directories
if [ -f ~/.config/user-dirs.dirs ]; then
    . ~/.config/user-dirs.dirs
fi

# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Function to lock the screen
lock() {
    waylock
}

# Function to take a screenshot
screenshot() {
    grim ~/Pictures/Screenshot-$(date +%F-%T).png
    echo "Screenshot saved to ~/Pictures"
}

# Function to take a selection screenshot
screenshot_sel() {
    grim -g "$(slurp)" ~/Pictures/Screenshot-$(date +%F-%T).png
    echo "Screenshot saved to ~/Pictures"
}

# Function to edit configuration files quickly
config() {
    nvim ~/.config/"$1"
}

# Function to restart Hyprland
restart_wm() {
    hyprctl reload
}

# Load Hyprland-specific environment variables
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland-egl
export CLUTTER_BACKEND=wayland
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24

# Set default applications
export TERMINAL=alacritty
export BROWSER=firefox
export EDITOR=nvim

# Wayland clipboard support for Neovim
export NVIM_LISTEN_ADDRESS=/tmp/nvimsocket

# Reduce GTK overlay scrolling friction
export GTK_OVERLAY_SCROLLING=0

# For PipeWire and PulseAudio
export PIPEWIRE_LATENCY=128/48000

# For applications that need XDG portals
export XDG_SESSION_DESKTOP=Hyprland
# export XDG_CURRENT_DESKTOP=sway
