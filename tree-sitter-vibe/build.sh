#!/usr/bin/env bash
# Build libtree-sitter-vibe for Emacs treesit
# Produces libtree-sitter-vibe.so (Linux) or libtree-sitter-vibe.dylib (macOS)
# in the build/ directory. Add build/ to treesit-extra-load-path in Emacs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build}"
SRC_DIR="$SCRIPT_DIR/src"

# Ensure parser is generated
if [[ ! -f "$SRC_DIR/parser.c" ]]; then
  echo "Generating parser..."
  if command -v tree-sitter &>/dev/null; then
    tree-sitter generate
  elif command -v npx &>/dev/null; then
    npx tree-sitter-cli generate
  else
    echo "Error: Need tree-sitter CLI. Install with: npm install -g tree-sitter-cli"
    exit 1
  fi
fi

mkdir -p "$BUILD_DIR"

# Detect OS and set library extension
case "$(uname -s)" in
  Darwin)
    SOEXT=dylib
    LINKSHARED="-dynamiclib"
    ;;
  Linux|*)
    SOEXT=so
    LINKSHARED="-shared"
    ;;
esac

LIBNAME="libtree-sitter-vibe.$SOEXT"

echo "Building $LIBNAME..."
${CC:-cc} -std=c11 -fPIC \
  -I"$SRC_DIR" \
  $LINKSHARED \
  -o "$BUILD_DIR/$LIBNAME" \
  "$SRC_DIR/parser.c"

echo "Built: $BUILD_DIR/$LIBNAME"
echo ""
echo "Add to Emacs config:"
echo "  (add-to-list 'treesit-extra-load-path \"$BUILD_DIR\")"
