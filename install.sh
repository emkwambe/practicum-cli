#!/bin/bash
# Practicum CLI — One-line Installer
# Usage: curl -sL https://raw.githubusercontent.com/emkwambe/practicum-cli/main/install.sh | bash

set -e

REPO="https://github.com/emkwambe/practicum-cli.git"
INSTALL_DIR="$HOME/practicum-cli"
BIN_DIR="$HOME/.local/bin"

echo ""
echo "  🚀 Installing Practicum CLI..."
echo ""

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
    echo "  Updating existing installation..."
    cd "$INSTALL_DIR" && git pull origin main
else
    echo "  Cloning repository..."
    git clone "$REPO" "$INSTALL_DIR"
fi

# Make scripts executable
chmod +x "$INSTALL_DIR/practicum" "$INSTALL_DIR/lib/"*.sh

# Create bin directory and wrapper
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/practicum" << WRAPPER
#!/bin/bash
exec "$INSTALL_DIR/practicum" "\$@"
WRAPPER
chmod +x "$BIN_DIR/practicum"

# Add to PATH if needed
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    SHELL_RC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"
    echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_RC"
    echo "  Added $BIN_DIR to PATH in $(basename $SHELL_RC)"
    export PATH="$PATH:$BIN_DIR"
fi

echo ""
echo "  ✅ Practicum CLI installed!"
echo "  Run: practicum --help"
echo ""
