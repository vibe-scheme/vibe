# Vibe Programming Language

Vibe is a Scheme-based programming language implemented in LLVM bitcode. It features a native FFI system and built-in socket communication capabilities.

## Requirements

- CMake 3.13 or higher
- LLVM 15.0 or higher
- A C++ compiler supporting C++17
- pthread library
- zlib

## Building

1. Clone the repository
2. Run the build script:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

The build script will create a `build` directory and compile the Vibe compiler. The resulting executable will be located at `build/vibe`.

## Socket API

Vibe provides a high-level socket API for network communication. Here are the available functions:

### Server-side Functions

```scheme
(create-server-socket port)
```
Creates a TCP server socket listening on the specified port. Returns a socket handle on success, or `#f` on failure.

```scheme
(accept-connection server-socket)
```
Accepts a connection on a server socket. Returns a new socket handle for the client connection on success, or `#f` on failure.

### Client-side Functions

```scheme
(connect-to-server host port)
```
Connects to a TCP server at the specified host and port. Returns a socket handle on success, or `#f` on failure.

### Common Socket Operations

```scheme
(socket-send socket data)
```
Sends data (a string) on the socket. Returns the number of bytes sent on success, or `#f` on failure.

```scheme
(socket-recv socket max-length)
```
Receives up to max-length bytes from the socket. Returns the received data as a string on success, or `#f` on failure.

```scheme
(socket-close socket)
```
Closes a socket. Returns `#t` on success, or `#f` on failure.

## Example Usage

Here's a simple echo server example:

```scheme
(define server (create-server-socket 8080))
(if server
    (let ((client (accept-connection server)))
      (if client
          (begin
            (let ((data (socket-recv client 1024)))
              (if data
                  (socket-send client data))
              (socket-close client)))
          (display "Failed to accept connection\n")))
    (display "Failed to create server\n"))
```

And a corresponding client:

```scheme
(define client (connect-to-server "localhost" 8080))
(if client
    (begin
      (socket-send client "Hello, World!")
      (let ((response (socket-recv client 1024)))
        (if response
            (display response))
        (socket-close client)))
    (display "Failed to connect to server\n"))
```

## Cross-platform Support

The project uses CMake for its build system, making it easier to build on different platforms. The socket implementation currently supports:

- macOS
- Linux
- Unix-like systems

Windows support is planned for future releases.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 