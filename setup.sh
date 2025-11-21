#!/bin/bash
##
# setup.sh - Initial setup script for Android OTA Patcher
#
# This script helps users set up the Android OTA Patcher environment,
# including container building, directory creation, and key setup guidance.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions for colored output
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

print_header() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          Android OTA Patcher Setup                  ║"
    echo "║      Automated Pixel OTA Scraper & Patcher          ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    info "Checking system requirements..."
    
    local missing_deps=()
    
    # Check for container runtime
    if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("podman or docker")
    fi
    
    # Check for make (optional but recommended)
    if ! command -v make >/dev/null 2>&1; then
        warning "Make not found - you can still use manual commands"
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        success "All required dependencies found"
        
        # Show which container runtime we'll use
        if command -v podman >/dev/null 2>&1; then
            info "Will use podman as container runtime"
        else
            info "Will use docker as container runtime"
        fi
    else
        error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install missing dependencies:"
        echo "  - Fedora/RHEL: sudo dnf install podman make"
        echo "  - Ubuntu/Debian: sudo apt install docker.io make"
        echo "  - Arch Linux: sudo pacman -S podman make"
        exit 1
    fi
}

create_directories() {
    info "Creating directory structure..."
    
    mkdir -p data keys
    
    success "Created directories:"
    echo "  📁 data/ - for downloads and temporary files"
    echo "  🔑 keys/ - for signing keys and certificates"
}

setup_keys_guidance() {
    info "Setting up signing keys..."
    
    if [ -f "keys/avb.key" ] && [ -f "keys/ota.key" ] && [ -f "keys/ota.crt" ]; then
        success "Signing keys found in keys/ directory"
    else
        warning "Signing keys not found"
        echo ""
        echo "You need to provide the following files in the keys/ directory:"
        echo "  🔐 avb.key      - AVB signing private key"
        echo "  🔐 ota.key      - OTA signing private key"
        echo "  📄 ota.crt      - OTA signing certificate" 
        echo "  📱 Magisk-v29.0.apk - Magisk APK (for Magisk patching)"
        echo ""
        echo "Generate keys with:"
        echo "  openssl genrsa -out keys/avb.key 4096"
        echo "  openssl genrsa -out keys/ota.key 4096"
        echo "  openssl req -new -x509 -key keys/ota.key -out keys/ota.crt -days 365"
        echo ""
    fi
}

build_container() {
    info "Building container image..."
    
    if [ -f "./build-container.sh" ]; then
        ./build-container.sh
        success "Container built successfully"
    else
        error "build-container.sh not found"
        exit 1
    fi
}

show_usage_examples() {
    info "Usage examples:"
    echo ""
    
    echo -e "${CYAN}📋 Using Make (recommended):${NC}"
    echo "  make help                    # Show all available commands"
    echo "  make scrape device=cheetah   # Get latest OTA URL for Pixel 7 Pro"
    echo "  make download device=cheetah # Download latest OTA"
    echo "  make ci                      # Run full CI pipeline"
    echo "  make shell                   # Interactive container shell"
    echo ""
    
    echo -e "${CYAN}📋 Using container directly:${NC}"
    if command -v podman >/dev/null 2>&1; then
        local runtime="podman"
    else
        local runtime="docker"
    fi
    
    echo "  $runtime run --rm android-ota-patcher"
    echo "  $runtime run --rm -v ./data:/data android-ota-patcher scrape --device cheetah"
    echo "  $runtime run --rm -v ./data:/data -v ./keys:/workspace/keys android-ota-patcher ci"
    echo ""
    
    echo -e "${CYAN}📋 Using Docker Compose:${NC}"
    echo "  docker-compose up ota-ci     # Run CI pipeline"
    echo "  docker-compose up ota-shell  # Interactive shell"
    echo ""
}

test_container() {
    info "Testing container functionality..."
    
    # Test basic help
    if command -v podman >/dev/null 2>&1; then
        runtime="podman"
    else
        runtime="docker"
    fi
    
    if $runtime run --rm android-ota-patcher >/dev/null 2>&1; then
        success "Container is working correctly"
    else
        error "Container test failed"
        exit 1
    fi
    
    # Test device listing
    info "Testing device configuration..."
    $runtime run --rm android-ota-patcher devices
}

create_sample_config() {
    if [ ! -f ".env" ] && [ -f ".env.sample" ]; then
        info "Creating environment configuration..."
        cp .env.sample .env
        success "Created .env file from template"
        echo "  📝 Edit .env to customize your setup"
    fi
}

print_next_steps() {
    echo ""
    echo -e "${GREEN}🚀 Setup complete! Next steps:${NC}"
    echo ""
    echo "1. 🔑 Add your signing keys to the keys/ directory"
    echo "2. 🔧 Edit .env file to customize configuration (optional)"
    echo "3. 📱 Run your first OTA scrape:"
    echo "   make scrape device=cheetah"
    echo ""
    echo "4. 📥 Download and patch an OTA:"
    echo "   make ci"
    echo ""
    echo "5. 📖 Read README.md for detailed usage instructions"
    echo "6. ❓ Run 'make help' to see all available commands"
    echo ""
}

main() {
    print_header
    
    check_requirements
    create_directories
    setup_keys_guidance
    build_container
    create_sample_config
    test_container
    show_usage_examples
    print_next_steps
    
    success "Android OTA Patcher setup completed successfully!"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Android OTA Patcher Setup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --no-build    Skip container build step"
        echo "  --quick       Skip tests and examples"
        echo ""
        exit 0
        ;;
    "--no-build")
        SKIP_BUILD=1
        ;;
    "--quick")
        QUICK_SETUP=1
        ;;
esac

# Override functions if flags are set
if [ "${SKIP_BUILD:-}" = "1" ]; then
    build_container() {
        info "Skipping container build (--no-build flag)"
    }
fi

if [ "${QUICK_SETUP:-}" = "1" ]; then
    test_container() {
        info "Skipping container test (--quick flag)"
    }
    show_usage_examples() {
        info "Skipping usage examples (--quick flag)"
    }
fi

# Run main setup
main
