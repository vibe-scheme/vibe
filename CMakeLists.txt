cmake_minimum_required(VERSION 3.20)
project(Vibe LANGUAGES C CXX)

# Find LLVM package (version 21)
# Note: We require LLVM 21. The bootstrap compiler uses LLVM tools (llvm-as, llvm-link, llc)
# during build time and links against LLVM C API libraries via FFI for bitcode generation.

# Try to find LLVM 21 in common locations first
# Homebrew on macOS typically installs to /usr/local/opt/llvm or /opt/homebrew/opt/llvm
if(APPLE)
    # Check for Homebrew LLVM installations
    if(EXISTS "/opt/homebrew/opt/llvm/lib/cmake/llvm")
        set(LLVM_DIR "/opt/homebrew/opt/llvm/lib/cmake/llvm")
    elseif(EXISTS "/usr/local/opt/llvm/lib/cmake/llvm")
        set(LLVM_DIR "/usr/local/opt/llvm/lib/cmake/llvm")
    elseif(EXISTS "/usr/local/Cellar/llvm")
        # Find the latest LLVM 21.x in Cellar
        file(GLOB LLVM_CELLAR_VERSIONS "/usr/local/Cellar/llvm/21.*")
        if(LLVM_CELLAR_VERSIONS)
            list(SORT LLVM_CELLAR_VERSIONS)
            list(REVERSE LLVM_CELLAR_VERSIONS)
            list(GET LLVM_CELLAR_VERSIONS 0 LLVM_CELLAR_LATEST)
            set(LLVM_DIR "${LLVM_CELLAR_LATEST}/lib/cmake/llvm")
        endif()
    endif()
endif()

# Find LLVM - we need version 21.x
# Note: CMake's version checking can be finicky with LLVM, so we find it first
# then verify the version manually
if(LLVM_DIR)
    # LLVM_DIR was set above, use it
    find_package(LLVM REQUIRED CONFIG)
else()
    # Let CMake find it, but don't enforce version (we'll check manually)
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
# LLVM_TOOLS_BINARY_DIR is set by find_package(LLVM)
if(NOT LLVM_TOOLS_BINARY_DIR)
    # Fallback: try to find llvm tools in common locations
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

# Verify required LLVM tools are available
# Search in LLVM_TOOLS_BINARY_DIR first to avoid finding old versions in PATH
find_program(LLVM_AS NAMES llvm-as PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)
find_program(LLVM_LINK NAMES llvm-link PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)
find_program(LLC NAMES llc PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)

message(STATUS "Found llvm-as: ${LLVM_AS}")
message(STATUS "Found llvm-link: ${LLVM_LINK}")
message(STATUS "Found llc: ${LLC}")

# Note: The bootstrap compiler executable does not link against LLVM libraries.
# It only uses LLVM tools to process bitcode files. The executable itself
# is compiled from LLVM IR to native code and only needs standard C libraries.

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Build mode: BOOTSTRAP (uses .ll files) or KERNEL (uses .vibe + _no_vibe.ll files)
if(NOT DEFINED BUILD_MODE)
    set(BUILD_MODE "BOOTSTRAP" CACHE STRING "Build mode: BOOTSTRAP or KERNEL")
endif()

message(STATUS "Build mode: ${BUILD_MODE}")

if(BUILD_MODE STREQUAL "BOOTSTRAP")
    set(USE_VIBE_FILES OFF)
    set(LEXER_SOURCE ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.ll)
elseif(BUILD_MODE STREQUAL "KERNEL")
    set(USE_VIBE_FILES ON)
    set(LEXER_SOURCE ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer_no_vibe.ll)
else()
    message(FATAL_ERROR "Invalid BUILD_MODE: ${BUILD_MODE}. Must be BOOTSTRAP or KERNEL")
endif()

# Shared Types - LLVM bitcode module (must be built first)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_types.bc
    COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/types/types.ll -o ${CMAKE_BINARY_DIR}/bootstrap_types.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/types/types.ll
    COMMENT "Assembling types bitcode"
)

add_custom_target(bootstrap_types DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_types.bc)

# Bootstrap Lexer - LLVM bitcode module
if(USE_VIBE_FILES)
    # KERNEL mode: Use _no_vibe.ll + compile .vibe files
    # Note: bootstrap_compiler must exist (build.sh checks this)
    # Step 1: Assemble lexer_no_vibe.ll to bitcode
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
        COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer_no_vibe.ll -o ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
        DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer_no_vibe.ll
        COMMENT "Assembling lexer_no_vibe bitcode (temp)"
    )
    
    # Step 2: Compile lexer.vibe to bitcode (requires bootstrap_compiler)
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_lexer_vibe_temp.bc
        COMMAND ${CMAKE_BINARY_DIR}/bin/bootstrap_compiler
            ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.vibe
            -o ${CMAKE_BINARY_DIR}/bootstrap_lexer_vibe_temp.bc
        DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.vibe
        COMMENT "Compiling lexer.vibe to bitcode"
    )
    
    # Step 3: Create final lexer.bc (with Vibe code)
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
        COMMAND ${LLVM_LINK}
            ${CMAKE_BINARY_DIR}/bootstrap_types.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer_vibe_temp.bc
            -o ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
        DEPENDS
            ${CMAKE_BINARY_DIR}/bootstrap_types.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer_vibe_temp.bc
        COMMENT "Linking lexer with types and Vibe code"
    )
    
    add_custom_target(bootstrap_lexer_vibe_temp DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_lexer_vibe_temp.bc)
    add_custom_target(bootstrap_lexer DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc)
    add_dependencies(bootstrap_lexer bootstrap_lexer_vibe_temp)
else()
    # BOOTSTRAP mode: Use .ll files only
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
        COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.ll -o ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
        DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.ll
        COMMENT "Assembling lexer bitcode (temp)"
    )
    
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
        COMMAND ${LLVM_LINK}
            ${CMAKE_BINARY_DIR}/bootstrap_types.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
            -o ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
        DEPENDS
            ${CMAKE_BINARY_DIR}/bootstrap_types.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer_temp.bc
        COMMENT "Linking lexer with types"
    )
    
    add_custom_target(bootstrap_lexer DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc)
endif()

# Bootstrap Parser - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_parser_temp.bc
    COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/parser/parser.ll -o ${CMAKE_BINARY_DIR}/bootstrap_parser_temp.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/parser/parser.ll
    COMMENT "Assembling parser bitcode (temp)"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
    COMMAND ${LLVM_LINK} ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_parser_temp.bc -o ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
    DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_parser_temp.bc
    COMMENT "Linking parser with types"
)

add_custom_target(bootstrap_parser DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_parser.bc)

# Bootstrap Runtime - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_runtime_temp.bc
    COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/runtime/runtime.ll -o ${CMAKE_BINARY_DIR}/bootstrap_runtime_temp.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/runtime/runtime.ll
    COMMENT "Assembling runtime bitcode (temp)"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
    COMMAND ${LLVM_LINK} ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_runtime_temp.bc -o ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
    DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_runtime_temp.bc
    COMMENT "Linking runtime with types"
)

add_custom_target(bootstrap_runtime DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc)

# Bootstrap FFI - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_ffi_temp.bc
    COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/runtime/ffi.ll -o ${CMAKE_BINARY_DIR}/bootstrap_ffi_temp.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/runtime/ffi.ll
    COMMENT "Assembling FFI bitcode (temp)"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
    COMMAND ${LLVM_LINK} ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_ffi_temp.bc -o ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
    DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_ffi_temp.bc
    COMMENT "Linking FFI with types"
)

add_custom_target(bootstrap_ffi DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc)

# Bootstrap Code Generator - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_codegen_temp.bc
    COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/compiler/codegen.ll -o ${CMAKE_BINARY_DIR}/bootstrap_codegen_temp.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/compiler/codegen.ll
    COMMENT "Assembling codegen bitcode (temp)"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc
    COMMAND ${LLVM_LINK} ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_codegen_temp.bc -o ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc
    DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_codegen_temp.bc
    COMMENT "Linking codegen with types"
)

add_custom_target(bootstrap_codegen DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc)

# Bootstrap Compiler - Main executable
# First compile main.ll to bitcode, then link all modules and compile to native
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler_main_temp.bc
    COMMAND ${LLVM_AS} ${CMAKE_SOURCE_DIR}/bootstrap/compiler/main.ll -o ${CMAKE_BINARY_DIR}/bootstrap_compiler_main_temp.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/compiler/main.ll
    COMMENT "Assembling compiler main bitcode (temp)"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
    COMMAND ${LLVM_LINK} ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_compiler_main_temp.bc -o ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
    DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_types.bc ${CMAKE_BINARY_DIR}/bootstrap_compiler_main_temp.bc
    COMMENT "Linking compiler main with types"
)

if(USE_VIBE_FILES)
    # KERNEL mode: Build vibe_kernel
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
        COMMAND ${LLVM_LINK}
            ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
            ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
            ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
            ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
            ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc
            -o ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
        DEPENDS
            ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
            ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
            ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
            ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
            ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc
        COMMENT "Linking Vibe kernel bitcode modules"
    )
    
    # Compile kernel bitcode to object file
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/vibe_kernel.o
        COMMAND ${LLC} -filetype=obj ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc -o ${CMAKE_BINARY_DIR}/vibe_kernel.o
        DEPENDS ${CMAKE_BINARY_DIR}/vibe_kernel_linked.bc
        COMMENT "Compiling kernel bitcode to object file"
    )
    
    # Create kernel executable
    add_executable(vibe_kernel ${CMAKE_BINARY_DIR}/vibe_kernel.o)
    set_target_properties(vibe_kernel PROPERTIES LINKER_LANGUAGE C)
    target_link_libraries(vibe_kernel ${LLVM_LIBS})
    if(UNIX AND NOT APPLE)
        target_link_libraries(vibe_kernel dl)
    endif()
    add_dependencies(vibe_kernel bootstrap_types bootstrap_lexer bootstrap_parser bootstrap_runtime bootstrap_ffi bootstrap_codegen)
else()
    # BOOTSTRAP mode: Build bootstrap_compiler
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc
        COMMAND ${LLVM_LINK}
            ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
            ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
            ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
            ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
            ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc
            -o ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc
        DEPENDS
            ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
            ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
            ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
            ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
            ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
            ${CMAKE_BINARY_DIR}/bootstrap_codegen.bc
        COMMENT "Linking bootstrap compiler bitcode modules"
    )
endif()

# Link against LLVM C API libraries
# Map LLVM components to library names
# Note: We use LLVM's component mapping, but may need to adjust component names
# based on the actual LLVM installation. Common components:
# - Core: Core LLVM functionality
# - BitWriter: For writing bitcode files
# - IR: IR functionality (may be part of Core in some builds)
llvm_map_components_to_libnames(LLVM_LIBS
    Core
    BitWriter
    Support
    Target
    MC
    Linker
    native
    nativecodegen
)

if(NOT USE_VIBE_FILES)
    # BOOTSTRAP mode: Compile bootstrap_compiler
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler.o
        COMMAND ${LLC} -filetype=obj ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc -o ${CMAKE_BINARY_DIR}/bootstrap_compiler.o
        DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc
        COMMENT "Compiling bitcode to object file"
    )
    
    # Create native executable from object file
    # Note: The bootstrap compiler links against LLVM C API libraries via FFI.
    # FFI is used to call LLVM C API functions at runtime for bitcode generation.
    # The executable needs standard C libraries (libc), dynamic library loading
    # (libdl on Linux), and LLVM C API libraries.
    add_executable(bootstrap_compiler ${CMAKE_BINARY_DIR}/bootstrap_compiler.o)
    set_target_properties(bootstrap_compiler PROPERTIES LINKER_LANGUAGE C)
    
    # Link LLVM libraries
    target_link_libraries(bootstrap_compiler ${LLVM_LIBS})
    
    # Link dynamic library loading (for FFI)
    if(UNIX AND NOT APPLE)
        target_link_libraries(bootstrap_compiler dl)
    elseif(APPLE)
        # macOS doesn't need separate dl library (dlopen is in libc)
        # No additional libraries needed
    endif()
    
    # Make bootstrap_compiler depend on all bitcode modules
    add_dependencies(bootstrap_compiler bootstrap_types bootstrap_lexer bootstrap_parser bootstrap_runtime bootstrap_ffi bootstrap_codegen)
endif()

# Testing
enable_testing()

if(USE_VIBE_FILES)
    # KERNEL mode: Use vibe_kernel for tests
    add_custom_target(run_tests
        COMMAND ${CMAKE_SOURCE_DIR}/test/run_test.sh
        DEPENDS vibe_kernel
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running Vibe kernel tests"
    )
    add_test(NAME hello_world COMMAND ${CMAKE_SOURCE_DIR}/test/run_test.sh)
else()
    # BOOTSTRAP mode: Use bootstrap_compiler for tests
    add_custom_target(run_tests
        COMMAND ${CMAKE_SOURCE_DIR}/test/run_test.sh
        DEPENDS bootstrap_compiler
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running bootstrap compiler tests"
    )
    add_test(NAME hello_world COMMAND ${CMAKE_SOURCE_DIR}/test/run_test.sh)
endif()

# Install targets
if(USE_VIBE_FILES)
    install(TARGETS vibe_kernel
        RUNTIME DESTINATION bin
    )
else()
    install(TARGETS bootstrap_compiler
        RUNTIME DESTINATION bin
    )
endif()

install(FILES
    ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
    ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
    ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
    DESTINATION lib/vibe
)
