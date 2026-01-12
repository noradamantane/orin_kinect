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
TOTAL_STEPS=7
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
            echo "  1. Ensure you have write permissions: sudo chmod a+rwx /lib/aarch64-linux-gnu"
            echo "  2. Verify architecture is arm64: uname -m"
            echo "  3. Download manually from: https://www.nuget.org/packages/Microsoft.Azure.Kinect.Sensor/"
            echo "  4. Extract libdepthengine.so.2.0 from linux/lib/native/arm64/release/"
            ;;
        "udev")
            echo "  1. Check directory permissions: ls -la /etc/udev/rules.d/"
            echo "  2. Try: sudo chmod 755 /etc/udev/rules.d"
            echo "  3. Reload udev rules: sudo udevadm control --reload-rules && sudo udevadm trigger"
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

# Step 6: Install depth engine library (critical manual step)
print_step "Configuring depth engine library"
print_info "The depth engine library (libdepthengine.so.2.0) must be manually installed."
print_info "Checking for existing installation..."

DEPTHENGINE_PATH="/lib/aarch64-linux-gnu/libdepthengine.so.2.0"
if [ -f "$DEPTHENGINE_PATH" ]; then
    print_success "Depth engine library already installed at $DEPTHENGINE_PATH"
else
    print_warning "Depth engine library NOT found at $DEPTHENGINE_PATH"
    print_info "This library is REQUIRED for Azure Kinect SDK to function."
    echo ""
    echo -e "${YELLOW}Manual installation steps:${NC}"
    echo "  1. Download Microsoft.Azure.Kinect.Sensor NuGet package (v1.4.0-alpha.4 or later)"
    echo "     URL: https://www.nuget.org/packages/Microsoft.Azure.Kinect.Sensor/"
    echo "  2. Extract the .nupkg file (it's a zip archive)"
    echo "  3. Navigate to: linux/lib/native/arm64/release/"
    echo "  4. Copy libdepthengine.so.2.0 to /lib/aarch64-linux-gnu/"
    echo "     Command: sudo cp libdepthengine.so.2.0 /lib/aarch64-linux-gnu/"
    echo "  5. Set permissions: sudo chmod 755 /lib/aarch64-linux-gnu/libdepthengine.so.2.0"
    echo "  6. Update library cache: sudo ldconfig"
    echo ""
    FAILED_TESTS+=("depthengine")
fi

# Ensure the target directory has appropriate permissions
if [ -d "/lib/aarch64-linux-gnu" ]; then
    print_info "Ensuring /lib/aarch64-linux-gnu is accessible..."
    $SUDO chmod 755 /lib/aarch64-linux-gnu 2>/dev/null || print_warning "Could not modify directory permissions"
fi

# Step 7: Configure udev rules for device access
print_step "Configuring udev rules for Kinect device access"
print_info "Checking for Azure Kinect SDK repository..."

# Check if the SDK repository exists
if [ -d "Azure-Kinect-Sensor-SDK" ]; then
    UDEV_SOURCE="Azure-Kinect-Sensor-SDK/scripts/99-k4a.rules"
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
    print_warning "Azure Kinect SDK repository not found in current directory"
    print_info "You'll need to configure udev rules after cloning the SDK repository:"
    echo "  1. Clone the SDK: git clone https://github.com/microsoft/Azure-Kinect-Sensor-SDK.git"
    echo "  2. Copy rules: sudo cp Azure-Kinect-Sensor-SDK/scripts/99-k4a.rules /etc/udev/rules.d/"
    echo "  3. Reload rules: sudo udevadm control --reload-rules && sudo udevadm trigger"
    FAILED_TESTS+=("udev-sdk-not-cloned")
fi

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Installation Summary${NC}"
echo -e "${BLUE}================================${NC}"

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    print_success "All dependency checks passed!"
    echo -e "\n${GREEN}Next steps:${NC}"
    echo "  1. Clone Azure Kinect SDK: git clone https://github.com/microsoft/Azure-Kinect-Sensor-SDK.git"
    echo "  2. Build the SDK:"
    echo "     cd Azure-Kinect-Sensor-SDK"
    echo "     mkdir build && cd build"
    echo "     cmake .. -GNinja"
    echo "     ninja"
    echo "  3. Connect your Azure Kinect device"
    echo "  4. Test with: ./bin/k4aviewer"
else
    print_warning "Installation completed with ${#FAILED_TESTS[@]} warning(s)/issue(s):"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done

    echo -e "\n${YELLOW}Action required:${NC}"
    if [[ " ${FAILED_TESTS[@]} " =~ "depthengine" ]]; then
        suggest_solution "depthengine"
    fi
    if [[ " ${FAILED_TESTS[@]} " =~ "udev" ]]; then
        suggest_solution "udev"
    fi
fi

echo -e "\n${BLUE}Installation log completed at $(date)${NC}"
