cmake_minimum_required(VERSION 3.13)
project(vibe VERSION 0.1.0
        DESCRIPTION "A modern Scheme implementation with native compilation"
        LANGUAGES C CXX)

# Build options
option(VIBE_BUILD_TESTS "Build and enable testing" ON)
option(VIBE_BUILD_DOCS "Build documentation" OFF)
option(VIBE_ENABLE_ASAN "Enable Address Sanitizer" OFF)
option(VIBE_ENABLE_UBSAN "Enable Undefined Behavior Sanitizer" OFF)
option(VIBE_BOOTSTRAP "Build bootstrap compiler" OFF)

# Find LLVM
find_package(LLVM REQUIRED CONFIG)
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

# Add LLVM definitions and include paths
add_definitions(${LLVM_DEFINITIONS})
include_directories(${LLVM_INCLUDE_DIRS})

# Set C++ standard and flags
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set warning flags
if(MSVC)
    add_compile_options(/W4)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Configure sanitizers if enabled
if(VIBE_ENABLE_ASAN)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address)
endif()

if(VIBE_ENABLE_UBSAN)
    add_compile_options(-fsanitize=undefined)
    add_link_options(-fsanitize=undefined)
endif()

# Source files
set(VIBE_CORE_SOURCES
    src/vibe/core/bootstrap.vibe
    src/vibe/core/doc.vibe
    src/vibe/core/eval.vibe
    src/vibe/core/ffi.vibe
    src/vibe/core/primitives.vibe
    src/vibe/core/r7rs.vibe
    src/vibe/core/runtime.vibe
    src/vibe/core/special.vibe
    src/vibe/core/types.vibe
    src/vibe/core/main.vibe)

set(VIBE_BASE_SOURCES
    src/vibe/base/binary.vibe
    src/vibe/base/event.vibe
    src/vibe/base/file.vibe
    src/vibe/base/library.vibe
    src/vibe/base/metadata.vibe
    src/vibe/base/package.vibe
    src/vibe/base/package-gen.vibe
    src/vibe/base/package-load.vibe
    src/vibe/base/queue.vibe
    src/vibe/base/repl.vibe
    src/vibe/base/serialize.vibe
    src/vibe/base/serialize-runtime.vibe
    src/vibe/base/socket.vibe
    src/vibe/base/test.vibe
    src/vibe/base/thread.vibe)

set(VIBE_COMPILER_SOURCES
    src/vibe/compiler/lexer.vibe
    src/vibe/compiler/parser.vibe)

# Find existing Vibe compiler
find_program(VIBE_COMPILER
    NAMES vibe bootstrap-vibe
    PATHS 
        ${CMAKE_BINARY_DIR}
        $ENV{PATH}
    NO_DEFAULT_PATH)

if(NOT VIBE_COMPILER AND NOT VIBE_BOOTSTRAP)
    message(FATAL_ERROR "No existing Vibe compiler found. Please build with --bootstrap first.")
endif()

# Create bootstrap compiler if requested
if(VIBE_BOOTSTRAP)
    # Bootstrap compiler uses LLVM bitcode main
    set(BOOTSTRAP_SOURCES
        src/main.ll
        ${VIBE_CORE_SOURCES}
        ${VIBE_BASE_SOURCES}
        ${VIBE_COMPILER_SOURCES})
    
    add_executable(bootstrap-vibe ${BOOTSTRAP_SOURCES})
    target_link_libraries(bootstrap-vibe
        ${llvm_libs}
        pthread
        dl
        z
        m)
    
    # Main vibe compiler uses Vibe main
    set(VIBE_SOURCES
        ${VIBE_CORE_SOURCES}
        ${VIBE_BASE_SOURCES}
        ${VIBE_COMPILER_SOURCES})
    
    add_executable(vibe ${VIBE_SOURCES})
    target_link_libraries(vibe
        ${llvm_libs}
        pthread
        dl
        z
        m)
    
    # Add dependency to ensure bootstrap compiler is built first
    add_dependencies(vibe bootstrap-vibe)
else()
    # Non-bootstrap build uses existing Vibe compiler
    set(VIBE_SOURCES
        ${VIBE_CORE_SOURCES}
        ${VIBE_BASE_SOURCES}
        ${VIBE_COMPILER_SOURCES})
    
    # Create custom command to compile Vibe sources
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/vibe
        COMMAND ${VIBE_COMPILER} --compile-vibe ${VIBE_SOURCES} -o ${CMAKE_BINARY_DIR}/vibe
        DEPENDS ${VIBE_SOURCES}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Compiling Vibe with ${VIBE_COMPILER}")
    
    # Create custom target for the Vibe compiler
    add_custom_target(vibe ALL
        DEPENDS ${CMAKE_BINARY_DIR}/vibe)
endif()

# Install targets
include(GNUInstallDirs)
install(TARGETS vibe
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# Install standard library files
install(DIRECTORY src/vibe/
        DESTINATION ${CMAKE_INSTALL_DATADIR}/vibe/lib
        FILES_MATCHING PATTERN "*.vibe")

# Testing configuration
if(VIBE_BUILD_TESTS)
    enable_testing()
    
    # Create test directories if they don't exist
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test/r7rs)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test/unit)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test/integration)
    
    # Copy test files to build directory
    configure_file(test/run-tests.vibe
                  ${CMAKE_BINARY_DIR}/test/run-tests.vibe
                  COPYONLY)
    configure_file(test/r7rs/r7rs-tests.vibe
                  ${CMAKE_BINARY_DIR}/test/r7rs/r7rs-tests.vibe
                  COPYONLY)
    
    # Add test targets
    add_test(NAME r7rs_tests
             COMMAND vibe test/run-tests.vibe
             WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
    
    # Set test properties
    set_tests_properties(r7rs_tests PROPERTIES
        ENVIRONMENT "VIBE_PATH=${CMAKE_SOURCE_DIR}/src/vibe"
        TIMEOUT 300)  # 5 minute timeout
endif()

# Documentation configuration
if(VIBE_BUILD_DOCS)
    # Add documentation targets here when we implement them
endif()

# Print build configuration summary
message(STATUS "\n=== Build Configuration ===")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Testing enabled: ${VIBE_BUILD_TESTS}")
message(STATUS "Documentation: ${VIBE_BUILD_DOCS}")
message(STATUS "Address Sanitizer: ${VIBE_ENABLE_ASAN}")
message(STATUS "UB Sanitizer: ${VIBE_ENABLE_UBSAN}")
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "=========================\n") 