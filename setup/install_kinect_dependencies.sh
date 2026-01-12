#!/bin/bash
# ABOUTME: Installs Azure Kinect SDK dependencies on Jetson Orin Nano
# ABOUTME: Tests installations, reports progress, and suggests solutions on failure

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

# Error tracking
FAILED_TESTS=()

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${BLUE}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Test if a package is installed
test_package() {
    local package=$1
    if dpkg -l | grep -q "^ii  $package"; then
        return 0
    else
        return 1
    fi
}

# Test if a library file exists
test_library() {
    local lib=$1
    if ldconfig -p | grep -q "$lib"; then
        return 0
    else
        return 1
    fi
}

# Test if a command exists
test_command() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Suggest solutions for common failures
suggest_solution() {
    local component=$1
    echo -e "\n${YELLOW}Suggested solutions for $component:${NC}"

    case $component in
        "apt-update")
            echo "  1. Check your internet connection"
            echo "  2. Try: sudo apt-get clean && sudo apt-get update"
            echo "  3. Check /etc/apt/sources.list for corrupted entries"
            ;;
        "graphics-libs")
            echo "  1. Ensure universe repository is enabled: sudo add-apt-repository universe"
            echo "  2. Try: sudo apt-get update && sudo apt-get install -f"
            echo "  3. Check disk space: df -h"
            ;;
        "ssl")
            echo "  1. Try: sudo apt-get install --reinstall openssl libssl-dev"
            echo "  2. Check if ca-certificates is installed: sudo apt-get install ca-certificates"
            ;;
        "ninja")
            echo "  1. Try alternative installation: sudo pip3 install ninja"
            echo "  2. Or build from source: git clone https://github.com/ninja-build/ninja.git"
            ;;
        "soundio")
            echo "  1. Try: sudo add-apt-repository universe && sudo apt-get update"
            echo "  2. Build from source: https://github.com/andrewrk/libsoundio"
            ;;
        "depthengine")
            echo "  1. Ensure you have write permissions: sudo chmod 755 /lib/aarch64-linux-gnu"
            echo "  2. Verify architecture is arm64: uname -m"
            echo "  3. Check if wget or curl is installed"
            echo "  4. Try manual download from: https://www.nuget.org/packages/Microsoft.Azure.Kinect.Sensor/"
            ;;
        "udev")
            echo "  1. Check directory permissions: ls -la /etc/udev/rules.d/"
            echo "  2. Try: sudo chmod 755 /etc/udev/rules.d"
            echo "  3. Reload udev rules: sudo udevadm control --reload-rules && sudo udevadm trigger"
            ;;
        "microsoft-repo")
            echo "  1. Check your internet connection"
            echo "  2. Verify curl is installed: sudo apt-get install curl"
            echo "  3. Try adding repository manually from: https://packages.microsoft.com"
            echo "  4. Check if GPG key import succeeded"
            ;;
        "k4a-packages")
            echo "  1. Verify Microsoft repository was added correctly: ls /etc/apt/sources.list.d/"
            echo "  2. Try: sudo apt-get update"
            echo "  3. Check available versions: apt-cache search libk4a"
            echo "  4. Try installing specific version: sudo apt-get install libk4a1.4 libk4a1.4-dev k4a-tools"
            ;;
        "sdk-clone")
            echo "  1. Check your internet connection"
            echo "  2. Verify git is installed: sudo apt-get install git"
            echo "  3. Check GitHub accessibility: ping github.com"
            ;;
        "sdk-build")
            echo "  1. Check build logs in the build directory"
            echo "  2. Ensure all dependencies are installed"
            echo "  3. Try: cd build && ninja clean && cmake .. -GNinja && ninja"
            echo "  4. Check for missing development packages"
            ;;
    esac
}

# Main installation flow
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Azure Kinect SDK Dependency Installer${NC}"
echo -e "${BLUE}For Jetson Orin Nano${NC}"
echo -e "${BLUE}================================${NC}"

# Check if running as root for sudo commands
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. This is acceptable but not required."
    SUDO=""
else
    SUDO="sudo"
fi

# Step 1: Update package lists
print_step "Updating package lists"
if $SUDO apt-get update; then
    print_success "Package lists updated"
else
    print_error "Failed to update package lists"
    suggest_solution "apt-update"
    exit 1
fi

# Step 2: Install graphics and display libraries
print_step "Installing graphics and display libraries"
GRAPHICS_PACKAGES="libglu1-mesa-dev freeglut3-dev mesa-common-dev libxinerama-dev libsdl2-dev"
if $SUDO apt-get install -y $GRAPHICS_PACKAGES; then
    print_success "Graphics libraries installed"

    # Test installation
    print_info "Testing graphics library installation..."
    for lib in "libGLU.so" "libglut.so" "libSDL2.so" "libXinerama.so"; do
        if test_library "$lib"; then
            print_success "  $lib found"
        else
            print_warning "  $lib not found in ldconfig cache (may still work)"
            FAILED_TESTS+=("graphics-lib-$lib")
        fi
    done
else
    print_error "Failed to install graphics libraries"
    suggest_solution "graphics-libs"
    exit 1
fi

# Step 3: Install SSL/OpenSSL
print_step "Installing OpenSSL and SSL libraries"
if $SUDO apt-get install -y openssl libssl-dev; then
    print_success "OpenSSL installed"

    # Test installation
    print_info "Testing OpenSSL installation..."
    if test_command "openssl"; then
        print_success "  openssl command available"
        openssl version
    else
        print_error "  openssl command not found"
        FAILED_TESTS+=("openssl-command")
    fi

    if test_library "libssl.so"; then
        print_success "  libssl library found"
    else
        print_warning "  libssl library not found"
        FAILED_TESTS+=("libssl")
    fi
else
    print_error "Failed to install OpenSSL"
    suggest_solution "ssl"
    exit 1
fi

# Step 4: Install Ninja build system
print_step "Installing Ninja build system"
if $SUDO apt-get install -y ninja-build; then
    print_success "Ninja build system installed"

    # Test installation
    print_info "Testing Ninja installation..."
    if test_command "ninja"; then
        print_success "  ninja command available"
        ninja --version
    else
        print_error "  ninja command not found"
        FAILED_TESTS+=("ninja-command")
        suggest_solution "ninja"
    fi
else
    print_error "Failed to install Ninja"
    suggest_solution "ninja"
    exit 1
fi

# Step 5: Install audio support library
print_step "Installing libsoundio"
if $SUDO apt-get install -y libsoundio-dev; then
    print_success "libsoundio installed"

    # Test installation
    print_info "Testing libsoundio installation..."
    if test_library "libsoundio.so"; then
        print_success "  libsoundio library found"
    else
        print_warning "  libsoundio library not found"
        FAILED_TESTS+=("libsoundio")
    fi
else
    print_error "Failed to install libsoundio"
    suggest_solution "soundio"
    exit 1
fi

# Step 6: Add Microsoft package repository
print_step "Adding Microsoft package repository for ARM64"
print_info "Configuring Microsoft apt repository..."

# Install prerequisites
if ! $SUDO apt-get install -y curl gpg; then
    print_error "Failed to install curl and gpg"
    suggest_solution "microsoft-repo"
    exit 1
fi

# Get Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
print_info "Detected Ubuntu version: $UBUNTU_VERSION"

# Check if repository already exists
REPO_CONFIGURED=false
if [ -f "/etc/apt/sources.list.d/microsoft-prod.list" ]; then
    print_success "Microsoft repository already configured"
    REPO_CONFIGURED=true
else
    # Add Microsoft GPG key
    print_info "Adding Microsoft GPG key..."
    if curl -sSL https://packages.microsoft.com/keys/microsoft.asc | $SUDO gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg; then
        print_success "Microsoft GPG key added"
    else
        print_error "Failed to add Microsoft GPG key"
        suggest_solution "microsoft-repo"
        exit 1
    fi

    # Add Microsoft repository for ARM64 with allow-insecure option
    # The Microsoft repo doesn't have a Release file, so we need to bypass the check
    print_info "Adding Microsoft ARM64 repository (with allow-insecure for missing Release file)..."
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/microsoft-prod.gpg allow-insecure=yes] https://packages.microsoft.com/ubuntu/${UBUNTU_VERSION}/multiarch/prod ${UBUNTU_VERSION} main" | $SUDO tee /etc/apt/sources.list.d/microsoft-prod.list > /dev/null
    print_success "Microsoft repository added"
fi

# Always update package lists after repository configuration
print_info "Updating package lists with Microsoft repository..."
if $SUDO apt-get update; then
    print_success "Package lists updated"
else
    print_warning "Update completed with warnings (this may be normal for Microsoft repo)"
fi

# Step 7: Install Azure Kinect SDK packages
print_step "Installing Azure Kinect SDK packages"
print_info "Installing libk4a runtime, development files, and tools..."

K4A_PACKAGES="libk4a1.4 libk4a1.4-dev k4a-tools"
if $SUDO apt-get install -y --allow-unauthenticated $K4A_PACKAGES; then
    print_success "Azure Kinect packages installed"

    # Test installation
    print_info "Testing Azure Kinect package installation..."
    if test_package "libk4a1.4"; then
        print_success "  libk4a1.4 runtime package installed"
    else
        print_warning "  libk4a1.4 package not confirmed"
        FAILED_TESTS+=("libk4a-runtime")
    fi

    if test_package "k4a-tools"; then
        print_success "  k4a-tools package installed"
    else
        print_warning "  k4a-tools package not confirmed"
        FAILED_TESTS+=("k4a-tools")
    fi

    if test_command "k4aviewer"; then
        print_success "  k4aviewer command available"
    else
        print_warning "  k4aviewer command not found in PATH"
        FAILED_TESTS+=("k4aviewer-command")
    fi
else
    print_error "Failed to install Azure Kinect packages"
    suggest_solution "k4a-packages"
    exit 1
fi

# Step 8: Verify depth engine library
print_step "Verifying depth engine library"
print_info "The depth engine library should be included in the libk4a package..."

DEPTHENGINE_PATH="/usr/lib/aarch64-linux-gnu/libdepthengine.so.2.0"
ALT_DEPTHENGINE_PATH="/lib/aarch64-linux-gnu/libdepthengine.so.2.0"

if [ -f "$DEPTHENGINE_PATH" ] || [ -f "$ALT_DEPTHENGINE_PATH" ]; then
    print_success "Depth engine library found"
    if [ -f "$DEPTHENGINE_PATH" ]; then
        print_info "  Location: $DEPTHENGINE_PATH"
    else
        print_info "  Location: $ALT_DEPTHENGINE_PATH"
    fi
else
    print_warning "Depth engine library not found at expected locations"
    print_info "Checking if it's accessible via ldconfig..."
    if test_library "libdepthengine.so"; then
        print_success "  libdepthengine.so found in library path"
    else
        print_warning "  libdepthengine.so not found"
        print_info "This may be included in a different location by the package manager."
        FAILED_TESTS+=("depthengine-location")
    fi
fi

# Update library cache
print_info "Updating library cache..."
$SUDO ldconfig
print_success "Library cache updated"

# Step 9: Clone Azure Kinect SDK source (for samples and additional tools)
print_step "Cloning Azure Kinect SDK source repository"
SDK_DIR="Azure-Kinect-Sensor-SDK"

if [ -d "$SDK_DIR" ]; then
    print_success "SDK repository already exists at $SDK_DIR"
else
    print_info "Cloning SDK repository from GitHub..."
    if git clone --depth 1 https://github.com/microsoft/Azure-Kinect-Sensor-SDK.git; then
        print_success "SDK repository cloned"
    else
        print_error "Failed to clone SDK repository"
        suggest_solution "sdk-clone"
        FAILED_TESTS+=("sdk-clone")
    fi
fi

# Step 10: Configure udev rules for device access
print_step "Configuring udev rules for Kinect device access"

if [ -d "$SDK_DIR" ]; then
    UDEV_SOURCE="$SDK_DIR/scripts/99-k4a.rules"
    if [ -f "$UDEV_SOURCE" ]; then
        print_info "Found udev rules file in SDK repository"
        if $SUDO cp "$UDEV_SOURCE" /etc/udev/rules.d/; then
            print_success "Udev rules installed to /etc/udev/rules.d/"
            $SUDO udevadm control --reload-rules
            $SUDO udevadm trigger
            print_success "Udev rules reloaded"
        else
            print_error "Failed to copy udev rules"
            FAILED_TESTS+=("udev-copy")
        fi
    else
        print_warning "Udev rules file not found at $UDEV_SOURCE"
        FAILED_TESTS+=("udev-missing")
    fi
else
    print_warning "SDK repository not available, skipping udev rules setup"
    print_info "You can manually copy udev rules later from the SDK repository"
    FAILED_TESTS+=("udev-sdk-not-available")
fi

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Installation Summary${NC}"
echo -e "${BLUE}================================${NC}"

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    print_success "All dependency checks passed!"
    echo -e "\n${GREEN}Azure Kinect SDK is ready to use!${NC}"
    echo ""
    echo "To test your installation:"
    echo "  1. Connect your Azure Kinect device via USB"
    echo "  2. Run: k4aviewer"
    echo ""
    echo "To use the SDK in your own projects:"
    echo "  - Runtime library: libk4a is installed and ready"
    echo "  - Development headers: Available in /usr/include/k4a/"
    echo "  - CMake integration: Use find_package(k4a) in your CMakeLists.txt"
    echo ""
    echo "SDK source code and examples are available in: $SDK_DIR"
else
    print_warning "Installation completed with ${#FAILED_TESTS[@]} warning(s)/issue(s):"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done

    echo -e "\n${YELLOW}Suggested actions:${NC}"
    if [[ " ${FAILED_TESTS[@]} " =~ "depthengine" ]]; then
        suggest_solution "depthengine"
    fi
    if [[ " ${FAILED_TESTS[@]} " =~ "udev" ]]; then
        suggest_solution "udev"
    fi
    if [[ " ${FAILED_TESTS[@]} " =~ "k4a" ]]; then
        suggest_solution "k4a-packages"
    fi
    if [[ " ${FAILED_TESTS[@]} " =~ "sdk" ]]; then
        suggest_solution "sdk-clone"
    fi

    echo -e "\n${YELLOW}Despite these warnings, the SDK may still be functional.${NC}"
    echo "Try running: k4aviewer (after connecting your device)"
fi

echo -e "\n${BLUE}Installation log completed at $(date)${NC}"
