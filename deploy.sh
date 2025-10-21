#!/bin/bash

# ============================================================
# HNG DevOps Stage 1 Task - Automated Deployment Bash Script
# Author: Festus Okagbare
# Fully Idempotent Version: Works with Dockerfile in app/
# ============================================================

set -e  # Exit immediately on error

# --- Absolute script directory and logging setup ---
SCRIPT_DIR=$(pwd)
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy_$(date +%Y%m%d_%H%M%S).log"
log() { echo "$(date +'%F %T') | $1" | tee -a "$LOG_FILE"; }
trap 'log "❌ An unexpected error occurred. Exiting..."; exit 1' ERR

# --- Collect user input ---
read -p "Enter GitHub repo URL: " REPO_URL
read -p "Enter GitHub Personal Access Token: " TOKEN
read -p "Enter branch name [default: main]: " BRANCH
BRANCH=${BRANCH:-main}
read -p "Enter remote SSH username: " REMOTE_USER
read -p "Enter remote server IP: " REMOTE_IP
read -p "Enter SSH private key path: " SSH_KEY
read -p "Enter internal app port (inside container): " APP_PORT

REPO_NAME=$(basename -s .git "$REPO_URL")

# --- Clone or update repo locally ---
if [ -d "$REPO_NAME" ]; then
  log "Repository exists. Pulling latest changes..."
  cd "$REPO_NAME" && git fetch && git pull
else
  log "Cloning repository..."
  git clone -b "$BRANCH" https://oauth2:${TOKEN}@${REPO_URL#https://}
  cd "$REPO_NAME"
fi
cd "$SCRIPT_DIR"

# --- Verify Dockerfile exists inside app/ ---
if [ ! -f "$SCRIPT_DIR/$REPO_NAME/app/Dockerfile" ]; then
  log "❌ No Dockerfile found in $SCRIPT_DIR/$REPO_NAME/app!"
  exit 1
fi

# --- Test SSH connection ---
log "Testing SSH connection..."
ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo SSH_OK" \
  || { log "SSH connection failed"; exit 1; }

# --- Prepare remote environment ---
log "Setting up remote environment..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" <<'REMOTE_CMDS'
sudo apt update -y

# Install rsync if missing
if ! command -v rsync >/dev/null 2>&1; then sudo apt install -y rsync; fi

# Install Nginx if missing
if ! command -v nginx >/dev/null 2>&1; then
    sudo apt install -y nginx
    sudo systemctl enable --now nginx
fi

# Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    sudo systemctl enable --now docker
fi
REMOTE_CMDS

# --- Transfer project files ---
log "Transferring project files..."
rsync -avz -e "ssh -i $SSH_KEY" --exclude '.git' "./$REPO_NAME/" "$REMOTE_USER@$REMOTE_IP:~/$REPO_NAME"

# --- Deploy Docker container ---
log "Deploying Docker container..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" "APP_PORT=$APP_PORT REPO_NAME='$REPO_NAME' bash -s" << 'REMOTE_DEPLOY_SCRIPT'
set -e
echo "Checking remote structure..."
echo "HOME: $HOME"
echo "REPO_NAME: $REPO_NAME"

REMOTE_APP_DIR="$HOME/$REPO_NAME/app"
echo "Looking for app in: $REMOTE_APP_DIR"

if [ ! -d "$REMOTE_APP_DIR" ]; then
    echo "❌ Remote app directory $REMOTE_APP_DIR does not exist!"
    echo "Available directories in $HOME:"
    ls -la "$HOME"
    exit 1
fi

cd "$REMOTE_APP_DIR"

if [ ! -f Dockerfile ]; then
    echo "❌ Dockerfile not found in $REMOTE_APP_DIR"
    echo "Contents of $REMOTE_APP_DIR:"
    ls -la
    exit 1
fi

# Build Docker image
echo "Building Docker image..."
docker build -t hng-app .

# Stop and remove existing container if exists
echo "Stopping and removing existing container..."
if docker ps -q --filter "name=hng-app" | grep -q .; then docker stop hng-app; fi
if docker ps -aq --filter "name=hng-app" | grep -q .; then docker rm hng-app; fi

# Remove dangling images
docker image prune -f

# Run container
echo "Starting container..."
docker run -d --name hng-app -p $APP_PORT:$APP_PORT hng-app
echo "✅ Container deployed successfully!"
REMOTE_DEPLOY_SCRIPT

# --- Configure Nginx reverse proxy ---
log "Configuring Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" "APP_PORT=$APP_PORT" 'bash -s' << 'NGINX_SCRIPT'
sudo tee /etc/nginx/sites-available/hng-app.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/hng-app.conf /etc/nginx/sites-enabled/hng-app.conf
sudo nginx -t && sudo systemctl reload nginx
NGINX_SCRIPT

# --- Validate deployment ---
log "Validating deployment..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" "curl -I http://127.0.0.1 || docker ps"

log "✅ Deployment completed successfully. Visit http://$REMOTE_IP/"
