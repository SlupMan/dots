#!/bin/bash

# Function to install yay
install_yay() {
    if ! command -v yay &> /dev/null
    then
        echo "Installing yay..."
        sudo pacman -S --needed git base-devel --noconfirm
        git clone https://aur.archlinux.org/yay.git || { echo "Failed to clone yay"; exit 1; }
        cd yay || exit 1
        makepkg -si --noconfirm || { echo "Failed to install yay"; exit 1; }
        cd ..
        rm -rf yay
    else
        echo "yay is already installed."
    fi
}

# Function to install packages in groups
install_packages_group() {
    local step=$1
    local packages=("${!2}")
    echo "Installing group $step: ${packages[*]}"
    sudo pacman -S --needed --noconfirm "${packages[@]}" || { echo "Failed to install group $step"; exit 1; }
    echo "[$step out of 12] completed."
}

install_aur_group() {
    local step=$1
    local packages=("${!2}")
    echo "Installing AUR group $step: ${packages[*]}"
    yay -S --needed --noconfirm "${packages[@]}" || { echo "Failed to install AUR group $step"; exit 1; }
    echo "[$step out of 12] completed."
}

# Step 1: Install yay
install_yay

# Pacman packages groups
pacman_group_1=(mako pipewire wireplumber pipewire-pulse xdg-desktop-portal-gtk xdg-desktop-portal)
pacman_group_2=(waybar wofi sddm nm-applet wlroots alacritty)
pacman_group_3=(thunar neovim mesa libxcb xorg-xwayland grim slurp)
pacman_group_4=(networkmanager pavucontrol brightnessctl archlinux-keyring xdg-utils xdg-user-dirs libinput)
pacman_group_5=(polkit xsettingsd ttf-dejavu ttf-liberation noto-fonts-emoji gvfs seatd)
pacman_group_6=(fuse3 bluez bluez-utils blueman xf86-input-libinput tlp tlp-rdw lm_sensors)
pacman_group_7=(ntfs-3g exfatprogs dosfstools bash-completion htop wget git gtk3 gtk4)

# Installing Pacman packages in groups
install_packages_group 1 pacman_group_1[@]
install_packages_group 2 pacman_group_2[@]
install_packages_group 3 pacman_group_3[@]
install_packages_group 4 pacman_group_4[@]
install_packages_group 5 pacman_group_5[@]
install_packages_group 6 pacman_group_6[@]
install_packages_group 7 pacman_group_7[@]

# AUR packages groups
aur_group_1=(hyprpaper hyprpicker hypridle xdg-desktop-portal-hyprland)
aur_group_2=(hyprsunset waylock wl-clipboard-manager hyprland wlogout)
aur_group_3=(hyprpolkitagent nerd-fonts-hack)

# Installing AUR packages in groups
install_aur_group 8 aur_group_1[@]
install_aur_group 9 aur_group_2[@]
install_aur_group 10 aur_group_3[@]

# Step 11: Enable required systemctl services
echo "Enabling systemctl services..."
sudo systemctl enable sddm NetworkManager tlp bluetooth seatd || { echo "Failed to enable services"; exit 1; }
echo "[11 out of 12] completed."

# Step 12: Add current user to 'seat' group
echo "Adding $USER to 'seat' group..."
sudo usermod -aG seat "$USER" || { echo "Failed to add user to seat group"; exit 1; }
echo "[12 out of 12] completed."

# Final message
echo "Installation and setup complete. Please log out and log back in for group changes to take effect."
