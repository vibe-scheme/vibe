# Primitive vs. Derived Forms in R7RS Scheme

## Overview

R7RS Small Scheme distinguishes between *primitive* (or *essential*) syntax and *derived* syntax. Derived forms are defined in Section 7.3 of the standard as macros over the primitives. Vibe's architecture depends on this distinction: primitives are implemented as `llvm:define-function` bitcode in the compiler kernel, while derived forms are macros that expand to them.

This document analyzes which forms must be primitive and why, catalogs the derived forms and their expansions, and maps primitives to their Vibe kernel implementations.

## The Primitive Set

The following forms cannot be implemented as macros and must be provided natively by the compiler:

| Form | Category | R7RS Section |
|------|----------|-------------|
| `define` | Definition | 5.2 |
| `lambda` | Expression | 4.1.4 |
| `if` | Expression | 4.1.5 |
| `set!` | Expression | 4.1.6 |
| `quote` | Expression | 4.1.2 |
| `define-syntax` | Definition | 5.4 |
| `syntax-rules` | Expression | 4.3.2 |

Additionally, **variable reference** (4.1.1) and **procedure call** (4.1.3) are primitive expression types, but they are syntactic rules (an identifier evaluates to its binding; a list whose operator is a procedure is a call) rather than named forms.

## Why Each Primitive Must Be Primitive

### `define` (Section 5.2)

`define` cannot be a macro for three independent reasons:

1. **Not an expression.** R7RS makes a grammatical distinction between definitions and expressions (Section 7.1). Macros defined via `syntax-rules` transform expressions. `define` is a `<definition>`, not an `<expression>`. There is no expression form it could expand into that would have the same effect.

2. **Top-level `define` is irreducible.** At the top level, `(define x expr)` creates a new binding in the environment. This is the primitive operation for introducing names. `set!` requires the binding to already exist; `lambda` creates local scope, not top-level bindings. There is nothing more fundamental.

3. **Internal definitions require body-level restructuring.** R7RS Section 5.3.2 specifies that internal definitions (at the start of a `<body>`) are equivalent to `letrec*`. This transformation is not a local rewrite of each `define` — it requires scanning the entire body, collecting all leading definitions, and restructuring them as a single `letrec*`. This is an expander-level operation, not a per-form macro.

R7RS confirms this: Section 7.3 ("Derived expression types") lists the forms that can be defined as macros. `define` is absent.

**Vibe implementation**: Top-level `define` maps to an LLVM global definition (function or variable). Internal `define` is rewritten to `letrec*` by the expander.

**Note on syntactic sugar**: The shorthand `(define (f x ...) body ...)` desugars to `(define f (lambda (x ...) body ...))`. This is a trivial rewrite the compiler performs, not a separate primitive.

**Docstrings**: Vibe adopts the Python/Clojure convention for documentation strings. In a `define` body with two or more expressions, if the first expression is a string literal, it is treated as a documentation string and registered in the binding registry rather than evaluated. This is syntactically valid R7RS (a string literal is a valid expression, and in a multi-expression body its value would be discarded anyway). The compiler can detect this because the parser tags string literals with a distinct `atom_type`, so the `define` implementation can distinguish a leading docstring from other expressions without requiring `syntax-rules` pattern matching. Single-expression bodies are unambiguous — the expression is always the return value.

```scheme
(define (add1 x)
  "Add one to x."
  (+ x 1))
```

### `lambda` (Section 4.1.4)

`lambda` is the fundamental abstraction mechanism. It creates a closure: a procedure paired with its lexical environment. Every other binding form in Scheme (`let`, `let*`, `letrec`, `letrec*`, named `let`, `do`) ultimately reduces to `lambda`.

`lambda` cannot be a macro because there is no simpler form that creates closures. It IS the form that creates closures.

**Vibe implementation**: `lambda` generates an LLVM function definition. When the lambda captures free variables, it additionally generates a closure struct (environment + function pointer) and the corresponding allocation code.

### `if` (Section 4.1.5)

`if` is the primitive conditional. It evaluates its test expression, then evaluates *exactly one* of its two branches based on the result.

`if` cannot be a function call because function calls evaluate all arguments before the call. Both branches would be evaluated, which is incorrect and potentially non-terminating. It cannot be expressed in terms of any other primitive.

**Vibe implementation**: `if` generates an LLVM conditional branch (`br i1`) with two basic blocks for the consequent and alternative, merging at a join block.

### `set!` (Section 4.1.6)

`set!` mutates an existing binding. It changes the value that a variable refers to in the environment.

`set!` cannot be a macro because no other form performs mutation of bindings. `define` creates new bindings; `set!` modifies existing ones. These are distinct operations on the environment.

**Vibe implementation**: `set!` generates an LLVM `store` instruction to the variable's alloca (or, for globals, to the global's storage).

### `quote` (Section 4.1.2)

`quote` returns its argument as a datum without evaluating it. `'(+ 1 2)` yields the list `(+ 1 2)`, not `3`.

`quote` cannot be a macro (or a function) because any macro expansion or function call would cause its argument to be evaluated first — defeating the purpose. The suppression of evaluation is inherently a meta-level operation that only the compiler can provide.

**Vibe implementation**: `quote` generates LLVM constants. Quoted numbers and strings become LLVM literal constants; quoted symbols become interned symbol references; quoted lists become compile-time-constructed cons cell chains.

### `define-syntax` and `syntax-rules` (Sections 5.4, 4.3.2)

`define-syntax` binds a keyword to a macro transformer. `syntax-rules` defines a pattern-matching transformer. Together, they ARE the macro system.

The macro system cannot itself be a macro — that would be circular. `define-syntax` and `syntax-rules` must be understood by the compiler/expander natively.

**Vibe implementation**: `define-syntax` registers a macro in the compile-time macro environment. `syntax-rules` compiles pattern/template pairs into a transformation function that the expander invokes during macro expansion.

**Macro documentation (contrast with `define` docstrings)**:

- **Not inside `syntax-rules`**: Each clause after the literals list is a pattern/template pair. A “documentation clause” is not viable; a string in pattern position would be a real pattern, not prose.
- **R7RS-safe transformer specs**: The second subform of `define-syntax` may be any `<expression>` whose value is a transformer. A doc string can sit in a sequencing wrapper evaluated once at install time, e.g. `(begin "…" (syntax-rules …))`, where the string’s value is discarded and the last subform yields the transformer. Procedural transformers (`lambda` of syntax) are a separate story (doc as first body expression would run per expansion unless stripped).
- **Portable `define-vibe-syntax` sketch**: A user-level macro can expand to `(define-syntax name transformer)` and match a doc subform that is **omitted from the template** — syntactically fine R7RS-style code, but the doc is not attached unless something else records it.
- **Kernel today**: **`kernel/macros.vibe`** defines **`define-vibe-syntax`** as that sketch (a normal macro: it expands to **`define-syntax`**). The shared **`vibe:*`** helpers are written with top-level **`define-syntax`** so the bootstrap/seed compiler installs them directly; each has a preceding **`;; Registry (planned):`** comment with the same text a future registry would record. You can use **`define-vibe-syntax`** in your own prelude once a top-level form that expands to **`define-syntax`** is fully supported end-to-end (see **macro-system.md**); it is not required for the kernel prelude today.
- **Planned Vibe form**: The expander may eventually treat **`define-vibe-syntax`** (or any macro that expands to **`define-syntax`**) as a first-class definition boundary for documentation; until then, `define-syntax` plus comments is the supported bootstrap path.

**Macro registry (planned) — kernel `vibe:*` entries**

When the binding/doc registry exists, these entries (name → exact documentation text; kept in sync with **`;; Registry (planned):`** lines in **`kernel/macros.vibe`**) should be registered as macro documentation:

| Macro | Docstring (registry text) |
|-------|---------------------------|
| `vibe:ast-null?` | `True when ptr is a null ASTNode pointer (empty list or missing node).` |
| `vibe:ast-some?` | `True when ptr is a non-null ASTNode pointer.` |
| `vibe:ptr-null?` | `True when ptr is a null opaque pointer (LLVM uses i8* for opaque handles).` |
| `vibe:ptr-some?` | `True when ptr is a non-null opaque pointer (LLVM uses i8* for opaque handles).` |
| `vibe:len-zero?` | `True when len is zero (i64 lengths: token, lexer source, AST value_len, paths).` |
| `vibe:ptr-empty?` | `True when ptr is null i8* or len is zero (invalid byte span / C-string).` |
| `vibe:node-empty?` | `True when AST node's value pointer is null or value_len is zero.` |
| `vibe:node-kind?` | `True when node's type field matches literal atom (0) or list (1).` |
| `vibe:atom-type?` | `True when node's atom_type field matches literal number/string/bytevector/pointer.` |

Keep this table in sync with **`kernel/macros.vibe`** when adding or editing documented kernel macros.
- **Compile unit today**: Each kernel `.vibe` file is compiled to its own bitcode module (see the `compile_*` rules in `CMakeLists.txt`), so the macro environment is **per file** for a single run of the compiler on that source.
- **Libraries deferred**: R7RS libraries and related packaging are out of scope until the compiler kernel is farther along and work shifts toward full R7RS support. The text above describes the current constraint and possible evolution, not a settled module design.
- **Future direction (explore later; not a commitment)**: Sharing macros across kernel files without deciding library semantics might use **multiple paths as one logical compilation unit** — for example, the driver accepting a **list of file names** and **concatenating** their contents in memory before lex/parse/expand, so early `define-syntax` forms are visible to the rest of that unit. This is a **next step to evaluate**, not a current implementation task.

## Derived Forms Catalog

R7RS Section 7.3 provides macro definitions for all derived forms. The following table summarizes each derived form and what it reduces to:

| Derived Form | Expands To | R7RS Section |
|---|---|---|
| `cond` | nested `if` | 4.2.1 |
| `case` | `let` + `cond` (with `eqv?` tests) | 4.2.1 |
| `and` | `if` (short-circuit) | 4.2.1 |
| `or` | `let` + `if` (short-circuit) | 4.2.1 |
| `when` | `if` + `begin` (no alternative) | 4.2.1 |
| `unless` | `if` + `begin` (negated) | 4.2.1 |
| `let` | `lambda` + procedure call | 4.2.2 |
| `let*` | nested `let` | 4.2.2 |
| `letrec` | `let` + `set!` + internal `lambda` | 4.2.2 |
| `letrec*` | `let` + `set!` (sequential) | 4.2.2 |
| `let-values` | `call-with-values` + `lambda` | 4.2.2 |
| `let*-values` | nested `let-values` | 4.2.2 |
| `begin` | sequenced `lambda` body | 4.2.3 |
| `do` | `letrec` + `if` | 4.2.4 |
| `delay` | `make-promise` + `lambda` | 4.2.5 |
| `delay-force` | `make-promise` + `lambda` | 4.2.5 |
| `force` | procedure (not syntax) | 4.2.5 |
| `make-promise` | procedure (not syntax) | 4.2.5 |
| `parameterize` | `dynamic-wind` + mutation | 4.2.6 |
| `guard` | `call/cc` + `cond` + `raise-continuable` | 4.2.7 |
| `case-lambda` | `lambda` + `cond` on argument count | 4.2.9 |
| `quasiquote` | `list`, `cons`, `append`, `quote` | 4.2.8 |

**Key insight**: Every derived form eventually bottoms out at the six primitive forms plus procedure calls. The longest expansion chain is something like `do` -> `letrec` -> `let` + `set!` -> `lambda` + `set!`.

## Open Questions

### `define-record-type` (Section 5.5)

R7RS defines `define-record-type` as a definition form. It could in principle be implemented as a macro that expands to a set of `define` forms (constructor, predicate, field accessors, field mutators). However, doing so efficiently may require compiler support for struct layout. This is an implementation decision to be made when records are implemented.

### `include` and `include-ci` (Section 4.1.7)

These read and splice source files at expansion time. They require filesystem access during macro expansion, which makes them somewhat special. They could be implemented as macros if the macro expander has file-reading capability, or they could be handled specially by the compiler. Either approach is compatible with Vibe's architecture.

### `syntax-error` (Section 4.3.3)

`syntax-error` signals an error during macro expansion. It could be a macro (that expands to something the expander rejects) or a primitive recognized by the expander. The choice has no architectural impact.

## Mapping to Vibe's LLVM Substrate

Each primitive form maps to specific patterns of LLVM code generation:

```
Primitive Form          LLVM Generation Pattern
─────────────          ──────────────────────────────
define (top-level)  →  global function/variable definition
define (internal)   →  letrec* rewriting (expander phase)
lambda              →  function definition + optional closure struct
if                  →  br i1 %test, label %then, label %else
set!                →  store to alloca or global
quote               →  compile-time constants (ints, strings, symbol
                       refs, cons cell chains)
define-syntax       →  compile-time macro environment registration
syntax-rules        →  pattern-matching transformer compilation
```

The compiler kernel (`kernel/codegen.vibe`) is responsible for these translations. The current kernel DSL (`llvm:define-function`, `llvm:call`, `llvm:br`, etc.) provides the building blocks. Implementing the Scheme-level primitives means writing codegen handlers that map Scheme syntax to sequences of DSL operations.

## Related Documents

- `vision.md` — Vibe's mission and how the primitive/macro boundary supports it
- `r7rs-compliance.md` — tracking implementation progress
