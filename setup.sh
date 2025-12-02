#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# --- Colors and Formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Icons ---
CHECK_ICON="${GREEN}✔${NC}"
CROSS_ICON="${RED}✘${NC}"
INFO_ICON="${BLUE}ℹ${NC}"
ARROW_ICON="${CYAN}➜${NC}"

# --- Helper Functions ---

# Spinner function
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Function to run a command with a spinner
run_with_spinner() {
  local message="$1"
  shift
  local command="$@"

  printf "${ARROW_ICON} ${message}...
"

  # Run command in background, redirecting output to a temporary file
  local temp_log=$(mktemp)
  (eval "$command") >"$temp_log" 2>&1 &
  local pid=$!

  # Show spinner
  spinner $pid

  # Wait for process to finish and get exit code
  wait $pid
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    echo -e "${CHECK_ICON} Done"
    rm "$temp_log"
  else
    echo -e "${CROSS_ICON} Failed"
    echo -e "${RED}Error output:${NC}"
    cat "$temp_log"
    rm "$temp_log"
    exit 1
  fi
}

show_help() {
  echo -e "${BOLD}Usage:${NC} setup.sh [OPTIONS]"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -h, --help    Show this help message"
  echo ""
  echo -e "${BOLD}Description:${NC}"
  echo "  Sets up Stylelint, Prettier, and pre-commit hooks for a project."
  echo "  Can initialize in the current directory or create a new one."
}

# --- Main Script ---

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

echo -e "${BOLD}${BLUE}Welcome to the Stylelint Setup Script!${NC}"
echo -e "${BLUE}--------------------------------------${NC}"

# Quick menu / Interactive mode
echo -e "${INFO_ICON} Where would you like to set up the project?"
echo "1) Current directory ($(pwd))"
echo "2) Create a new directory"
echo -n -e "${YELLOW}Select an option (1/2) [1]: ${NC}"
read choice
choice=${choice:-1}

if [ "$choice" == "2" ]; then
  echo -n -e "${YELLOW}Enter the new directory name: ${NC}"
  read new_dir
  if [ -z "$new_dir" ]; then
    echo -e "${RED}Directory name cannot be empty. Exiting.${NC}"
    exit 1
  fi

  if [ -d "$new_dir" ]; then
    echo -e "${YELLOW}Directory '$new_dir' already exists.${NC}"
    echo -n -e "${YELLOW}Do you want to use it? (y/N) ${NC}"
    read use_exist
    if [[ ! "$use_exist" =~ ^[Yy]$ ]]; then
      echo "Exiting."
      exit 1
    fi
  else
    echo -e "${ARROW_ICON} Creating directory '${CYAN}$new_dir${NC}'..."
    mkdir -p "$new_dir"
  fi

  cd "$new_dir" || exit 1
  echo -e "${CHECK_ICON} Switched to directory: ${BOLD}$(pwd)${NC}"
fi

# Check for package.json
if [ ! -f "package.json" ]; then
  echo -e "${YELLOW}No package.json found.${NC}"
  echo -n -e "${YELLOW}Do you want to run 'npm init -y'? (Y/n) ${NC}"
  read init_npm
  init_npm=${init_npm:-y}
  if [[ "$init_npm" =~ ^[Yy]$ ]]; then
    run_with_spinner "Initializing npm" "npm init -y"
  fi
fi

echo -e "\n${BOLD}Setting up configuration files...${NC}"

# Copy config file
if [ -f ".stylelintrc.json" ]; then
  echo -e "${INFO_ICON} .stylelintrc.json already exists. Skipping copy."
else
  cp "$SCRIPT_DIR/.stylelintrc.json" .
  echo -e "${CHECK_ICON} Copied .stylelintrc.json"
fi

# Copy prettier config
if [ -f ".prettierrc" ]; then
  echo -e "${INFO_ICON} .prettierrc already exists. Skipping copy."
else
  cp "$SCRIPT_DIR/.prettierrc" .
  echo -e "${CHECK_ICON} Copied .prettierrc"
fi

# Copy pre-commit-config.yaml
if [ -f ".pre-commit-config.yaml" ]; then
  echo -e "${INFO_ICON} .pre-commit-config.yaml already exists. Skipping copy."
else
  cp "$SCRIPT_DIR/.pre-commit-config.yaml" .
  echo -e "${CHECK_ICON} Copied .pre-commit-config.yaml"
fi

# Install dependencies
echo ""
run_with_spinner "Installing devDependencies (this may take a while)" "npm install --save-dev stylelint stylelint-config-recommended stylelint-config-standard stylelint-plugin-stylus stylelint-config-html postcss-html postcss-markdown prettier"

# Add scripts to package.json
if [ -f "package.json" ]; then
  echo -e "${ARROW_ICON} Adding scripts to package.json..."
  npm pkg set scripts.lint="stylelint \"src/**/*.styl\" \"**/*.html\" \"**/*.vue\" \"**/*.svelte\" \"**/*.astro\" \"**/*.php\" \"**/*.md\""
  npm pkg set scripts.format="prettier --write \"src/**/*.{styl,js,json}\" && stylelint --fix \"src/**/*.styl\" \"**/*.html\" \"**/*.vue\" \"**/*.svelte\" \"**/*.astro\" \"**/*.php\" \"**/*.md\""
  echo -e "${CHECK_ICON} Scripts added."
else
  echo -e "${RED}No package.json found. Skipping scripts addition.${NC}"
fi

echo -e "\n${GREEN}${BOLD}Stylelint setup complete!${NC} 🚀"
