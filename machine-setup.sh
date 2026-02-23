#!/bin/bash
#
# CPOS — First-time machine setup
#
# Installs all tools required before running the developer onboarding script.
# Safe to run multiple times — already-installed tools are skipped.
#
# Usage:
#   bash scripts/machine-setup.sh
#

set -uo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
skip() { echo -e "  ${BLUE}–${RESET}  ${DIM}$1${RESET}"; }
step() { echo -e "\n${BOLD}$1${RESET}"; }
warn() { echo -e "  ${YELLOW}!${RESET}  $1"; }
die()  { echo -e "\n  ✗  $1\n"; exit 1; }

echo ""
echo -e "${BOLD}  CPOS Hub — Machine Setup${RESET}"
echo -e "  ${DIM}Sets up a clean macOS machine for development.${RESET}"
echo ""

# ── Step 1: Xcode Command Line Tools ─────────────────────────────────────────
step "1/9  Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  skip "Already installed at $(xcode-select -p)"
else
  warn "Not installed. Triggering install — follow the prompt that appears."
  xcode-select --install 2>/dev/null || true
  echo ""
  read -rp "  Press Enter once the Xcode tools installer has finished... "
  xcode-select -p &>/dev/null || die "Xcode Command Line Tools still not found. Please complete the installer and re-run."
  ok "Installed"
fi

# ── Step 2: Homebrew ──────────────────────────────────────────────────────────
step "2/9  Homebrew"

if command -v brew &>/dev/null; then
  skip "Already installed ($(brew --version | head -1))"
else
  warn "Not installed. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew installation failed."

  # Load brew into the current shell session
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  ok "Installed — open a new terminal window if 'brew' is not found in future sessions"
fi

# Ensure brew is in PATH for the rest of this script
if ! command -v brew &>/dev/null; then
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "brew not found. Try opening a new terminal and re-running this script."
  fi
fi

# ── Step 3: nvm ───────────────────────────────────────────────────────────────
step "3/9  nvm"

if [ -d "$HOME/.nvm" ]; then
  skip "Already installed (~/.nvm exists)"
else
  brew install nvm || die "Failed to install nvm."
  ok "Installed"
fi

# Add nvm config to ~/.zshrc if not already present
NVM_CONFIG=$(cat <<'EOF'

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
EOF
)

if grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null; then
  skip "~/.zshrc already configured for nvm"
else
  echo "$NVM_CONFIG" >> "$HOME/.zshrc"
  ok "Added nvm config to ~/.zshrc"
fi

# Load nvm into the current shell session
export NVM_DIR="$HOME/.nvm"
BREW_PREFIX="$(brew --prefix)"
[ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ] && source "$BREW_PREFIX/opt/nvm/nvm.sh"

command -v nvm &>/dev/null || die "nvm loaded but 'nvm' command not found. Try opening a new terminal and re-running."

# ── Step 4: Node.js v22 ───────────────────────────────────────────────────────
step "4/9  Node.js v22"

CURRENT_NODE=$(node --version 2>/dev/null || echo "none")
NODE_MAJOR=$(echo "$CURRENT_NODE" | sed 's/v//' | cut -d. -f1)

if [ "$NODE_MAJOR" = "22" ]; then
  skip "Already on $CURRENT_NODE"
else
  if [ "$CURRENT_NODE" != "none" ]; then
    warn "Found $CURRENT_NODE — v22.x required. Installing v22..."
  fi
  nvm install 22 || die "Failed to install Node.js v22."
  nvm use 22
  ok "$(node --version)"
fi

# ── Step 5: pnpm ─────────────────────────────────────────────────────────────
step "5/9  pnpm"

if command -v pnpm &>/dev/null; then
  skip "Already installed ($(pnpm --version))"
else
  corepack enable pnpm || die "Failed to enable pnpm via Corepack."
  ok "$(pnpm --version)"
fi

# ── Step 6: AWS CLI v2 ────────────────────────────────────────────────────────
step "6/9  AWS CLI v2"

AWS_VERSION=$(aws --version 2>&1 || echo "none")
if echo "$AWS_VERSION" | grep -q 'aws-cli/2'; then
  skip "Already installed ($(echo "$AWS_VERSION" | cut -d' ' -f1))"
elif echo "$AWS_VERSION" | grep -q 'aws-cli/1'; then
  warn "AWS CLI v1 found — v2 is required. Installing v2 via Homebrew..."
  brew install awscli || die "Failed to install AWS CLI v2."
  ok "$(aws --version | cut -d' ' -f1)"
else
  brew install awscli || die "Failed to install AWS CLI v2."
  ok "$(aws --version | cut -d' ' -f1)"
fi

# ── Step 7: Stripe CLI ────────────────────────────────────────────────────────
step "7/9  Stripe CLI"

if command -v stripe &>/dev/null; then
  skip "Already installed ($(stripe --version))"
else
  brew install stripe/stripe-cli/stripe || die "Failed to install Stripe CLI."
  ok "$(stripe --version)"
fi

# ── Step 8: GitHub CLI ────────────────────────────────────────────────────────
step "8/9  GitHub CLI"

if command -v gh &>/dev/null; then
  skip "Already installed ($(gh --version | head -1))"
else
  brew install gh || die "Failed to install GitHub CLI."
  ok "$(gh --version | head -1)"
fi

# Authenticate if not already logged in
if gh auth status &>/dev/null; then
  skip "Already authenticated ($(gh auth status 2>&1 | grep 'Logged in' | xargs))"
else
  warn "Not authenticated. Running 'gh auth login' — a browser window will open."
  echo ""
  gh auth login || die "GitHub authentication failed."
  ok "Authenticated"
fi

# ── Step 9: Clone the Repository ──────────────────────────────────────────────
step "9/9  Clone the Repository"

DEFAULT_DEST="$HOME/workspace/cpos-hub"
echo ""
read -rp "  Where should the repo be cloned? [${DEFAULT_DEST}]: " DEST
DEST="${DEST:-$DEFAULT_DEST}"

if [ -d "$DEST/.git" ]; then
  skip "Repo already exists at $DEST"
else
  mkdir -p "$(dirname "$DEST")"
  gh repo clone cpos-com/cpos-hub "$DEST" -- --depth=1 || die "Failed to clone repository."
  ok "Cloned to $DEST"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  All done!${RESET}"
echo ""
echo "  Next step — run the developer onboarding tool:"
echo ""
echo -e "    ${DIM}cd $DEST${RESET}"
echo -e "    ${DIM}node scripts/onboarding/index.js${RESET}"
echo ""
