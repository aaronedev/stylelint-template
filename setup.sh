#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

echo "Setting up Stylelint..."

# Copy config file
if [ -f ".stylelintrc.json" ]; then
  echo ".stylelintrc.json already exists. Skipping copy."
else
  cp "$SCRIPT_DIR/.stylelintrc.json" .
  echo "Copied .stylelintrc.json"
fi

# Copy prettier config
if [ -f ".prettierrc" ]; then
  echo ".prettierrc already exists. Skipping copy."
else
  cp "$SCRIPT_DIR/.prettierrc" .
  echo "Copied .prettierrc"
fi

# Install dependencies
echo "Installing devDependencies..."
npm install --save-dev stylelint stylelint-config-recommended stylelint-config-standard stylelint-plugin-stylus stylelint-config-html postcss-html postcss-markdown prettier

# Add scripts to package.json
if [ -f "package.json" ]; then
  echo "Adding scripts to package.json..."
  npm pkg set scripts.lint="stylelint \"src/**/*.styl\" \"**/*.html\" \"**/*.vue\" \"**/*.svelte\" \"**/*.astro\" \"**/*.php\" \"**/*.md\""
  npm pkg set scripts.format="prettier --write \"src/**/*.{styl,js,json}\" && stylelint --fix \"src/**/*.styl\" \"**/*.html\" \"**/*.vue\" \"**/*.svelte\" \"**/*.astro\" \"**/*.php\" \"**/*.md\""
  echo "Scripts added."
else
  echo "No package.json found. Skipping scripts addition."
fi

# Copy pre-commit-config.yaml
if [ -f ".pre-commit-config.yaml" ]; then
  echo ".pre-commit-config.yaml already exists. Skipping copy."
else
  cp "$SCRIPT_DIR/.pre-commit-config.yaml" .
  echo "Copied .pre-commit-config.yaml"
fi

echo "Stylelint setup complete."
