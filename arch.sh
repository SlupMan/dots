#!/bin/bash
# --- Partitioning & Filesystem ---
DISK="/dev/nvme0n1"
SWAP_SIZE="16GiB"

# Partition disk (UEFI + Single Btrfs partition + Swap)
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart "EFI" fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart "swap" linux-swap 513MiB "$SWAP_SIZE"
parted -s "$DISK" mkpart "root" btrfs "$SWAP_SIZE" 100%

# Format partitions
mkfs.fat -F32 "${DISK}p1"
mkswap "${DISK}p2"
mkfs.btrfs -f "${DISK}p3"

# Mount Btrfs and create subvolumes
mount "${DISK}p3" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@dev_env
umount /mnt

# Mount partitions with subvolumes
mount -o noatime,compress=zstd,subvol=@ "${DISK}p3" /mnt
mkdir -p /mnt/{home,var/lib/libvirt/images,boot/efi}
mount -o noatime,compress=zstd,subvol=@home "${DISK}p3" /mnt/home
mount -o noatime,compress=zstd,subvol=@dev_env "${DISK}p3" /mnt/var/lib/libvirt/images
mount "${DISK}p1" /mnt/boot/efi
swapon "${DISK}p2"

# --- Base System ---
pacstrap /mnt base linux linux-firmware intel-ucode btrfs-progs

# --- Bootloader (GRUB) ---
arch-chroot /mnt pacman -S grub efibootmgr os-prober --noconfirm
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# --- Host Configuration ---
echo "archlap" > /mnt/etc/hostname
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=de-latin1-nodeadkeys" > /mnt/etc/vconsole.conf
arch-chroot /mnt locale-gen

# --- Users ---
arch-chroot /mnt useradd -m -G wheel -s /bin/bash slup
echo "root:a1912" | arch-chroot /mnt chpasswd
echo "slup:1912" | arch-chroot /mnt chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

# --- Network & Services ---
arch-chroot /mnt pacman -S networkmanager openssh --noconfirm
arch-chroot /mnt systemctl enable NetworkManager sshd

# --- GUI & Applications ---
arch-chroot /mnt pacman -S xorg plasma kde-applications sddm firefox git --noconfirm
arch-chroot /mnt systemctl enable sddm

# --- NVIDIA Drivers (RTX 4050) ---
arch-chroot /mnt pacman -S nvidia nvidia-utils nvidia-settings --noconfirm
echo "blacklist nouveau" >> /mnt/etc/modprobe.d/blacklist.conf

# --- Custom Packages ---
arch-chroot /mnt pacman -S ufw yay qemu libvirt virt-manager tailscale tlp --noconfirm

# --- YAY Installation (AUR Helper) ---
arch-chroot /mnt pacman -S --needed git base-devel --noconfirm
arch-chroot /mnt git clone https://aur.archlinux.org/yay.git /tmp/yay
arch-chroot /mnt bash -c "cd /tmp/yay && makepkg -si --noconfirm"

# --- Post-Install Commands ---
arch-chroot /mnt /bin/bash <<EOF
# Firewall setup
ufw default deny
ufw allow SSH
ufw enable

# KVM Configuration
usermod -aG libvirt slup
systemctl enable libvirtd

# Tailscale & Power Management
systemctl enable tailscaled
systemctl enable tlp

# Initialize initramfs
mkinitcpio -P
EOF

# --- Optional Suggestions ---
echo "Consider these post-install steps:"
echo "1. Configure 1Password: install from AUR and set up browser integration"
echo "2. Enable TRIM: systemctl enable fstrim.timer"
echo "3. Configure KVM: edit /etc/libvirt/libvirtd.conf for permissions"
echo "4. Install additional HP Victus firmware: linux-firmware iwd bluez"