#!/bin/bash

# SneakyHub AI - Open WebUI Docker Rebuild Script
# This script pulls the latest changes from GitHub and rebuilds the Docker container

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="open-webui"
IMAGE_NAME="sneakyhub-open-webui"
GITHUB_REPO="https://github.com/SneakyHub/open-webui.git"
BUILD_DIR="/tmp/open-webui-build"
PORT="3000"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Consider using a non-root user with Docker permissions."
    fi
}

# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "Docker is installed and running"
}

# Function to check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Installing git..."
        sudo apt-get update && sudo apt-get install -y git
    fi
    
    print_success "Git is available"
}

# Function to stop and remove existing container
cleanup_container() {
    print_status "Checking for existing container..."
    
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        print_status "Stopping existing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        
        print_status "Removing existing container..."
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        
        print_success "Existing container removed"
    else
        print_status "No existing container found"
    fi
}

# Function to remove existing image
cleanup_image() {
    print_status "Checking for existing image..."
    
    if docker images | grep -q "$IMAGE_NAME"; then
        print_status "Removing existing image..."
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        print_success "Existing image removed"
    else
        print_status "No existing image found"
    fi
}

# Function to clone/update repository
update_repository() {
    print_status "Preparing build directory..."
    
    # Clean up build directory
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$BUILD_DIR"
    
    print_status "Cloning latest code from GitHub..."
    git clone "$GITHUB_REPO" "$BUILD_DIR"
    
    cd "$BUILD_DIR"
    
    print_success "Repository cloned successfully"
    print_status "Latest commit: $(git log --oneline -1)"
}

# Function to build Docker image
build_image() {
    print_status "Building Docker image..."
    
    cd "$BUILD_DIR"
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in repository"
        exit 1
    fi
    
    # Build the image
    docker build -t "$IMAGE_NAME" .
    
    print_success "Docker image built successfully"
}

# Function to run the container
run_container() {
    print_status "Starting new container..."
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT:8080" \
        -v open-webui:/app/backend/data \
        --restart unless-stopped \
        "$IMAGE_NAME"
    
    print_success "Container started successfully"
    print_status "Container is running on port $PORT"
    print_status "You can access SneakyHub AI at: http://localhost:$PORT"
}

# Function to show container status
show_status() {
    print_status "Container status:"
    docker ps | grep "$CONTAINER_NAME" || print_warning "Container not found in running processes"
    
    print_status "Recent container logs:"
    docker logs --tail 10 "$CONTAINER_NAME" 2>/dev/null || print_warning "Could not retrieve logs"
}

# Function to cleanup build directory
cleanup_build() {
    print_status "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
    print_success "Build directory cleaned up"
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  SneakyHub AI - Docker Rebuild Script${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    # Pre-flight checks
    check_root
    check_docker
    check_git
    
    echo
    print_status "Starting rebuild process..."
    echo
    
    # Cleanup existing container and image
    cleanup_container
    cleanup_image
    
    # Update repository
    update_repository
    
    # Build new image
    build_image
    
    # Run new container
    run_container
    
    # Show status
    echo
    show_status
    
    # Cleanup
    cleanup_build
    
    echo
    print_success "Rebuild completed successfully!"
    echo -e "${GREEN}Your SneakyHub AI instance is now running with the latest changes.${NC}"
    echo -e "${BLUE}Access it at: http://localhost:$PORT${NC}"
    echo
    
    # Optional: Show useful commands
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  View logs: docker logs -f $CONTAINER_NAME"
    echo "  Stop container: docker stop $CONTAINER_NAME"
    echo "  Restart container: docker restart $CONTAINER_NAME"
    echo "  Remove container: docker rm $CONTAINER_NAME"
    echo
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "SneakyHub AI Docker Rebuild Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --logs, -l     Show container logs after rebuild"
        echo "  --no-cleanup   Don't remove build directory after completion"
        echo
        echo "This script will:"
        echo "  1. Stop and remove existing container"
        echo "  2. Remove existing Docker image"
        echo "  3. Clone latest code from GitHub"
        echo "  4. Build new Docker image"
        echo "  5. Start new container"
        echo
        exit 0
        ;;
    --logs|-l)
        main
        echo
        print_status "Following container logs (Ctrl+C to exit)..."
        docker logs -f "$CONTAINER_NAME"
        ;;
    --no-cleanup)
        # Modify cleanup function to skip cleanup
        cleanup_build() {
            print_status "Skipping build directory cleanup (--no-cleanup flag used)"
            print_status "Build directory: $BUILD_DIR"
        }
        main
        ;;
    *)
        main
        ;;
esac