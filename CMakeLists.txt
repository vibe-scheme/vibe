cmake_minimum_required(VERSION 3.20)
project(Vibe LANGUAGES CXX)

# Find LLVM package
find_package(LLVM REQUIRED CONFIG)

# Set up LLVM toolchain
set(LLVM_TOOLS_BINARY_DIR ${LLVM_TOOLS_BINARY_DIR})
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

# Include LLVM directories
include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# Get LLVM tools
llvm_map_components_to_libnames(LLVM_LIBS
    core
    native
    bitwriter
    bitreader
    asmprinter
    irreader
    linker
    transformutils
    analysis
    executionengine
    mcjit
    target
    mc
    object
    option
    support
)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Bootstrap Lexer - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llvm-as ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.ll -o ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/lexer/lexer.ll
    COMMENT "Assembling lexer bitcode"
)

add_custom_target(bootstrap_lexer DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc)

# Bootstrap Parser - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llvm-as ${CMAKE_SOURCE_DIR}/bootstrap/parser/parser.ll -o ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/parser/parser.ll
    COMMENT "Assembling parser bitcode"
)

add_custom_target(bootstrap_parser DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_parser.bc)

# Bootstrap Runtime - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llvm-as ${CMAKE_SOURCE_DIR}/bootstrap/runtime/runtime.ll -o ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/runtime/runtime.ll
    COMMENT "Assembling runtime bitcode"
)

add_custom_target(bootstrap_runtime DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc)

# FFI System - LLVM bitcode module
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llvm-as ${CMAKE_SOURCE_DIR}/bootstrap/runtime/ffi.ll -o ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/runtime/ffi.ll
    COMMENT "Assembling FFI bitcode"
)

add_custom_target(bootstrap_ffi DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc)

# Bootstrap Compiler - Main executable
# First compile main.ll to bitcode, then link all modules and compile to native
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llvm-as ${CMAKE_SOURCE_DIR}/bootstrap/compiler/main.ll -o ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
    DEPENDS ${CMAKE_SOURCE_DIR}/bootstrap/compiler/main.ll
    COMMENT "Assembling compiler main bitcode"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llvm-link
        ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
        ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
        ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
        ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
        ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
        -o ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc
    DEPENDS
        ${CMAKE_BINARY_DIR}/bootstrap_compiler_main.bc
        ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
        ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
        ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
        ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
    COMMENT "Linking bootstrap compiler bitcode modules"
)

# Compile linked bitcode to object file
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/bootstrap_compiler.o
    COMMAND ${LLVM_TOOLS_BINARY_DIR}/llc -filetype=obj ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc -o ${CMAKE_BINARY_DIR}/bootstrap_compiler.o
    DEPENDS ${CMAKE_BINARY_DIR}/bootstrap_compiler_linked.bc
    COMMENT "Compiling bitcode to object file"
)

# Create native executable from object file
add_executable(bootstrap_compiler ${CMAKE_BINARY_DIR}/bootstrap_compiler.o)
target_link_libraries(bootstrap_compiler ${LLVM_LIBS} dl)

# Make bootstrap_compiler depend on all bitcode modules
add_dependencies(bootstrap_compiler bootstrap_lexer bootstrap_parser bootstrap_runtime bootstrap_ffi)

# Install targets
install(TARGETS bootstrap_compiler
    RUNTIME DESTINATION bin
)

install(FILES
    ${CMAKE_BINARY_DIR}/bootstrap_lexer.bc
    ${CMAKE_BINARY_DIR}/bootstrap_parser.bc
    ${CMAKE_BINARY_DIR}/bootstrap_runtime.bc
    ${CMAKE_BINARY_DIR}/bootstrap_ffi.bc
    DESTINATION lib/vibe
)
