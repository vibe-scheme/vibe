#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"

cd "$PROJECT_ROOT"

# Force arm64 for linking when on Darwin (vibe produces arm64; cc may run under Rosetta)
ARCH_FLAG=""
if [ "$(uname -s)" = "Darwin" ]; then
    ARCH_FLAG="-arch arm64"
fi

# Determine which compiler to use
if [ -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
    COMPILER="${BUILD_DIR}/bin/vibe_kernel"
elif [ -f "${BUILD_DIR}/bin/bootstrap_compiler" ]; then
    COMPILER="${BUILD_DIR}/bin/bootstrap_compiler"
else
    echo "FAIL: No compiler found (neither vibe_kernel nor bootstrap_compiler)"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: hello_world (must pass)
echo "=== Test: hello_world.vibe ==="
echo "Compiling hello_world.vibe using $COMPILER..."
if "${COMPILER}" test/hello_world.vibe -o test/hello_world.o 2>/dev/null; then
    if [ -f test/hello_world.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/hello_world.o -o test/hello_world.exe -lc 2>/dev/null; then
            OUTPUT=$(./test/hello_world.exe)
            if [ "$OUTPUT" = "Hello, World!" ]; then
                echo "PASS: hello_world"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: hello_world - Expected 'Hello, World!', got '$OUTPUT'"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: hello_world - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: hello_world - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: hello_world - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 2: macro_hello (define-syntax + substitution into llvm:define-function body)
echo ""
echo "=== Test: macro_hello.vibe (macro canary) ==="
echo "Compiling macro_hello.vibe using $COMPILER..."
if "${COMPILER}" test/macro_hello.vibe -o test/macro_hello.o 2>/dev/null; then
    if [ -f test/macro_hello.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/macro_hello.o -o test/macro_hello.exe -lc 2>/dev/null; then
            # Exit 42 is success; set -e would abort on nonzero without an if guard.
            if ./test/macro_hello.exe 2>/dev/null; then
                MACRO_EXIT=0
            else
                MACRO_EXIT=$?
            fi
            if [ "$MACRO_EXIT" -eq 42 ]; then
                echo "PASS: macro_hello"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: macro_hello - Expected exit code 42, got $MACRO_EXIT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: macro_hello - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: macro_hello - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: macro_hello - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 3: macro_literals_clauses (syntax-rules literals + multiple clauses)
echo ""
echo "=== Test: macro_literals_clauses.vibe ==="
echo "Compiling macro_literals_clauses.vibe using $COMPILER..."
if "${COMPILER}" test/macro_literals_clauses.vibe -o test/macro_literals_clauses.o 2>/dev/null; then
    if [ -f test/macro_literals_clauses.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/macro_literals_clauses.o -o test/macro_literals_clauses.exe -lc 2>/dev/null; then
            if ./test/macro_literals_clauses.exe 2>/dev/null; then
                LIT_EXIT=0
            else
                LIT_EXIT=$?
            fi
            if [ "$LIT_EXIT" -eq 27 ]; then
                echo "PASS: macro_literals_clauses"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: macro_literals_clauses - Expected exit code 27, got $LIT_EXIT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: macro_literals_clauses - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: macro_literals_clauses - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: macro_literals_clauses - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 4: macro_define_via_expand (define-syntax after macro expansion at top level)
echo ""
echo "=== Test: macro_define_via_expand.vibe ==="
echo "Compiling macro_define_via_expand.vibe using $COMPILER..."
if "${COMPILER}" test/macro_define_via_expand.vibe -o test/macro_define_via_expand.o 2>/dev/null; then
    if [ -f test/macro_define_via_expand.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/macro_define_via_expand.o -o test/macro_define_via_expand.exe -lc 2>/dev/null; then
            if ./test/macro_define_via_expand.exe 2>/dev/null; then
                VIA_EXIT=0
            else
                VIA_EXIT=$?
            fi
            if [ "$VIA_EXIT" -eq 33 ]; then
                echo "PASS: macro_define_via_expand"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: macro_define_via_expand - Expected exit code 33, got $VIA_EXIT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: macro_define_via_expand - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: macro_define_via_expand - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: macro_define_via_expand - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 5: macro_ellipsis_nested (nested subpatterns + ellipsis in syntax-rules)
echo ""
echo "=== Test: macro_ellipsis_nested.vibe ==="
echo "Compiling macro_ellipsis_nested.vibe using $COMPILER..."
if "${COMPILER}" test/macro_ellipsis_nested.vibe -o test/macro_ellipsis_nested.o 2>/dev/null; then
    if [ -f test/macro_ellipsis_nested.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/macro_ellipsis_nested.o -o test/macro_ellipsis_nested.exe -lc 2>/dev/null; then
            if ./test/macro_ellipsis_nested.exe 2>/dev/null; then
                ELL_EXIT=0
            else
                ELL_EXIT=$?
            fi
            if [ "$ELL_EXIT" -eq 64 ]; then
                echo "PASS: macro_ellipsis_nested"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: macro_ellipsis_nested - Expected exit code 64, got $ELL_EXIT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: macro_ellipsis_nested - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: macro_ellipsis_nested - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: macro_ellipsis_nested - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 6: macro_ast_ref_shape (literal-keyed clauses like kernel vibe:ast-ref)
echo ""
echo "=== Test: macro_ast_ref_shape.vibe ==="
echo "Compiling macro_ast_ref_shape.vibe using $COMPILER..."
if "${COMPILER}" test/macro_ast_ref_shape.vibe -o test/macro_ast_ref_shape.o 2>/dev/null; then
    if [ -f test/macro_ast_ref_shape.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/macro_ast_ref_shape.o -o test/macro_ast_ref_shape.exe -lc 2>/dev/null; then
            if ./test/macro_ast_ref_shape.exe 2>/dev/null; then
                AR_EXIT=0
            else
                AR_EXIT=$?
            fi
            if [ "$AR_EXIT" -eq 19 ]; then
                echo "PASS: macro_ast_ref_shape"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: macro_ast_ref_shape - Expected exit code 19, got $AR_EXIT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: macro_ast_ref_shape - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: macro_ast_ref_shape - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: macro_ast_ref_shape - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
exit 0
