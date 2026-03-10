# tree-sitter-vibe

Tree-sitter grammar for the [Vibe](https://github.com/vibe-lang/vibe) language.

## Building

```bash
npm install
npx tree-sitter generate
```

To build the Node.js binding (optional, for use with Emacs tree-sitter):

```bash
npm run build
```

## Testing

```bash
npx tree-sitter test
```

To parse a file:

```bash
npx tree-sitter parse path/to/file.vibe
```

## Grammar Scope

The grammar supports:

- S-expressions (lists, improper lists)
- Identifiers (including R7RS peculiar identifiers like `.str.hello`)
- Vertical-bar delimited symbols: `|i8*|`, `|%ASTNode*|`, `|[12 x i8]|`
- Numbers, strings, booleans (`#t`, `#f`), characters (`#\x`)
- Vectors: `#(datum ...)`
- Bytevectors: `#u8(number ...)`
- Abbreviations: `'`, `` ` ``, `,`, `,@`
- Comments: `;` line comments, `#| ... |#` block comments
