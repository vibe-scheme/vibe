/**
 * Tree-sitter grammar for Vibe
 * Vibe is a R7RS Small Scheme derivative with LLVM integration.
 * Supports: S-expressions, vertical-bar identifiers, bytevectors, vectors.
 */

module.exports = grammar({
  name: "vibe",

  extras: $ => [
    $.comment,
    $.block_comment,
    /\s/,
  ],

  rules: {
    program: $ => repeat($._form),

    _form: $ => $._datum,

    _datum: $ =>
      choice(
        $.list,
        $.improper_list,
        $.vector,
        $.bytevector,
        $.abbreviation,
        $._atom,
      ),

    list: $ =>
      seq(
        "(",
        repeat($._datum),
        ")",
      ),

    improper_list: $ =>
      seq(
        "(",
        repeat1($._datum),
        ".",
        $._datum,
        ")",
      ),

    vector: $ =>
      seq(
        "#(",
        repeat($._datum),
        ")",
      ),

    bytevector: $ =>
      seq(
        "#u8(",
        repeat($.number),
        ")",
      ),

    abbreviation: $ =>
      choice(
        seq("'", $._datum),
        seq("`", $._datum),
        seq(",@", $._datum),
        seq(",", $._datum),
      ),

    _atom: $ =>
      choice(
        $.identifier,
        $.vertical_bar_symbol,
        $.number,
        $.string,
        $.boolean,
        $.character,
      ),

    identifier: $ =>
      token(
        choice(
          seq(
            choice(
              /[a-zA-Z]|[!$%&*\/:<=>?^_~]/,
              /[+\-]/,
              /\./,
            ),
            repeat(choice(/\w/, /[!$%&*\/:<=>?^_~]/, /[+\-.]/, /@/)),
          ),
          /\.\./,
          /\.\.\./,
        ),
      ),

    vertical_bar_symbol: $ =>
      token(/\|([^|\\]|\\.)*\|/),

    number: $ =>
      token(
        choice(
          seq(optional(/[+\-]/), /[0-9]+/, optional(seq(".", /[0-9]*/)), optional(/[eE][+\-]?[0-9]+/)),
          seq(/#[bodx]/, /[0-9a-fA-F]+/),
          seq(optional(/[+\-]/), /[0-9]+/, optional(seq(".", /[0-9]*/)), /[+\-]i/),
        ),
      ),

    string: $ =>
      token(
        seq(
          '"',
          repeat(choice(/[^"\\]/, /\\./)),
          '"',
        ),
      ),

    boolean: $ =>
      choice(
        token(/#t(?:rue)?/),
        token(/#f(?:alse)?/),
      ),

    character: $ =>
      token(choice(/#\\[a-zA-Z]+/, /#\\x[0-9a-fA-F]+/, /#\\./)),

    comment: $ =>
      token(seq(";", /.*/)),

    block_comment: $ =>
      token(/#\|[\s\S]*?\|#/),
  },
});
