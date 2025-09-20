#!/bin/bash

# Variables
MOUNT_POINT="/mnt/mydrive"
UUID="FA8C87BA8C877045"  # Replace with your actual UUID if different
SAMBA_USER="pi"
SHARE_NAME="shared"
SHARE_PATH="$MOUNT_POINT/$SHARE_NAME"

# Update and install samba & cifs-utils
sudo apt update && sudo apt upgrade -y
sudo apt install -y samba cifs-utils ntfs-3g

# Create mount point if it doesn't exist
sudo mkdir -p $MOUNT_POINT

# Backup existing fstab
sudo cp /etc/fstab /etc/fstab.bak

# Add entry to /etc/fstab for NTFS drive
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MOUNT_POINT ntfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

# Mount all drives according to fstab
sudo mount -a

# Create shared directory with permissions
sudo mkdir -p $SHARE_PATH
sudo chmod -R 777 $SHARE_PATH  # Permissive permissions; adjust for security as needed

# Backup Samba configuration
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Write Samba config for share
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
workgroup = WORKGROUP
server string = Raspberry Pi NAS
netbios name = RASPINAS
security = user
map to guest = bad user
dns proxy = no
server min protocol = SMB2
server max protocol = SMB3
client min protocol = SMB2
client max protocol = SMB3
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
read raw = yes
write raw = yes
max xmit = 65535
dead time = 15
getwd cache = yes

[$SHARE_NAME]
path = $SHARE_PATH
valid users = $SAMBA_USER
writeable = yes
browseable = yes
create mask = 0664
directory mask = 0775
force user = $SAMBA_USER
force group = $SAMBA_USER
EOF

# Add samba user (pi) if it doesn't exist as system user, create it
if ! id -u $SAMBA_USER >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" $SAMBA_USER
fi

# Add samba user credentials (will prompt for password)
sudo smbpasswd -a $SAMBA_USER

# Restart Samba service
sudo systemctl restart smbd
sudo systemctl enable smbd

echo "Setup complete. Your NAS should be accessible at '\\\\raspinas\\$SHARE_NAME' or '\\\\<Pi-IP>\\$SHARE_NAME'."
echo "Use username: $SAMBA_USER and the password you just set."
