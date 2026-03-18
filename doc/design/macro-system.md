# Macro System Design

## Strategic Rationale: Why Macros First

The standard textbook order for implementing a Scheme is: primitive forms (`define`, `lambda`, `if`, `set!`, `quote`) first, then the macro expander, then derived forms. This makes sense when starting from nothing — you need an evaluation model before you can write a macro expander in the language itself.

Vibe is not starting from nothing. It has a working, self-hosted compiler with a capable DSL (`llvm:define-function`, `llvm:call`, `llvm:br`, `llvm:gep`, etc.) and all the infrastructure for AST manipulation (cons cells, string nodes, alist lookups, tree traversal). The macro system can be built directly on this existing substrate.

### Macros need no runtime value representation

Macros are purely compile-time AST-to-AST transformations. They operate on the parser's output (linked lists of `ASTNode` structs) and produce new AST trees that the codegen phase consumes. The infrastructure they require — `codegen_create_cons`, `codegen_create_string_node`, string comparison via `strncmp`, linked-list traversal — already exists in `kernel/codegen.vibe`.

By contrast, implementing `define` and `lambda` at the Scheme level forces immediate decisions about:

- **Value representation**: Tagged pointers? NaN-boxing? Boxed structs with a type tag? This decision pervades every part of the system.
- **Closures**: How are captured variables stored? Flat closures (copy all free variables into a struct)? Linked environment frames? Each has different performance and complexity trade-offs.
- **Memory management**: Closures that outlive their creating scope need some form of heap allocation and eventual reclamation — GC, reference counting, or arena allocation.
- **Calling convention**: How do Scheme procedures (which may have variable arity) map to LLVM functions (which have fixed signatures)?

None of these questions need answering to implement macros. Deferring them is not procrastination — it is strategic.

### The bootstrapping opportunity

Because Vibe is self-hosted, implementing macros creates a virtuous cycle:

1. **Implement the macro expander** in the current verbose `llvm:*` DSL. This is a one-time cost — painful but tractable.
2. **Self-host.** The new compiler understands macros.
3. **Define convenience macros** that abstract the kernel's most repetitive patterns (null-check-and-branch, GEP+load, alist lookup, the multi-block name-comparison pattern).
4. **Rewrite the kernel** using those macros. Self-host again. The kernel becomes dramatically more readable.
5. **Implement the Scheme-level primitives** (`define`, `lambda`, `if`, `set!`, `quote`). But now you're writing the implementation with macros available, so the code is tractable instead of overwhelming.

Step 5 is where the value representation, closure design, and memory management decisions happen — but they happen in a much more comfortable development environment.

### Macros are on the critical path

Every derived form in R7RS is a macro: `let`, `cond`, `and`, `or`, `begin`, `do`, `letrec*`, and dozens more. The macro system is needed regardless of what else is implemented. Building it first means every subsequent feature benefits from it immediately.

## Phase 1: Minimal Unhygienic Macro System

### Scope

Implement `define-syntax` with `syntax-rules` supporting literal pattern matching and template substitution. No hygienic renaming.

### Why unhygienic is acceptable initially

The immediate use case is DSL-level convenience macros in the kernel compiler itself. These macros generate `llvm:*` DSL calls — they produce LLVM names, not Scheme-level bindings. Variable capture (the problem hygiene solves) is not a concern when the expanded code operates at the LLVM IR level, where names are either global symbols or SSA values scoped to a function.

Hygiene is also the hardest part of `syntax-rules`. It requires tracking the lexical context of each identifier through expansion — marks, substitutions, or alpha-renaming. Deferring it lets us get immediate practical value from a tractable implementation.

### What Phase 1 supports

- **Pattern variables**: `(syntax-rules () ((name pattern ...) template))` — match subforms and bind them to pattern variables for use in the template
- **Literal matching**: `(syntax-rules (lit1 lit2) ...)` — require certain positions to match specific identifiers
- **Ellipsis** (`...`): In patterns, match zero or more repetitions of the preceding sub-pattern. In templates, replicate the preceding template element for each match.
- **Nested patterns**: Match structure at arbitrary depth
- **Multiple clauses**: Tried in order; the first matching clause wins

### What Phase 1 does NOT support

- **Hygienic renaming** — deferred to Phase 3
- **`syntax-case`** or procedural macros — not part of R7RS Small
- **`let-syntax` / `letrec-syntax`** — local macro bindings, deferred until needed
- **`syntax-error`** — can be added trivially later

### Example: what Phase 1 enables

```scheme
;; Abstract the GEP + load pattern for struct field access
(define-syntax with-field
  (syntax-rules ()
    ((with-field struct type idx result-type)
     (llvm:load (llvm:gep type struct 0 idx) result-type))))

;; Abstract null-check-and-branch
(define-syntax if-null
  (syntax-rules ()
    ((if-null ptr then-label else-label)
     (llvm:br (llvm:icmp 'eq ptr (llvm:const-null |i8*|)) then-label else-label))))

;; Abstract the repeated binary operation pattern (~50 lines each currently)
(define-syntax define-dsl-binop
  (syntax-rules ()
    ((define-dsl-binop name llvm-builder)
     (llvm:define-function (name (cg |%CodeGen*|) (args |%ASTNode*|)) |i8*|
       (let* ((first-arg (llvm:load (llvm:gep |%ASTNode| args 0 4) |%ASTNode*|))
              (rest (llvm:load (llvm:gep |%ASTNode| args 0 5) |%ASTNode*|))
              (second-arg (llvm:load (llvm:gep |%ASTNode| rest 0 4) |%ASTNode*|))
              (lhs (llvm:call codegen_eval_dsl_expr cg first-arg))
              (rhs (llvm:call codegen_eval_dsl_expr cg second-arg)))
         (llvm:ret (llvm:call llvm-builder lhs rhs "")))))))
```

## Architectural Changes

### New compiler pipeline

```
Source (.vibe) --> Lexer --> Parser --> Expander --> Codegen --> LLVM bitcode
```

The expander is a new phase inserted between the parser and codegen. It receives the full AST from the parser, performs macro expansion (repeatedly, until no macros match), and passes the fully-expanded AST to codegen. Codegen sees only expanded forms — it never encounters `define-syntax` or macro invocations.

### New module: `kernel/expander.vibe`

The expander module implements:

1. **Macro environment**: A map from keyword names to transformer specs (the parsed `syntax-rules` clauses). Stored as an alist of `(name . transformer)` pairs, using the same cons-cell infrastructure that `codegen.vibe` uses for its binding lists.

2. **Top-level `define-syntax` handling**: When the expander encounters a `(define-syntax name (syntax-rules ...))` form, it parses the clauses and registers the transformer in the macro environment. The form is consumed — it does not pass through to codegen.

3. **Expansion walk**: For each list form in the AST, the expander checks whether the head (car) is a keyword in the macro environment. If so, it applies the pattern matcher against each clause in order. On the first match, it instantiates the template with the matched bindings and replaces the original form. Expansion is recursive — the result of a macro expansion is itself subject to further expansion.

4. **Pattern matcher**: Walks a `syntax-rules` pattern and an input form in parallel. Literal identifiers must match exactly. Pattern variables bind to the corresponding input sub-form. Ellipsis patterns match zero or more repetitions. Returns either a set of bindings (on match) or failure.

5. **Template instantiation**: Walks a template, replacing pattern variables with their bound values and replicating ellipsis-marked sub-templates for each repetition. Produces a new AST tree.

6. **Fixed-point expansion**: The expander repeats until no more expansions occur in a pass, or until a configurable depth limit is reached (to detect infinite expansion loops).

### Utility extraction: `kernel/util.vibe`

Currently `kernel/codegen.vibe` contains ~7600 lines, many of which are general-purpose AST and data-structure utilities rather than code generation logic. The expander needs these same utilities. Rather than duplicating them or creating brittle cross-module dependencies, extract the shared functions into a new `kernel/util.vibe` module.

Functions to extract from `codegen.vibe`:

| Current name | New name | Purpose |
|---|---|---|
| `codegen_create_cons` | `create_cons` | Construct a cons cell (LIST ASTNode with car/cdr) |
| `codegen_create_pair` | `create_pair` | Construct a pair (cons cell with cdr wrapper) |
| `codegen_create_string_node` | `create_string_node` | Construct a string-valued ATOM ASTNode |
| `codegen_create_pointer_node` | `create_pointer_node` | Wrap a raw pointer in an ASTNode |
| `codegen_create_int_node` | `create_int_node` | Construct an integer-valued ASTNode |
| `codegen_parse_int_string` | `parse_int_string` | Parse a decimal integer from a string |
| `codegen_parse_int_from_ast` | `parse_int_from_ast` | Extract an integer from an ATOM ASTNode |
| `codegen_extract_quoted_atom` | `extract_quoted_atom` | Extract the atom name/length from a quote form |
| `codegen_is_array_type` | `is_array_type` | Check if a type string has array syntax |
| `codegen_append` | `buffer_append` | Append a string to a dynamically-sized buffer |
| `codegen_format_number` | `format_number` | Convert an integer to a single-digit string |
| `codegen_int_to_string` | `int_to_string` | Convert an integer to a decimal string |
| `codegen_map_predicate_string` | `map_predicate_string` | Map a predicate name to its LLVM icmp code |

Both `codegen.vibe` and `expander.vibe` reference these via `llvm:declare-function`. The build system (`CMakeLists.txt`) compiles `util.vibe` and links it alongside the other modules.

After extraction, `codegen.vibe` retains the functions that are specific to LLVM code generation: DSL instruction handlers (`codegen_dsl_add`, `codegen_dsl_br`, etc.), type resolution (`codegen_resolve_type_string`), function/constant/type registries (`codegen_store_type`, `codegen_get_type`, etc.), IR text generation, bitcode writing, and the main `codegen_eval_dsl_expr` dispatch.

### Integration with `kernel/main.vibe`

`main.vibe` currently drives the pipeline as: parse each top-level form, then pass it to codegen. After this change, the flow becomes: parse each top-level form, pass it to the expander, then pass the expanded form to codegen.

The expander is initialized once per compilation unit (to maintain the macro environment across top-level forms within a file). `define-syntax` forms encountered early in a file are available for expansion of forms later in the same file.

## Phase 2: Kernel Rewrite Using Macros

Once Phase 1 is complete and self-hosted, define convenience macros that eliminate the kernel's most repetitive patterns. The goal is to make the kernel readable enough that implementing Scheme-level primitives (Phase 4) is tractable.

### Target macros

- **`with-field`**: Abstract the GEP + load pattern for struct field access. Eliminates the two-step `(llvm:gep ...) (llvm:load ...)` idiom that appears hundreds of times.
- **`if-null`**: Abstract the null-check + conditional-branch + two-label pattern. The kernel is full of `(llvm:icmp 'eq ptr (llvm:const-null ...))` followed by `(llvm:br ...)`.
- **`string-match`**: Abstract the strlen + strncmp + branch pattern used pervasively in name lookups and dispatch.
- **`define-dsl-binop`**: Abstract the ~50-line boilerplate repeated for every binary LLVM operation (`codegen_dsl_add`, `codegen_dsl_sub`, `codegen_dsl_mul`, `codegen_dsl_and`, `codegen_dsl_or`, `codegen_dsl_urem`, `codegen_dsl_udiv`). These all have identical structure differing only in which LLVM builder function they call.
- **`alist-lookup`**: Abstract the multi-block linked-list traversal + name comparison pattern used in `codegen_get_type`, `codegen_get_llvm_function`, `codegen_dsl_resolve_local`, `codegen_dsl_resolve_param`, `codegen_get_constant`, `codegen_get_function_type`, etc.

### Process

The kernel rewrite proceeds module by module, self-hosting after each change to verify correctness:

1. Define the macros in a shared location (possibly a prelude file or at the top of each module)
2. Rewrite `kernel/util.vibe` functions using macros
3. Rewrite `kernel/codegen.vibe` — the largest module and biggest beneficiary
4. Rewrite `kernel/main.vibe`, `kernel/parser.vibe`, `kernel/lexer.vibe` as applicable
5. Self-host the fully rewritten kernel to confirm the compiler can still build itself

## Phase 3: Full Hygienic `syntax-rules`

Hygiene ensures that macro-introduced bindings do not accidentally capture user-level bindings, and vice versa. This is essential for R7RS compliance (Section 4.3) and for writing correct macros at the Scheme level (as opposed to the DSL level, where it is less critical).

### What hygiene requires

The classic approach (Dybvig et al., "Syntactic Abstraction in Scheme") uses a system of **marks** and **substitutions**:

- Each macro expansion step applies a unique mark to all identifiers in the expanded output.
- When resolving an identifier, the expander considers both the name and its marks to determine which binding it refers to.
- Two identifiers with the same name but different marks are distinct — preventing capture.

Alternative approaches include explicit alpha-renaming and the "sets of scopes" model (Flatt, "Binding as Sets of Scopes"). The detailed design will be chosen when Phase 2 is complete, informed by the experience of implementing and using the unhygienic system.

### R7RS compliance

Full hygiene brings Vibe to compliance with R7RS Section 4.3.2 (`syntax-rules`). Combined with `let-syntax` and `letrec-syntax` (Section 4.3.1), this completes the macro subsystem of R7RS Small.

## Related Documents

- `vision.md` — Vibe's mission and how the macro system supports it
- `primitive-forms.md` — which R7RS forms are primitive vs. derived via macros
- `r7rs-compliance.md` — tracking implementation progress, including macros
