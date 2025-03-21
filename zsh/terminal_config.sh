#!/bin/zsh

# This script installs zsh-autosuggestions, zsh-syntax-highlighting, kubectl, krew, kube-ps1, and sets up a clean zsh environment.

# Check for Homebrew installation
if ! command -v brew &>/dev/null; then
    echo "Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

# Backup current zshrc
cp ~/.zshrc ~/.zshrc.bak

#Update brew
brew update

# Function to install a package if it's not already installed
install_if_missing() {
    local package=$1
    if ! command -v "$package" &>/dev/null; then
        echo "Installing $package..."
        brew install "$package"
    else
        echo "$package is already installed."
    fi
}

# Install necessary tools
echo "Installing required tools..."
install_if_missing zsh-autosuggestions
install_if_missing zsh-syntax-highlighting
install_if_missing kubectl

# Install krew manually
if ! command -v kubectl-krew &>/dev/null; then
    echo "Installing krew manually..."
    (
        set -x
        cd "$(mktemp -d)" &&
        OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
        ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
        KREW="krew-${OS}_${ARCH}" &&
        curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
        tar zxvf "${KREW}.tar.gz" &&
        ./"${KREW}" install krew
    )
else
    echo "krew is already installed."
fi

# Install kube-ps1 via krew
install_if_missing kube-ps1

# 4. Update .zshrc with required configurations
echo "Configuring zsh..."

cat <<'EOL' >> ~/.zshrc

# Add krew bin to PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Add Homebrew binary directory to PATH
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

# Enable zsh-autosuggestions and zsh-syntax-highlighting
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#History configuration
HISTFILE=~/.zhistory
HISTSIZE=1000
SAVEHIST=1000
alias h="history"

# Aliases for kubectl
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kns='kubectl config set-context --current --namespace'

#Color Linux commands
color_param="-G"
alias ls="ls $color_param"
alias ll="ls -l $color_param"
alias grep="grep $color_param"
alias egrep="egrep $color_param"

# Autocomplete settings for kubectl
autoload -Uz compinit
compinit
setopt auto_list
setopt menu_complete
setopt auto_menu
setopt complete_in_word
source <(kubectl completion zsh)

# Set up kube-ps1 for Kubernetes context in prompt
plugins=(
kube-ps1
kubectl-autocomplete
)
source "$HOMEBREW_PREFIX/opt/kube-ps1/share/kube-ps1.sh"
PS1='$(kube_ps1) %F{green}%1~%f %# '

#Set up kubectl autocomplete
autoload -Uz compinit
compinit
setopt auto_list        # Show autocomplete options immediately
setopt menu_complete    # Cycle through options with Tab
setopt auto_menu        # Display menu after first Tab press
setopt complete_in_word # Complete from the middle of a word
compinit
source <(kubectl completion zsh)

# Function to display current Git branch in the prompt
getBranch() {
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        echo "%F{yellow}($branch)%f"
    fi
}

# Include Git branch in the prompt
export PS1="$PS1 \$(getBranch) "
setopt PROMPT_SUBST;

EOL

# Reload .zshrc to apply changes immediately
echo "Reloading .zshrc..."
source ~/.zshrc

# Verify installation
echo "Verifying installation..."
kubectl version --client
kubectl krew version

