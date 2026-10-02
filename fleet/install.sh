#!/usr/bin/env zsh
# install.sh — idempotent fleet overlay installer for oh-my-zsh.
# Law: upstream oh-my-zsh files are NEVER modified. We only link into
# $ZSH/custom, which is oh-my-zsh's designed extension point.
set -e
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
HERE="${0:A:h}"

if [[ ! -d "$ZSH" ]]; then
  print -u2 "install: oh-my-zsh not found at $ZSH — clone it first:"
  print -u2 "  git clone https://github.com/SuperInstance/oh-my-zsh \"$ZSH\""
  exit 1
fi

mkdir -p "$ZSH/custom/plugins/fleet" "$ZSH/custom/themes"
ln -sf "$HERE/plugins/fleet/fleet.plugin.zsh" "$ZSH/custom/plugins/fleet/fleet.plugin.zsh"
ln -sf "$HERE/themes/receipts.zsh-theme"      "$ZSH/custom/themes/receipts.zsh-theme"

print -r -- "linked fleet plugin + receipts theme into $ZSH/custom"
print -r -- "enable in ~/.zshrc:"
print -r -- '  plugins=(... fleet)'
print -r -- '  ZSH_THEME="receipts"'
