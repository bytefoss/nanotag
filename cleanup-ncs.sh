#!/bin/zsh
# Removes the manual nRF Connect SDK install (README "Alternative: manual install") on macOS / Linux.
# That install keeps everything in ~/ncs (Python venv with west, SDK v3.2.0 source, Zephyr ARM compiler)
# plus cmake, ninja and dtc, which are removed here only if Homebrew installed them. The other paths are
# places Zephyr writes to by default, listed in case something slipped out. Shows what it found and asks
# before deleting anything. Needs zsh (default on macOS; on Linux install it or delete ~/ncs by hand).

cleanup_paths=(
  "$HOME/ncs"                                        # venv, SDK v3.2.0, Zephyr SDK compiler
  "$HOME/.cmake/packages/Zephyr"                     # Zephyr CMake package registration
  "$HOME/.cmake/packages/ZephyrUnittest"
  "$HOME/Library/Caches/zephyr"                      # Zephyr build cache (macOS)
  "$HOME/.cache/zephyr"                              # Zephyr build cache (Linux)
  "${0:A:h}/build"                                   # this project's build output
)
brew_formulas=(cmake ninja dtc)                      # installed for this project only

found_paths=()
for cleanup_path in $cleanup_paths; do
  [[ -e $cleanup_path ]] && found_paths+=$cleanup_path
done
found_formulas=()
for brew_formula in $brew_formulas; do
  brew list --formula $brew_formula >/dev/null 2>&1 && found_formulas+=$brew_formula
done

if (( ${#found_paths} == 0 && ${#found_formulas} == 0 )); then
  echo "Nothing to clean up."
  exit 0
fi

echo "Will delete:"
for found_path in $found_paths; do
  printf "  %8s  %s\n" "$(du -sh "$found_path" 2>/dev/null | cut -f1)" "$found_path"
done
(( ${#found_formulas} )) && echo "  brew uninstall $found_formulas"
echo
echo "Not touched: this project's source, tools/ and firmware/."
echo
read "is_confirmed?Delete these? [y/N] "
[[ $is_confirmed == [yY] ]] || { echo "Cancelled."; exit 1; }

for found_path in $found_paths; do
  rm -rf "$found_path" && echo "Deleted $found_path"
done
(( ${#found_formulas} )) && brew uninstall $found_formulas
