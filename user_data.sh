#!/bin/bash
set -e

# ============================================================
# Update packages
# ============================================================
apt-get update -y

# ============================================================
# Install Google Authenticator PAM module
# ============================================================
apt-get install -y libpam-google-authenticator

# ============================================================
# Backup SSH and PAM configuration
# ============================================================
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cp /etc/pam.d/sshd /etc/pam.d/sshd.backup

# ============================================================
# Configure SSH
# ============================================================

# Enable keyboard-interactive authentication
if grep -qE '^[#]?KbdInteractiveAuthentication' /etc/ssh/sshd_config; then
    sed -i 's/^[#]*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
else
    echo 'KbdInteractiveAuthentication yes' >> /etc/ssh/sshd_config
fi

# Enable PAM
if grep -qE '^[#]?UsePAM' /etc/ssh/sshd_config; then
    sed -i 's/^[#]*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
else
    echo 'UsePAM yes' >> /etc/ssh/sshd_config
fi

# Disable normal SSH password authentication
if grep -qE '^[#]?PasswordAuthentication' /etc/ssh/sshd_config; then
    sed -i 's/^[#]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
else
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
fi

# ============================================================
# Configure PAM
# ============================================================

# Remove any existing Google Authenticator entries
sed -i '/pam_google_authenticator\.so/d' /etc/pam.d/sshd

# Add Google Authenticator as the only SSH authentication
# PAM authentication method
sed -i '1i auth required pam_google_authenticator.so' /etc/pam.d/sshd

# IMPORTANT:
# Do NOT include @include common-auth here.
# This prevents SSH from asking for the Linux account password.
sed -i '/^[[:space:]]*@include common-auth[[:space:]]*$/d' /etc/pam.d/sshd

# ============================================================
# Validate SSH configuration
# ============================================================
sshd -t

# ============================================================
# Restart SSH
# ============================================================
systemctl restart ssh

echo "============================================================"
echo "Google Authenticator SSH MFA configured."
echo "PasswordAuthentication: disabled"
echo "KeyboardInteractiveAuthentication: enabled"
echo "PAM: enabled"
echo "Linux password authentication: disabled"
echo "============================================================"
echo ""
echo "IMPORTANT:"
echo "Run 'google-authenticator' as the target user to enroll"
echo "their Google Authenticator secret."