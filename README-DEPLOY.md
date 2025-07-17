# SneakyHub AI - Docker Deployment Guide

This guide will help you deploy the SneakyHub AI themed Open WebUI on Debian 12.

## Prerequisites

Make sure you have the following installed on your Debian 12 system:

1. **Docker** - Container runtime
2. **Git** - Version control (the script will install it if missing)
3. **Sudo access** - For package installation if needed

## Quick Start

1. **Download the rebuild script** to your Debian 12 system:
   ```bash
   wget https://raw.githubusercontent.com/SneakyHub/open-webui/main/rebuild-docker.sh
   # OR
   curl -O https://raw.githubusercontent.com/SneakyHub/open-webui/main/rebuild-docker.sh
   ```

2. **Make the script executable**:
   ```bash
   chmod +x rebuild-docker.sh
   ```

3. **Run the script**:
   ```bash
   ./rebuild-docker.sh
   ```

## What the Script Does

The script performs the following steps automatically:

1. **Pre-flight checks**: Verifies Docker and Git are installed
2. **Cleanup**: Stops and removes any existing container and image
3. **Update**: Clones the latest code from your GitHub repository
4. **Build**: Creates a new Docker image with your SneakyHub AI theme
5. **Deploy**: Starts a new container with the updated code
6. **Status**: Shows container status and access information

## Script Options

- `./rebuild-docker.sh --help` - Show help message
- `./rebuild-docker.sh --logs` - Follow container logs after rebuild
- `./rebuild-docker.sh --no-cleanup` - Keep build directory after completion

## Manual Docker Installation (if needed)

If Docker isn't installed on your system:

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

## Configuration

The script uses these default settings (matching your current setup):

- **Container name**: `open-webui`
- **Image name**: `sneakyhub-ai`
- **Port**: `8081` (using host network mode)
- **Ollama URL**: `http://127.0.0.1:11435`
- **Data volume**: `open-webui` (persistent storage)
- **Network mode**: `host` (direct host network access)
- **Restart policy**: `always`
- **GitHub repo**: `https://github.com/SneakyHub/open-webui.git`

You can modify these values at the top of the script if needed.

## Accessing Your SneakyHub AI

After the script completes successfully:

1. **Open your browser** and go to: `http://localhost:8081`
2. **Create an admin account** on first visit
3. **Your Ollama models** should be automatically detected from `http://127.0.0.1:11435`
4. **Configure additional AI models** in the settings if needed

## Useful Commands

After deployment, you can use these Docker commands:

```bash
# View container logs
docker logs -f open-webui

# Stop the container
docker stop open-webui

# Start the container
docker start open-webui

# Restart the container
docker restart open-webui

# Remove the container (data is preserved in volume)
docker rm open-webui

# View container status
docker ps

# Access container shell (for debugging)
docker exec -it open-webui bash

# Check if Ollama is accessible
curl -s http://127.0.0.1:11435/api/tags

# Test Ollama connection
curl -s http://127.0.0.1:11435/api/version
```

## Troubleshooting

### Permission Denied Error
If you get a permission denied error when running Docker commands:
```bash
sudo usermod -aG docker $USER
# Then log out and log back in
```

### Port Already in Use
If port 8081 is already in use, edit the script and change the `PORT` variable:
```bash
PORT="8080"  # or any other available port
```

### Ollama Connection Issues
If the container can't connect to Ollama:
1. **Check if Ollama is running**: `curl -s http://127.0.0.1:11435/api/version`
2. **Verify Ollama port**: Make sure Ollama is running on port 11435
3. **Check firewall**: Ensure no firewall is blocking port 11435
4. **Host network mode**: The script uses `--network=host` for direct access to Ollama

### Container Won't Start
Check the logs for errors:
```bash
docker logs open-webui
```

### Build Failures
If the Docker build fails:
1. Make sure you have enough disk space
2. Check the error messages in the script output
3. Try running the script again (sometimes network issues cause temporary failures)

## Data Persistence

Your SneakyHub AI data is stored in a Docker volume called `open-webui`. This means:
- **Chats and settings persist** between container rebuilds
- **Models and configurations are preserved**
- **User accounts remain intact**

To backup your data:
```bash
docker run --rm -v open-webui:/data -v $(pwd):/backup alpine tar czf /backup/sneakyhub-backup.tar.gz /data
```

To restore from backup:
```bash
docker run --rm -v open-webui:/data -v $(pwd):/backup alpine tar xzf /backup/sneakyhub-backup.tar.gz -C /
```

## Updating

To update to the latest version, simply run the rebuild script again:
```bash
./rebuild-docker.sh
```

This will pull the latest changes from GitHub and rebuild your container with the new theme updates.

## Support

If you encounter any issues:
1. Check the container logs: `docker logs open-webui`
2. Verify Docker is running: `docker info`
3. Check the GitHub repository for updates
4. Review the script output for error messages

---

**Note**: This script is designed for development and testing. For production deployments, consider using Docker Compose or Kubernetes for better orchestration and monitoring.