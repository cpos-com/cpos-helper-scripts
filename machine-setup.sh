#!/bin/bash
#
# CPOS — First-time machine setup
#
# Installs all tools required before following the developer onboarding guide
# (docs/guides/onboarding.md in cpos-hub).
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

BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
if [ -z "$BREW_PREFIX" ]; then
  if [ "$(uname -m)" = "arm64" ]; then BREW_PREFIX="/opt/homebrew"; else BREW_PREFIX="/usr/local"; fi
fi

export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# nvm can live in ~/.nvm (its install script) or under Homebrew
find_nvm_sh() {
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    echo "$NVM_DIR/nvm.sh"
  elif [ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ]; then
    echo "$BREW_PREFIX/opt/nvm/nvm.sh"
  fi
}

NVM_SH="$(find_nvm_sh)"
if [ -n "$NVM_SH" ]; then
  skip "Already installed ($NVM_SH)"
else
  brew install nvm || die "Failed to install nvm."
  NVM_SH="$(find_nvm_sh)"
  ok "Installed"
fi

# Add nvm config to ~/.zshrc if not already present
NVM_CONFIG=$(cat <<EOF

export NVM_DIR="\$HOME/.nvm"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
  \. "\$NVM_DIR/nvm.sh"
elif [ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ]; then
  \. "$BREW_PREFIX/opt/nvm/nvm.sh"
  [ -s "$BREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$BREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
fi
EOF
)

if grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null; then
  skip "~/.zshrc already configured for nvm"
else
  echo "$NVM_CONFIG" >> "$HOME/.zshrc"
  ok "Added nvm config to ~/.zshrc"
fi

# Load nvm into the current shell session. nvm does not support 'set -u',
# so nounset is off while nvm runs.
set +u
# shellcheck source=/dev/null
[ -n "$NVM_SH" ] && source "$NVM_SH"

command -v nvm &>/dev/null || die "nvm not found in ~/.nvm or $BREW_PREFIX/opt/nvm. Try opening a new terminal and re-running."
set -u

# ── Step 4: AWS CLI v2 ────────────────────────────────────────────────────────
step "4/9  AWS CLI v2"

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

# ── Step 5: Stripe CLI ────────────────────────────────────────────────────────
step "5/9  Stripe CLI"

if command -v stripe &>/dev/null; then
  skip "Already installed ($(stripe --version))"
else
  brew install stripe/stripe-cli/stripe || die "Failed to install Stripe CLI."
  ok "$(stripe --version)"
fi

# ── Step 6: GitHub CLI ────────────────────────────────────────────────────────
step "6/9  GitHub CLI"

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

# ── Step 7: Clone the Repository ──────────────────────────────────────────────
step "7/9  Clone the Repository"

DEFAULT_DEST="$HOME/workspace/cpos-hub"
echo ""
read -rp "  Where should the repo be cloned? [${DEFAULT_DEST}]: " DEST
DEST="${DEST:-$DEFAULT_DEST}"

if [ -d "$DEST/.git" ]; then
  skip "Repo already exists at $DEST"
  # 'pnpm verify' needs full history to find the merge-base with origin/main
  if [ "$(git -C "$DEST" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    warn "Clone is shallow. Fetching full history..."
    if git -C "$DEST" remote set-branches origin '*' && git -C "$DEST" fetch --unshallow; then
      ok "Fetched full history"
    else
      warn "Could not unshallow. Run 'git fetch --unshallow' in $DEST before 'pnpm verify'."
    fi
  fi
else
  mkdir -p "$(dirname "$DEST")"
  gh repo clone cpos-com/cpos-hub "$DEST" || die "Failed to clone repository."
  ok "Cloned to $DEST"
fi

# ── Step 8: Node.js ───────────────────────────────────────────────────────────
step "8/9  Node.js"

FALLBACK_NODE="22"
if [ -s "$DEST/.nvmrc" ]; then
  NODE_WANT="$(head -n 1 "$DEST/.nvmrc" | tr -d '[:space:]')"
  NODE_SOURCE="$DEST/.nvmrc"
else
  NODE_WANT="$FALLBACK_NODE"
  NODE_SOURCE="fallback, no .nvmrc found"
  warn "No .nvmrc in $DEST — using Node $FALLBACK_NODE"
fi

set +u
if [ "$(nvm version "$NODE_WANT")" != "N/A" ]; then
  nvm use "$NODE_WANT" >/dev/null || die "Failed to switch to Node $NODE_WANT."
  skip "Already installed ($(node --version), from $NODE_SOURCE)"
else
  nvm install "$NODE_WANT" || die "Failed to install Node $NODE_WANT."
  nvm use "$NODE_WANT" >/dev/null || die "Failed to switch to Node $NODE_WANT."
  ok "$(node --version) (from $NODE_SOURCE)"
fi
set -u

# ── Step 9: pnpm ──────────────────────────────────────────────────────────────
step "9/9  pnpm"

# Always enable, even if some pnpm is already on PATH: it is idempotent, and the
# Corepack shim next to nvm's node runs the version pinned in package.json
command -v corepack &>/dev/null || die "corepack not found for Node $(node --version). Install pnpm per the onboarding guide."
corepack enable pnpm || die "Failed to enable pnpm via Corepack."
PNPM_VERSION="$(cd "$DEST" && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 pnpm --version 2>/dev/null)" \
  || die "pnpm did not run in $DEST. Check 'corepack enable pnpm' and the repo's packageManager field."
ok "pnpm $PNPM_VERSION (pinned by $DEST/package.json)"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  All done!${RESET}"
echo ""
echo "  Next step — open a new terminal (to load nvm), then continue the"
echo "  developer onboarding guide from \"Set Up Your Sandbox\":"
echo ""
echo -e "    ${DIM}$DEST/docs/guides/onboarding.md${RESET}"
echo ""
