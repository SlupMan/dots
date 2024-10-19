#!/bin/bash

# Step 1: Install yay
if ! command -v yay &> /dev/null
then
    echo "Installing yay..."
    sudo pacman -S --needed git base-devel --noconfirm
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
else
    echo "yay is already installed."
fi

# Step 2: Bundle and install packages

# Pacman packages
pacman_packages=(
    mako
    pipewire
    wireplumber
    pipewire-pulse
    xdg-desktop-portal-gtk
    xdg-desktop-portal
    waybar
    wofi
    sddm
    nm-applet
    wlroots
    alacritty
    thunar
    neovim
    mesa
    libxcb
    xorg-xwayland
    grim
    slurp
    networkmanager
    pavucontrol
    brightnessctl
    archlinux-keyring
    xdg-utils
    xdg-user-dirs
    libinput
    polkit
    xsettingsd
    ttf-dejavu
    ttf-liberation
    noto-fonts-emoji
    gvfs
    seatd
    fuse3
    bluez
    bluez-utils
    blueman
    xf86-input-libinput
    tlp
    tlp-rdw
    lm_sensors
    ntfs-3g
    exfatprogs
    dosfstools
    bash-completion
    htop
    wget
    git
    gtk3
    gtk4
)

echo "Installing packages from official repositories..."
sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"

# AUR packages
aur_packages=(
    hyprpaper
    hyprpicker
    hypridle
    xdg-desktop-portal-hyprland
    hyprsunset
    waylock
    wl-clipboard-manager
    hyprland
    wlogout
    hyprpolkitagent
    nerd-fonts-complete
    sudocompletion
)

echo "Installing AUR packages..."
yay -S --needed --noconfirm "${aur_packages[@]}"

# Step 3: Enable required systemctl services
echo "Enabling required systemctl services..."
sudo systemctl enable sddm
sudo systemctl enable NetworkManager
sudo systemctl enable tlp
sudo systemctl enable bluetooth
sudo systemctl enable seatd

# Add current user to the 'seat' group
sudo usermod -aG seat "$USER"
echo "Added $USER to 'seat' group. Please log out and log back in for group changes to take effect."

echo "Installation and setup complete."
