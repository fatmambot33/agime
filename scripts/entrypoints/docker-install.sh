#!/bin/bash
# -------------------------------------------------------------
# One-shot Docker & Docker Compose installer for Ubuntu via SSH
# User: Your normal user with sudo privileges
# After this, Docker can be used WITHOUT sudo
# -------------------------------------------------------------

set -e
set -u

echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing required dependencies ==="
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "=== Setting up Docker GPG key and repository ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Updating package index for Docker repo ==="
sudo apt update

echo "=== Installing Docker Engine, CLI, Buildx, containerd, and Compose plugin ==="
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Adding current user to Docker group ==="
sudo usermod -aG docker $USER

echo "=== Enabling Docker to start on boot ==="
sudo systemctl enable docker
sudo systemctl start docker

echo
echo "✅ Docker installation complete!"

echo "=== Testing Docker (requires sudo if group changes not applied yet) ==="
if ! docker run --rm hello-world &>/dev/null; then
    echo "⚠ You need to log out and log back in for Docker group changes to take effect."
    echo "Running test with sudo..."
    sudo docker run --rm hello-world
else
    echo "✅ Docker ran hello-world successfully without sudo!"
fi

echo
echo "Now you can run Docker and docker-compose without sudo in this SSH session"
echo "after reconnecting or logging out & back in."