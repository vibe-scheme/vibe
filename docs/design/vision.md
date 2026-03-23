# Vibe: Vision and Goals

## Mission

Vibe is a programming language where humans and AI reason *together* about programs. Rather than requiring humans to trust code written by models, or requiring models to guess at the meaning of opaque code, Vibe makes programs fully introspectable at every level — from high-level intent down to machine instructions.

Vibe achieves this through the combination of two core ideas, both rooted in Scheme's tradition of principled abstraction:

1. A macro system that makes program structure transparent
2. A binding registry that makes program semantics transparent

## Goal 1: R7RS Small Scheme via Macro Expansion

Vibe implements the R7RS Small Scheme standard with a specific architectural constraint: every language feature that *can* be a macro *must* be a macro. Only an irreducible set of primitive forms are implemented natively (as `llvm:define-function` bitcode definitions). Everything else — `let`, `cond`, `and`, `or`, `begin`, `do`, `letrec*`, and the rest — is defined as a macro that expands to those primitives.

This means that any Vibe program can be mechanically reduced to a composition of a small number of well-understood operations. There is no hidden complexity, no "compiler magic" that transforms code in ways that are difficult to inspect. The macro expander is the single bridge between the language a programmer writes and the primitives that generate machine code.

### The Primitive Set

R7RS defines a clear boundary between primitive and derived forms. Vibe's native core consists of:

- **`define`** — creates top-level bindings; participates in internal-definition-to-`letrec*` rewriting
- **`lambda`** — creates closures (the fundamental abstraction mechanism)
- **`if`** — conditional evaluation (cannot be a function — both branches would be evaluated)
- **`set!`** — mutates an existing binding
- **`quote`** — prevents evaluation (a meta-level operation)
- **`define-syntax` / `syntax-rules`** — the macro system itself

Each of these maps to one or more `llvm:define-function` implementations in the compiler kernel. See `primitive-forms.md` for the full analysis.

### Why This Matters

When a human or an AI reads `(let ((x 1)) (+ x 2))`, they can expand it to `((lambda (x) (+ x 2)) 1)`, and from there to the primitive `lambda` + procedure-call semantics. Every step is a well-defined, inspectable transformation. There is never a point where meaning is hidden behind an opaque compiler pass.

## Goal 2: Binding Registry with Human-Language Descriptions

Every binding in a Vibe program — every global variable, every module export, every macro definition — is paired with a human-language description of what it does or stores. This registry is not documentation that lives alongside code; it is part of the language's runtime metadata.

An LLM (or any tool) can introspect a Vibe program by:

1. **Macro-expanding** any expression to see its structure in terms of primitives
2. **Looking up** each primitive and binding in the registry to understand its semantics
3. **Composing** these understandings to reason about the whole program

This is fundamentally different from "reading the source code." Source code is optimized for humans who have internalized a language's conventions. The binding registry provides a uniform, machine-queryable semantic layer that gives AI systems (and human newcomers) the same level of understanding that an experienced programmer has.

### What the Registry Contains

For each binding:

- **Name**: The symbol or identifier
- **Kind**: Variable, procedure, macro, type, etc.
- **Description**: A human-language explanation of purpose and behavior
- **Signature**: Parameter types and return type (where applicable)
- **Module**: Which library or module provides this binding
- **Expansion** (for macros): What the macro expands to, described both formally and in natural language

## How the Goals Reinforce Each Other

The macro system and the binding registry are not independent features — they form a complete introspection stack:

- **Macros** make programs *structurally* transparent: any expression can be reduced to primitives through a sequence of well-defined expansions.
- **The registry** makes primitives *semantically* transparent: each primitive and binding carries a human-readable explanation of its meaning.

Together, they close the loop: structure all the way down, meaning all the way up. An AI system can follow the macro expansion to understand *what* the code does, and consult the registry to understand *why* each piece exists.

## Downstream Possibilities

With full structural and semantic introspectability, several powerful capabilities become feasible:

### Conversational Programming

A development environment where the programmer and an AI co-author programs through conversation. The AI doesn't just generate code — it explains its reasoning by reference to macro expansions and registry entries, and the human can verify each step. Programs become *arguments*, not artifacts.

### Verified Program Transformation

Because macro expansion is deterministic and registry lookups are precise, program transformations (refactoring, optimization, migration) can be *verified* rather than trusted. An AI proposes a transformation; the human (or another AI) verifies it by checking that the expansion-level semantics are preserved.

### Self-Modifying Runtime

A future Vibe runtime could support dynamic modification — adding, replacing, or removing bindings at runtime — under human supervision. The binding registry makes this safe: every modification is accompanied by a semantic description, and the macro system ensures that the effects of the modification are transparent. This is not immediate-term work, but the architecture makes it possible.

## Current State

Vibe is fully self-hosted. The compiler (`vibe_kernel`) compiles itself from `.vibe` source files in `kernel/`. The kernel DSL provides:

- `llvm:define-function` — define LLVM functions (the core primitive)
- `llvm:define-type` — define LLVM struct types
- `llvm:declare-function` — forward-declare functions
- `llvm:call`, `llvm:icmp`, `llvm:br`, `llvm:label`, `llvm:alloca`, `llvm:store`, `llvm:load`, `llvm:gep`, etc. — LLVM instruction primitives
- `let*` — lexical binding (currently a compiler built-in, not yet a macro)

What does not yet exist:

- **Macro system** — `define-syntax` / `syntax-rules` are not yet implemented
- **Binding registry** — no metadata infrastructure yet
- **R7RS standard forms** — `define`, `lambda`, `if`, etc. are not yet implemented as Scheme-level forms; the compiler currently operates at the DSL level
- **Standard library** — no R7RS standard procedures yet

## Architecture

```
    +--------------------------------------------------+
    |              User Programs                       |
    +--------------------------------------------------+
    |           Standard Library (R7RS 6.x)            |
    +--------------------------------------------------+
    |      Derived Forms via Macros (R7RS 4.2, 5.3)    |
    |  let, cond, and, or, begin, do, letrec*, ...     |
    +--------------------------------------------------+
    |         Primitive Forms (R7RS 4.1, 5.2)          |
    |  define, lambda, if, set!, quote, define-syntax  |
    +--------------------------------------------------+
    |            Kernel DSL (llvm:*)                    |
    |  llvm:define-function, llvm:call, llvm:br, ...   |
    +--------------------------------------------------+
    |              LLVM Bitcode                         |
    +--------------------------------------------------+
    |            Native Machine Code                    |
    +--------------------------------------------------+
```

Each layer is built entirely from the layer below it. The kernel DSL is the trusted core — the only code that must be understood by reading its implementation rather than its expansion. Everything above the DSL is transparent by construction.

## Related Documents

- `primitive-forms.md` — detailed analysis of which R7RS forms must be primitive
- `r7rs-compliance.md` — section-by-section R7RS Small implementation tracker
- `cross-compilation-plan.md` — plan for multi-architecture support
