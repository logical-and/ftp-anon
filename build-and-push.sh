#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="andspace/ftp-anon"
TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

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

# Check if Docker is running
print_status "Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running. Please start Docker and try again."
    exit 1
fi
print_success "Docker daemon is running"

# Check if we're in the right directory (look for Dockerfile)
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found in current directory. Please run this script from the project root."
    exit 1
fi

# Build the Docker image
print_status "Building Docker image: ${FULL_IMAGE_NAME}"
if docker build -t "${FULL_IMAGE_NAME}" .; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Check if user is logged in to Docker Hub
print_status "Checking Docker Hub authentication..."
if ! docker info | grep -q "Username:"; then
    print_warning "Not logged in to Docker Hub. Attempting to log in..."
    print_status "Please enter your Docker Hub credentials:"
    if ! docker login; then
        print_error "Failed to log in to Docker Hub"
        exit 1
    fi
fi

# Push the image to Docker Hub
print_status "Pushing image to Docker Hub: ${FULL_IMAGE_NAME}"
if docker push "${FULL_IMAGE_NAME}"; then
    print_success "Image pushed successfully to Docker Hub"
else
    print_error "Failed to push image to Docker Hub"
    exit 1
fi

# Display final information
print_success "Build and push completed successfully!"
echo
print_status "Image details:"
echo "  Repository: ${IMAGE_NAME}"
echo "  Tag: ${TAG}"
echo "  Full name: ${FULL_IMAGE_NAME}"
echo
print_status "To pull this image:"
echo "  docker pull ${FULL_IMAGE_NAME}"
echo
print_status "To run this image:"
echo "  docker run -d -p 21:21 -p 30000-30100:30000-30100 ${FULL_IMAGE_NAME}" 