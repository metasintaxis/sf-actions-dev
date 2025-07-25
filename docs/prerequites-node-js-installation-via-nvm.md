# Prerequisites: Node.js Installation via NVM

This guide covers installing Node Version Manager (NVM) on macOS to manage Node.js versions for this project.

## Prerequisites

- macOS with Homebrew installed
- Terminal access

## Installation Steps

### 1. Install NVM via Homebrew

```bash
brew install nvm
```

### 2. Create NVM's working directory if it doesn't exist

```bash
mkdir ~/.nvm
```

### 3. Set up NVM in your shell profile

Add the following lines to your shell profile (`.zshrc` or `.bashrc`):

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/share/nvm/nvm.sh" ] && \. "/opt/homebrew/share/nvm/nvm.sh"
[ -s "/opt/homebrew/share/nvm/bash_completion" ] && \. "/opt/homebrew/share/nvm/bash_completion"
```

To know which shell are you terminal using, run the following command:

```bash
echo $0
```

That should tell you which config file you need to modify, use `.zshrc` if the output displays `zsh` and `.bashrc` if the previous command output includes `bash`.


### 4. Reload your shell

```bash
source ~/.zshrc  # or ~/.bash_profile
```

### 5. Verify installation

```bash
nvm --version
```

## Usage for this Project

### Install and use the recommended Node.js version

```bash
# Install the latest LTS version
nvm install --lts

# Use the LTS version
nvm use --lts

# Set as default
nvm alias default node
```

### Verify setup

```bash
node --version
npm --version
```

## Next Steps

After NVM setup, you can proceed with project installation:

```bash
npm install
```

This will set up Husky Git hooks and all project dependencies automatically.

## Troubleshooting

- If `nvm` command is not found, ensure the shell profile lines are correctly added and sourced
- For Apple Silicon Macs, Homebrew installs to `/opt/homebrew/` instead of `/usr/local/`
- Restart your terminal if changes don't take effect immediately