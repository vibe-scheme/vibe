cmake_minimum_required(VERSION 3.20)
project(Vibe LANGUAGES C CXX)

# Find LLVM package (version 21)
# The Vibe compiler uses LLVM tools (llvm-as, llvm-link, llc) during build time
# and links against LLVM C API libraries for bitcode generation.

# Try to find LLVM 21 in common locations first
if(APPLE)
    if(EXISTS "/opt/homebrew/opt/llvm/lib/cmake/llvm")
        set(LLVM_DIR "/opt/homebrew/opt/llvm/lib/cmake/llvm")
    elseif(EXISTS "/usr/local/opt/llvm/lib/cmake/llvm")
        set(LLVM_DIR "/usr/local/opt/llvm/lib/cmake/llvm")
    elseif(EXISTS "/usr/local/Cellar/llvm")
        file(GLOB LLVM_CELLAR_VERSIONS "/usr/local/Cellar/llvm/21.*")
        if(LLVM_CELLAR_VERSIONS)
            list(SORT LLVM_CELLAR_VERSIONS)
            list(REVERSE LLVM_CELLAR_VERSIONS)
            list(GET LLVM_CELLAR_VERSIONS 0 LLVM_CELLAR_LATEST)
            set(LLVM_DIR "${LLVM_CELLAR_LATEST}/lib/cmake/llvm")
        endif()
    endif()
endif()

if(LLVM_DIR)
    find_package(LLVM REQUIRED CONFIG)
else()
    find_package(LLVM REQUIRED CONFIG)
endif()

# Verify we have the right version (21.x)
if(LLVM_PACKAGE_VERSION)
    if(LLVM_PACKAGE_VERSION VERSION_LESS "21.0")
        message(FATAL_ERROR "LLVM 21.0 or higher is required, but found version ${LLVM_PACKAGE_VERSION}. Please install LLVM 21.")
    endif()
    if(LLVM_PACKAGE_VERSION VERSION_GREATER_EQUAL "22.0")
        message(WARNING "LLVM 22 is not yet supported. Found version ${LLVM_PACKAGE_VERSION}. Proceeding anyway, but may encounter issues.")
    endif()
    message(STATUS "Found LLVM version ${LLVM_PACKAGE_VERSION}")
else()
    message(WARNING "Could not determine LLVM version. Proceeding, but LLVM 21 is recommended.")
endif()

# Set up LLVM toolchain
if(NOT LLVM_TOOLS_BINARY_DIR)
    find_program(LLVM_AS NAMES llvm-as PATHS
        ${LLVM_TOOLS_BINARY_DIR}
        /usr/local/opt/llvm/bin
        /usr/local/bin
        /usr/bin
        REQUIRED
    )
    get_filename_path(LLVM_TOOLS_BINARY_DIR ${LLVM_AS})
endif()

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
message(STATUS "LLVM tools directory: ${LLVM_TOOLS_BINARY_DIR}")

find_program(LLVM_AS NAMES llvm-as PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)
find_program(LLVM_LINK NAMES llvm-link PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)
find_program(LLC NAMES llc PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)

message(STATUS "Found llvm-as: ${LLVM_AS}")
message(STATUS "Found llvm-link: ${LLVM_LINK}")
message(STATUS "Found llc: ${LLC}")

# Find zstd library (required by LLVM's compression support)
find_library(ZSTD_LIBRARY NAMES zstd PATHS /opt/homebrew/lib NO_DEFAULT_PATH)
if(NOT ZSTD_LIBRARY)
    find_library(ZSTD_LIBRARY NAMES zstd)
endif()
if(ZSTD_LIBRARY)
    message(STATUS "Found zstd: ${ZSTD_LIBRARY}")
endif()

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Detect target architecture from the system
if(APPLE)
    execute_process(
        COMMAND sysctl -n machdep.cpu.brand_string
        OUTPUT_VARIABLE CPU_BRAND
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(CPU_BRAND MATCHES "Apple")
        set(LLVM_TARGET_TRIPLE "arm64-apple-darwin")
    else()
        set(LLVM_TARGET_TRIPLE "x86_64-apple-macosx10.15.0")
    endif()
else()
    set(LLVM_TARGET_TRIPLE "${CMAKE_SYSTEM_PROCESSOR}-unknown-linux-gnu")
endif()
message(STATUS "Target triple: ${LLVM_TARGET_TRIPLE}")

# The compiler (vibe_kernel) must already exist in build/bin/ before CMake runs.
# build.sh ensures this by downloading the seed binary if needed.
set(VIBE_COMPILER ${CMAKE_BINARY_DIR}/bin/vibe_kernel)

# ============================================================================
# Compile each kernel module from .vibe source to bitcode
# ============================================================================

# Lexer
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/lexer.bc
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/lexer.vibe
        -o ${CMAKE_BINARY_DIR}/lexer.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/lexer.vibe
    COMMENT "Compiling lexer.vibe"
)
add_custom_target(compile_lexer DEPENDS ${CMAKE_BINARY_DIR}/lexer.bc)

# Parser
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/parser.bc
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/parser.vibe
        -o ${CMAKE_BINARY_DIR}/parser.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/parser.vibe
    COMMENT "Compiling parser.vibe"
)
add_custom_target(compile_parser DEPENDS ${CMAKE_BINARY_DIR}/parser.bc)

# FFI
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/ffi.bc
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/ffi.vibe
        -o ${CMAKE_BINARY_DIR}/ffi.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/ffi.vibe
    COMMENT "Compiling ffi.vibe"
)
add_custom_target(compile_ffi DEPENDS ${CMAKE_BINARY_DIR}/ffi.bc)

# DSL
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/dsl.bc
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/dsl.vibe
        -o ${CMAKE_BINARY_DIR}/dsl.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/dsl.vibe
    COMMENT "Compiling dsl.vibe"
)
add_custom_target(compile_dsl DEPENDS ${CMAKE_BINARY_DIR}/dsl.bc)

# Util (outputs .ll text, then assembled to .bc - same as codegen for consistent symbol generation)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/util.ll
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/util.vibe
        -o ${CMAKE_BINARY_DIR}/util.ll
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/util.vibe
    COMMENT "Compiling util.vibe"
)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/util.bc
    COMMAND ${LLVM_AS} ${CMAKE_BINARY_DIR}/util.ll
        -o ${CMAKE_BINARY_DIR}/util.bc
    DEPENDS ${CMAKE_BINARY_DIR}/util.ll
    COMMENT "Assembling util bitcode"
)
add_custom_target(compile_util DEPENDS ${CMAKE_BINARY_DIR}/util.bc)

# Expander
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/expander.bc
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/expander.vibe
        -o ${CMAKE_BINARY_DIR}/expander.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/expander.vibe
    COMMENT "Compiling expander.vibe"
)
add_custom_target(compile_expander DEPENDS ${CMAKE_BINARY_DIR}/expander.bc)

# Codegen (outputs .ll text, then assembled to .bc)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/codegen.ll
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/codegen.vibe
        -o ${CMAKE_BINARY_DIR}/codegen.ll
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/codegen.vibe
    COMMENT "Compiling codegen.vibe"
)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/codegen.bc
    COMMAND ${LLVM_AS} ${CMAKE_BINARY_DIR}/codegen.ll
        -o ${CMAKE_BINARY_DIR}/codegen.bc
    DEPENDS ${CMAKE_BINARY_DIR}/codegen.ll
    COMMENT "Assembling codegen bitcode"
)
add_custom_target(compile_codegen DEPENDS ${CMAKE_BINARY_DIR}/codegen.bc)

# Main (outputs .ll text, then assembled to .bc)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/main.ll
    COMMAND ${VIBE_COMPILER}
        ${CMAKE_SOURCE_DIR}/kernel/main.vibe
        -o ${CMAKE_BINARY_DIR}/main.ll
    DEPENDS ${CMAKE_SOURCE_DIR}/kernel/main.vibe
    COMMENT "Compiling main.vibe"
)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/main.bc
    COMMAND ${LLVM_AS} ${CMAKE_BINARY_DIR}/main.ll
        -o ${CMAKE_BINARY_DIR}/main.bc
    DEPENDS ${CMAKE_BINARY_DIR}/main.ll
    COMMENT "Assembling main bitcode"
)
add_custom_target(compile_main DEPENDS ${CMAKE_BINARY_DIR}/main.bc)

# ============================================================================
# Link all modules and build the vibe_kernel executable
# ============================================================================

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
    COMMAND ${LLVM_LINK}
        ${CMAKE_BINARY_DIR}/main.bc
        ${CMAKE_BINARY_DIR}/lexer.bc
        ${CMAKE_BINARY_DIR}/parser.bc
        ${CMAKE_BINARY_DIR}/ffi.bc
        ${CMAKE_BINARY_DIR}/dsl.bc
        ${CMAKE_BINARY_DIR}/util.bc
        ${CMAKE_BINARY_DIR}/codegen.bc
        ${CMAKE_BINARY_DIR}/expander.bc
        -o ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
    DEPENDS
        ${CMAKE_BINARY_DIR}/main.bc
        ${CMAKE_BINARY_DIR}/lexer.bc
        ${CMAKE_BINARY_DIR}/parser.bc
        ${CMAKE_BINARY_DIR}/ffi.bc
        ${CMAKE_BINARY_DIR}/dsl.bc
        ${CMAKE_BINARY_DIR}/util.bc
        ${CMAKE_BINARY_DIR}/codegen.bc
        ${CMAKE_BINARY_DIR}/expander.bc
    COMMENT "Linking all kernel modules"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/vibe_kernel.o
    COMMAND ${LLC} -mtriple=${LLVM_TARGET_TRIPLE} -filetype=obj
        ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
        -o ${CMAKE_BINARY_DIR}/vibe_kernel.o
    DEPENDS ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
    COMMENT "Compiling linked bitcode to object file"
)

# LLVM libraries
llvm_map_components_to_libnames(LLVM_LIBS
    Core
    BitWriter
    Support
    Target
    MC
    Linker
)

if(LLVM_TARGET_TRIPLE MATCHES "arm64|aarch64")
    llvm_map_components_to_libnames(LLVM_ARCH_LIBS
        AArch64CodeGen
        AArch64Desc
        AArch64Info
        AArch64Utils
        AArch64AsmParser
    )
    list(APPEND LLVM_LIBS ${LLVM_ARCH_LIBS})
    message(STATUS "Added ARM64-specific LLVM components")
elseif(LLVM_TARGET_TRIPLE MATCHES "x86_64|i386|i686")
    llvm_map_components_to_libnames(LLVM_ARCH_LIBS
        X86CodeGen
        X86Desc
        X86Info
        X86Utils
    )
    list(APPEND LLVM_LIBS ${LLVM_ARCH_LIBS})
    message(STATUS "Added X86-specific LLVM components")
endif()

add_executable(vibe_kernel ${CMAKE_BINARY_DIR}/vibe_kernel.o)
set_target_properties(vibe_kernel PROPERTIES LINKER_LANGUAGE C)

if(LLVM_TARGET_TRIPLE MATCHES "arm64")
    set_target_properties(vibe_kernel PROPERTIES OSX_ARCHITECTURES "arm64")
elseif(LLVM_TARGET_TRIPLE MATCHES "x86_64")
    set_target_properties(vibe_kernel PROPERTIES OSX_ARCHITECTURES "x86_64")
endif()

target_link_libraries(vibe_kernel ${LLVM_LIBS})
if(UNIX AND NOT APPLE)
    target_link_libraries(vibe_kernel dl)
endif()
if(ZSTD_LIBRARY)
    target_link_libraries(vibe_kernel ${ZSTD_LIBRARY})
endif()

add_dependencies(vibe_kernel compile_lexer compile_parser compile_ffi compile_dsl compile_util compile_expander compile_codegen compile_main)

# ============================================================================
# Testing
# ============================================================================

enable_testing()

add_custom_target(run_tests
    COMMAND ${CMAKE_SOURCE_DIR}/test/run_test.sh
    DEPENDS vibe_kernel
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running tests"
)
add_test(NAME hello_world COMMAND ${CMAKE_SOURCE_DIR}/test/run_test.sh)

# ============================================================================
# Install
# ============================================================================

install(TARGETS vibe_kernel
    RUNTIME DESTINATION bin
)

install(FILES
    ${CMAKE_BINARY_DIR}/lexer.bc
    ${CMAKE_BINARY_DIR}/parser.bc
    DESTINATION lib/vibe
)
