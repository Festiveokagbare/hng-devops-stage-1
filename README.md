HNG Stage 1 - Automated Deployment Project

Overview

This project demonstrates a fully automated deployment pipeline for a Python web application using Docker, Nginx, and a Bash deployment script. The system is idempotent, handles remote server setup, and provides a reverse-proxied deployment accessible via HTTP.

The project structure is designed for clarity and ease of deployment.

Features
1. Python web application containerized with Docker
2. Fully automated deployment via deploy.sh
3. Idempotent: safe to run multiple times without breaking existing deployments
4. Automatic setup of remote server environment:
    i. Installs Docker if missing
    ii. Installs Nginx and configures reverse proxy
    iii. Installs rsync for file transfer
5. Stops, removes, and rebuilds Docker containers if changes are detected
6. Validates deployment with HTTP check

Project Structure
hng-devops-stage-1/
├── app/
│   ├── Dockerfile        # Container configuration
│   ├── app.py            # Python application entry point
│   └── requirements.txt  # Python dependencies
├── deploy.sh             # Deployment script
├── README.md             # This file
└── logs/                 # Deployment logs generated at runtime


Technologies Used
1. Python 3.11 – Application runtime
2. Docker – Containerization
3. Nginx – Reverse proxy and web server
4. Bash – Deployment automation
5. rsync – Remote file transfer

Prerequisites
1. GitHub repository with app/ folder containing Dockerfile, app.py, and requirements.txt
2. Remote Linux server (Ubuntu recommended)
3. SSH access to the remote server
4. GitHub Personal Access Token (if using private repositories)

Deployment Instructions
1. Clone the repo locally (optional):
    git clone https://github.com/Festiveokagbare/hng-devops-stage-1.git
    cd hng-devops-stage-1


2. Run the deployment script:
   ./deploy.sh


3. You will be prompted for:
        i. GitHub repo URL
        ii. Personal Access Token
        iii. Branch name (default: main)
        iv. Remote SSH username & IP
        v. SSH private key path
        vi. App internal port

4. Access your app:
        Once deployment completes successfully, visit:
            http://<REMOTE_SERVER_IP>/


5. Optional: Fix Nginx default page
    If the default Nginx page appears, remove the default site and reload Nginx:
        ssh -i <SSH_KEY> <USER>@<REMOTE_IP> <<'EOF'
        sudo rm -f /etc/nginx/sites-enabled/default
        sudo ln -sf /etc/nginx/sites-available/hng-app.conf /etc/nginx/sites-enabled/
        sudo nginx -t
        sudo systemctl reload nginx
        EOF

6. Deployment Log
   Every deployment generates a timestamped log file inside logs/ for debugging and audit purposes.

Example:
    logs/deploy_20251021_175826.log

Notes
    1. The script is idempotent: repeated executions will update your app without breaking the existing deployment.
    2. Docker image is automatically cleaned to remove dangling images.
    3. Nginx reverse proxy ensures your app is publicly accessible on port 80.


Author
Festus Okagbare
GitHub: [Festiveokagbare](https://github.com/Festiveokagbare)
LinkedIn: https://www.linkedin.com/in/festus-okagbare/