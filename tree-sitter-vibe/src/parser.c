#include <tree_sitter/parser.h>

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#endif

#define LANGUAGE_VERSION 14
#define STATE_COUNT 44
#define LARGE_STATE_COUNT 36
#define SYMBOL_COUNT 32
#define ALIAS_COUNT 0
#define TOKEN_COUNT 19
#define EXTERNAL_TOKEN_COUNT 0
#define FIELD_COUNT 0
#define MAX_ALIAS_SEQUENCE_LENGTH 5
#define PRODUCTION_ID_COUNT 1

enum {
  anon_sym_LPAREN = 1,
  anon_sym_RPAREN = 2,
  anon_sym_DOT = 3,
  anon_sym_POUND_LPAREN = 4,
  anon_sym_POUNDu8_LPAREN = 5,
  anon_sym_SQUOTE = 6,
  anon_sym_BQUOTE = 7,
  anon_sym_COMMA_AT = 8,
  anon_sym_COMMA = 9,
  sym_identifier = 10,
  sym_vertical_bar_symbol = 11,
  sym_number = 12,
  sym_string = 13,
  aux_sym_boolean_token1 = 14,
  aux_sym_boolean_token2 = 15,
  sym_character = 16,
  sym_comment = 17,
  sym_block_comment = 18,
  sym_program = 19,
  sym__form = 20,
  sym__datum = 21,
  sym_list = 22,
  sym_improper_list = 23,
  sym_vector = 24,
  sym_bytevector = 25,
  sym_abbreviation = 26,
  sym__atom = 27,
  sym_boolean = 28,
  aux_sym_program_repeat1 = 29,
  aux_sym_list_repeat1 = 30,
  aux_sym_bytevector_repeat1 = 31,
};

static const char * const ts_symbol_names[] = {
  [ts_builtin_sym_end] = "end",
  [anon_sym_LPAREN] = "(",
  [anon_sym_RPAREN] = ")",
  [anon_sym_DOT] = ".",
  [anon_sym_POUND_LPAREN] = "#(",
  [anon_sym_POUNDu8_LPAREN] = "#u8(",
  [anon_sym_SQUOTE] = "'",
  [anon_sym_BQUOTE] = "`",
  [anon_sym_COMMA_AT] = ",@",
  [anon_sym_COMMA] = ",",
  [sym_identifier] = "identifier",
  [sym_vertical_bar_symbol] = "vertical_bar_symbol",
  [sym_number] = "number",
  [sym_string] = "string",
  [aux_sym_boolean_token1] = "boolean_token1",
  [aux_sym_boolean_token2] = "boolean_token2",
  [sym_character] = "character",
  [sym_comment] = "comment",
  [sym_block_comment] = "block_comment",
  [sym_program] = "program",
  [sym__form] = "_form",
  [sym__datum] = "_datum",
  [sym_list] = "list",
  [sym_improper_list] = "improper_list",
  [sym_vector] = "vector",
  [sym_bytevector] = "bytevector",
  [sym_abbreviation] = "abbreviation",
  [sym__atom] = "_atom",
  [sym_boolean] = "boolean",
  [aux_sym_program_repeat1] = "program_repeat1",
  [aux_sym_list_repeat1] = "list_repeat1",
  [aux_sym_bytevector_repeat1] = "bytevector_repeat1",
};

static const TSSymbol ts_symbol_map[] = {
  [ts_builtin_sym_end] = ts_builtin_sym_end,
  [anon_sym_LPAREN] = anon_sym_LPAREN,
  [anon_sym_RPAREN] = anon_sym_RPAREN,
  [anon_sym_DOT] = anon_sym_DOT,
  [anon_sym_POUND_LPAREN] = anon_sym_POUND_LPAREN,
  [anon_sym_POUNDu8_LPAREN] = anon_sym_POUNDu8_LPAREN,
  [anon_sym_SQUOTE] = anon_sym_SQUOTE,
  [anon_sym_BQUOTE] = anon_sym_BQUOTE,
  [anon_sym_COMMA_AT] = anon_sym_COMMA_AT,
  [anon_sym_COMMA] = anon_sym_COMMA,
  [sym_identifier] = sym_identifier,
  [sym_vertical_bar_symbol] = sym_vertical_bar_symbol,
  [sym_number] = sym_number,
  [sym_string] = sym_string,
  [aux_sym_boolean_token1] = aux_sym_boolean_token1,
  [aux_sym_boolean_token2] = aux_sym_boolean_token2,
  [sym_character] = sym_character,
  [sym_comment] = sym_comment,
  [sym_block_comment] = sym_block_comment,
  [sym_program] = sym_program,
  [sym__form] = sym__form,
  [sym__datum] = sym__datum,
  [sym_list] = sym_list,
  [sym_improper_list] = sym_improper_list,
  [sym_vector] = sym_vector,
  [sym_bytevector] = sym_bytevector,
  [sym_abbreviation] = sym_abbreviation,
  [sym__atom] = sym__atom,
  [sym_boolean] = sym_boolean,
  [aux_sym_program_repeat1] = aux_sym_program_repeat1,
  [aux_sym_list_repeat1] = aux_sym_list_repeat1,
  [aux_sym_bytevector_repeat1] = aux_sym_bytevector_repeat1,
};

static const TSSymbolMetadata ts_symbol_metadata[] = {
  [ts_builtin_sym_end] = {
    .visible = false,
    .named = true,
  },
  [anon_sym_LPAREN] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_RPAREN] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_DOT] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_POUND_LPAREN] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_POUNDu8_LPAREN] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_SQUOTE] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_BQUOTE] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_COMMA_AT] = {
    .visible = true,
    .named = false,
  },
  [anon_sym_COMMA] = {
    .visible = true,
    .named = false,
  },
  [sym_identifier] = {
    .visible = true,
    .named = true,
  },
  [sym_vertical_bar_symbol] = {
    .visible = true,
    .named = true,
  },
  [sym_number] = {
    .visible = true,
    .named = true,
  },
  [sym_string] = {
    .visible = true,
    .named = true,
  },
  [aux_sym_boolean_token1] = {
    .visible = false,
    .named = false,
  },
  [aux_sym_boolean_token2] = {
    .visible = false,
    .named = false,
  },
  [sym_character] = {
    .visible = true,
    .named = true,
  },
  [sym_comment] = {
    .visible = true,
    .named = true,
  },
  [sym_block_comment] = {
    .visible = true,
    .named = true,
  },
  [sym_program] = {
    .visible = true,
    .named = true,
  },
  [sym__form] = {
    .visible = false,
    .named = true,
  },
  [sym__datum] = {
    .visible = false,
    .named = true,
  },
  [sym_list] = {
    .visible = true,
    .named = true,
  },
  [sym_improper_list] = {
    .visible = true,
    .named = true,
  },
  [sym_vector] = {
    .visible = true,
    .named = true,
  },
  [sym_bytevector] = {
    .visible = true,
    .named = true,
  },
  [sym_abbreviation] = {
    .visible = true,
    .named = true,
  },
  [sym__atom] = {
    .visible = false,
    .named = true,
  },
  [sym_boolean] = {
    .visible = true,
    .named = true,
  },
  [aux_sym_program_repeat1] = {
    .visible = false,
    .named = false,
  },
  [aux_sym_list_repeat1] = {
    .visible = false,
    .named = false,
  },
  [aux_sym_bytevector_repeat1] = {
    .visible = false,
    .named = false,
  },
};

static const TSSymbol ts_alias_sequences[PRODUCTION_ID_COUNT][MAX_ALIAS_SEQUENCE_LENGTH] = {
  [0] = {0},
};

static const uint16_t ts_non_terminal_alias_map[] = {
  0,
};

static const TSStateId ts_primary_state_ids[STATE_COUNT] = {
  [0] = 0,
  [1] = 1,
  [2] = 2,
  [3] = 3,
  [4] = 2,
  [5] = 5,
  [6] = 6,
  [7] = 7,
  [8] = 8,
  [9] = 9,
  [10] = 8,
  [11] = 9,
  [12] = 7,
  [13] = 6,
  [14] = 14,
  [15] = 14,
  [16] = 16,
  [17] = 16,
  [18] = 18,
  [19] = 19,
  [20] = 20,
  [21] = 18,
  [22] = 22,
  [23] = 23,
  [24] = 24,
  [25] = 22,
  [26] = 23,
  [27] = 19,
  [28] = 28,
  [29] = 29,
  [30] = 30,
  [31] = 30,
  [32] = 20,
  [33] = 29,
  [34] = 24,
  [35] = 28,
  [36] = 36,
  [37] = 36,
  [38] = 38,
  [39] = 39,
  [40] = 38,
  [41] = 41,
  [42] = 42,
  [43] = 42,
};

static inline bool sym_identifier_character_set_1(int32_t c) {
  return (c < '<'
    ? (c < '*'
      ? (c < '$'
        ? c == '!'
        : c <= '&')
      : (c <= '*' || (c < ':'
        ? c == '/'
        : c <= ':')))
    : (c <= 'D' || (c < 'a'
      ? (c < '^'
        ? (c >= 'F' && c <= 'Z')
        : c <= '_')
      : (c <= 'd' || (c < '~'
        ? (c >= 'f' && c <= 'z')
        : c <= '~')))));
}

static inline bool sym_identifier_character_set_2(int32_t c) {
  return (c < '<'
    ? (c < '*'
      ? (c < '$'
        ? c == '!'
        : c <= '&')
      : (c <= '*' || (c < ':'
        ? (c >= '.' && c <= '/')
        : c <= ':')))
    : (c <= 'D' || (c < 'a'
      ? (c < '^'
        ? (c >= 'F' && c <= 'Z')
        : c <= '_')
      : (c <= 'd' || (c < '~'
        ? (c >= 'f' && c <= 'z')
        : c <= '~')))));
}

static inline bool sym_identifier_character_set_3(int32_t c) {
  return (c < ':'
    ? (c < '*'
      ? (c < '$'
        ? c == '!'
        : c <= '&')
      : (c <= '*' || (c >= '.' && c <= '/')))
    : (c <= ':' || (c < 'a'
      ? (c < '^'
        ? (c >= '<' && c <= 'Z')
        : c <= '_')
      : (c <= 'z' || c == '~'))));
}

static inline bool sym_identifier_character_set_4(int32_t c) {
  return (c < ':'
    ? (c < '*'
      ? (c < '$'
        ? c == '!'
        : c <= '&')
      : (c <= '+' || (c >= '-' && c <= '/')))
    : (c <= ':' || (c < 'a'
      ? (c < '^'
        ? (c >= '<' && c <= 'Z')
        : c <= '_')
      : (c <= 'z' || c == '~'))));
}

static inline bool sym_identifier_character_set_5(int32_t c) {
  return (c < '<'
    ? (c < '*'
      ? (c < '$'
        ? c == '!'
        : c <= '&')
      : (c <= '+' || (c >= '-' && c <= ':')))
    : (c <= 'Z' || (c < 'j'
      ? (c < 'a'
        ? (c >= '^' && c <= '_')
        : c <= 'h')
      : (c <= 'z' || c == '~'))));
}

static bool ts_lex(TSLexer *lexer, TSStateId state) {
  START_LEXER();
  eof = lexer->eof(lexer);
  switch (state) {
    case 0:
      if (eof) ADVANCE(24);
      if (lookahead == '"') ADVANCE(1);
      if (lookahead == '#') ADVANCE(4);
      if (lookahead == '\'') ADVANCE(30);
      if (lookahead == '(') ADVANCE(25);
      if (lookahead == ')') ADVANCE(26);
      if (lookahead == ',') ADVANCE(33);
      if (lookahead == '.') ADVANCE(27);
      if (lookahead == ';') ADVANCE(58);
      if (lookahead == '`') ADVANCE(31);
      if (lookahead == '|') ADVANCE(7);
      if (('+' <= lookahead && lookahead <= '-')) ADVANCE(39);
      if (lookahead == '\t' ||
          lookahead == '\n' ||
          lookahead == '\r' ||
          lookahead == ' ') SKIP(0)
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(45);
      if (('!' <= lookahead && lookahead <= '?') ||
          ('A' <= lookahead && lookahead <= 'Z') ||
          ('^' <= lookahead && lookahead <= 'z') ||
          lookahead == '~') ADVANCE(42);
      END_STATE();
    case 1:
      if (lookahead == '"') ADVANCE(49);
      if (lookahead == '\\') ADVANCE(21);
      if (lookahead != 0) ADVANCE(1);
      END_STATE();
    case 2:
      if (lookahead == '#') ADVANCE(59);
      END_STATE();
    case 3:
      if (lookahead == '#') ADVANCE(15);
      if (lookahead == ')') ADVANCE(26);
      if (lookahead == ';') ADVANCE(58);
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(18);
      if (lookahead == '\t' ||
          lookahead == '\n' ||
          lookahead == '\r' ||
          lookahead == ' ') SKIP(3)
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(45);
      END_STATE();
    case 4:
      if (lookahead == '(') ADVANCE(28);
      if (lookahead == '\\') ADVANCE(14);
      if (lookahead == 'f') ADVANCE(53);
      if (lookahead == 't') ADVANCE(51);
      if (lookahead == 'u') ADVANCE(6);
      if (lookahead == '|') ADVANCE(16);
      if (lookahead == 'b' ||
          lookahead == 'd' ||
          lookahead == 'o' ||
          lookahead == 'x') ADVANCE(20);
      END_STATE();
    case 5:
      if (lookahead == '(') ADVANCE(29);
      END_STATE();
    case 6:
      if (lookahead == '8') ADVANCE(5);
      END_STATE();
    case 7:
      if (lookahead == '\\') ADVANCE(22);
      if (lookahead == '|') ADVANCE(43);
      if (lookahead != 0) ADVANCE(7);
      END_STATE();
    case 8:
      if (lookahead == 'e') ADVANCE(50);
      END_STATE();
    case 9:
      if (lookahead == 'e') ADVANCE(52);
      END_STATE();
    case 10:
      if (lookahead == 'i') ADVANCE(44);
      END_STATE();
    case 11:
      if (lookahead == 'l') ADVANCE(12);
      END_STATE();
    case 12:
      if (lookahead == 's') ADVANCE(9);
      END_STATE();
    case 13:
      if (lookahead == 'u') ADVANCE(8);
      END_STATE();
    case 14:
      if (lookahead == 'x') ADVANCE(55);
      if (('A' <= lookahead && lookahead <= 'Z') ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(57);
      if (lookahead != 0 &&
          lookahead != '\n') ADVANCE(54);
      END_STATE();
    case 15:
      if (lookahead == '|') ADVANCE(16);
      if (lookahead == 'b' ||
          lookahead == 'd' ||
          lookahead == 'o' ||
          lookahead == 'x') ADVANCE(20);
      END_STATE();
    case 16:
      if (lookahead == '|') ADVANCE(2);
      if (lookahead == '\t' ||
          lookahead == '\n' ||
          lookahead == '\r' ||
          lookahead == ' ') ADVANCE(16);
      END_STATE();
    case 17:
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(19);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(47);
      END_STATE();
    case 18:
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(45);
      END_STATE();
    case 19:
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(47);
      END_STATE();
    case 20:
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(48);
      END_STATE();
    case 21:
      if (lookahead != 0 &&
          lookahead != '\n') ADVANCE(1);
      END_STATE();
    case 22:
      if (lookahead != 0 &&
          lookahead != '\n') ADVANCE(7);
      END_STATE();
    case 23:
      if (eof) ADVANCE(24);
      if (lookahead == '"') ADVANCE(1);
      if (lookahead == '#') ADVANCE(4);
      if (lookahead == '\'') ADVANCE(30);
      if (lookahead == '(') ADVANCE(25);
      if (lookahead == ')') ADVANCE(26);
      if (lookahead == ',') ADVANCE(33);
      if (lookahead == '.') ADVANCE(35);
      if (lookahead == ';') ADVANCE(58);
      if (lookahead == '`') ADVANCE(31);
      if (lookahead == '|') ADVANCE(7);
      if (('+' <= lookahead && lookahead <= '-')) ADVANCE(39);
      if (lookahead == '\t' ||
          lookahead == '\n' ||
          lookahead == '\r' ||
          lookahead == ' ') SKIP(23)
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(45);
      if (('!' <= lookahead && lookahead <= '?') ||
          ('A' <= lookahead && lookahead <= 'Z') ||
          ('^' <= lookahead && lookahead <= 'z') ||
          lookahead == '~') ADVANCE(42);
      END_STATE();
    case 24:
      ACCEPT_TOKEN(ts_builtin_sym_end);
      END_STATE();
    case 25:
      ACCEPT_TOKEN(anon_sym_LPAREN);
      END_STATE();
    case 26:
      ACCEPT_TOKEN(anon_sym_RPAREN);
      END_STATE();
    case 27:
      ACCEPT_TOKEN(anon_sym_DOT);
      if (lookahead == '.') ADVANCE(34);
      if (lookahead == '!' ||
          ('$' <= lookahead && lookahead <= '&') ||
          lookahead == '*' ||
          lookahead == '+' ||
          ('-' <= lookahead && lookahead <= ':') ||
          ('<' <= lookahead && lookahead <= 'Z') ||
          lookahead == '^' ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z') ||
          lookahead == '~') ADVANCE(42);
      END_STATE();
    case 28:
      ACCEPT_TOKEN(anon_sym_POUND_LPAREN);
      END_STATE();
    case 29:
      ACCEPT_TOKEN(anon_sym_POUNDu8_LPAREN);
      END_STATE();
    case 30:
      ACCEPT_TOKEN(anon_sym_SQUOTE);
      END_STATE();
    case 31:
      ACCEPT_TOKEN(anon_sym_BQUOTE);
      END_STATE();
    case 32:
      ACCEPT_TOKEN(anon_sym_COMMA_AT);
      END_STATE();
    case 33:
      ACCEPT_TOKEN(anon_sym_COMMA);
      if (lookahead == '@') ADVANCE(32);
      END_STATE();
    case 34:
      ACCEPT_TOKEN(sym_identifier);
      if (lookahead == '.') ADVANCE(42);
      if (lookahead == '!' ||
          ('$' <= lookahead && lookahead <= '&') ||
          lookahead == '*' ||
          lookahead == '+' ||
          ('-' <= lookahead && lookahead <= ':') ||
          ('<' <= lookahead && lookahead <= 'Z') ||
          lookahead == '^' ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z') ||
          lookahead == '~') ADVANCE(42);
      END_STATE();
    case 35:
      ACCEPT_TOKEN(sym_identifier);
      if (lookahead == '.') ADVANCE(34);
      if (lookahead == '!' ||
          ('$' <= lookahead && lookahead <= '&') ||
          lookahead == '*' ||
          lookahead == '+' ||
          ('-' <= lookahead && lookahead <= ':') ||
          ('<' <= lookahead && lookahead <= 'Z') ||
          lookahead == '^' ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z') ||
          lookahead == '~') ADVANCE(42);
      END_STATE();
    case 36:
      ACCEPT_TOKEN(sym_identifier);
      if (lookahead == '.') ADVANCE(37);
      if (sym_identifier_character_set_1(lookahead)) ADVANCE(42);
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(41);
      if (lookahead == 'E' ||
          lookahead == 'e') ADVANCE(38);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(36);
      END_STATE();
    case 37:
      ACCEPT_TOKEN(sym_identifier);
      if (sym_identifier_character_set_2(lookahead)) ADVANCE(42);
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(41);
      if (lookahead == 'E' ||
          lookahead == 'e') ADVANCE(38);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(37);
      END_STATE();
    case 38:
      ACCEPT_TOKEN(sym_identifier);
      if (sym_identifier_character_set_3(lookahead)) ADVANCE(42);
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(40);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(40);
      END_STATE();
    case 39:
      ACCEPT_TOKEN(sym_identifier);
      if (sym_identifier_character_set_4(lookahead)) ADVANCE(42);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(36);
      END_STATE();
    case 40:
      ACCEPT_TOKEN(sym_identifier);
      if (sym_identifier_character_set_4(lookahead)) ADVANCE(42);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(40);
      END_STATE();
    case 41:
      ACCEPT_TOKEN(sym_identifier);
      if (sym_identifier_character_set_5(lookahead)) ADVANCE(42);
      if (lookahead == 'i') ADVANCE(42);
      END_STATE();
    case 42:
      ACCEPT_TOKEN(sym_identifier);
      if (lookahead == '!' ||
          ('$' <= lookahead && lookahead <= '&') ||
          lookahead == '*' ||
          lookahead == '+' ||
          ('-' <= lookahead && lookahead <= ':') ||
          ('<' <= lookahead && lookahead <= 'Z') ||
          lookahead == '^' ||
          lookahead == '_' ||
          ('a' <= lookahead && lookahead <= 'z') ||
          lookahead == '~') ADVANCE(42);
      END_STATE();
    case 43:
      ACCEPT_TOKEN(sym_vertical_bar_symbol);
      END_STATE();
    case 44:
      ACCEPT_TOKEN(sym_number);
      END_STATE();
    case 45:
      ACCEPT_TOKEN(sym_number);
      if (lookahead == '.') ADVANCE(46);
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(10);
      if (lookahead == 'E' ||
          lookahead == 'e') ADVANCE(17);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(45);
      END_STATE();
    case 46:
      ACCEPT_TOKEN(sym_number);
      if (lookahead == '+' ||
          lookahead == '-') ADVANCE(10);
      if (lookahead == 'E' ||
          lookahead == 'e') ADVANCE(17);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(46);
      END_STATE();
    case 47:
      ACCEPT_TOKEN(sym_number);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(47);
      END_STATE();
    case 48:
      ACCEPT_TOKEN(sym_number);
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(48);
      END_STATE();
    case 49:
      ACCEPT_TOKEN(sym_string);
      END_STATE();
    case 50:
      ACCEPT_TOKEN(aux_sym_boolean_token1);
      END_STATE();
    case 51:
      ACCEPT_TOKEN(aux_sym_boolean_token1);
      if (lookahead == 'r') ADVANCE(13);
      END_STATE();
    case 52:
      ACCEPT_TOKEN(aux_sym_boolean_token2);
      END_STATE();
    case 53:
      ACCEPT_TOKEN(aux_sym_boolean_token2);
      if (lookahead == 'a') ADVANCE(11);
      END_STATE();
    case 54:
      ACCEPT_TOKEN(sym_character);
      END_STATE();
    case 55:
      ACCEPT_TOKEN(sym_character);
      if (('0' <= lookahead && lookahead <= '9')) ADVANCE(56);
      if (('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(55);
      if (('G' <= lookahead && lookahead <= 'Z') ||
          ('g' <= lookahead && lookahead <= 'z')) ADVANCE(57);
      END_STATE();
    case 56:
      ACCEPT_TOKEN(sym_character);
      if (('0' <= lookahead && lookahead <= '9') ||
          ('A' <= lookahead && lookahead <= 'F') ||
          ('a' <= lookahead && lookahead <= 'f')) ADVANCE(56);
      END_STATE();
    case 57:
      ACCEPT_TOKEN(sym_character);
      if (('A' <= lookahead && lookahead <= 'Z') ||
          ('a' <= lookahead && lookahead <= 'z')) ADVANCE(57);
      END_STATE();
    case 58:
      ACCEPT_TOKEN(sym_comment);
      if (lookahead != 0 &&
          lookahead != '\n') ADVANCE(58);
      END_STATE();
    case 59:
      ACCEPT_TOKEN(sym_block_comment);
      END_STATE();
    default:
      return false;
  }
}

static const TSLexMode ts_lex_modes[STATE_COUNT] = {
  [0] = {.lex_state = 0},
  [1] = {.lex_state = 23},
  [2] = {.lex_state = 0},
  [3] = {.lex_state = 23},
  [4] = {.lex_state = 0},
  [5] = {.lex_state = 23},
  [6] = {.lex_state = 0},
  [7] = {.lex_state = 23},
  [8] = {.lex_state = 23},
  [9] = {.lex_state = 23},
  [10] = {.lex_state = 23},
  [11] = {.lex_state = 23},
  [12] = {.lex_state = 23},
  [13] = {.lex_state = 23},
  [14] = {.lex_state = 23},
  [15] = {.lex_state = 23},
  [16] = {.lex_state = 23},
  [17] = {.lex_state = 23},
  [18] = {.lex_state = 0},
  [19] = {.lex_state = 23},
  [20] = {.lex_state = 23},
  [21] = {.lex_state = 23},
  [22] = {.lex_state = 23},
  [23] = {.lex_state = 23},
  [24] = {.lex_state = 23},
  [25] = {.lex_state = 0},
  [26] = {.lex_state = 0},
  [27] = {.lex_state = 0},
  [28] = {.lex_state = 0},
  [29] = {.lex_state = 0},
  [30] = {.lex_state = 0},
  [31] = {.lex_state = 23},
  [32] = {.lex_state = 0},
  [33] = {.lex_state = 23},
  [34] = {.lex_state = 0},
  [35] = {.lex_state = 23},
  [36] = {.lex_state = 3},
  [37] = {.lex_state = 3},
  [38] = {.lex_state = 3},
  [39] = {.lex_state = 3},
  [40] = {.lex_state = 3},
  [41] = {.lex_state = 0},
  [42] = {.lex_state = 0},
  [43] = {.lex_state = 0},
};

static const uint16_t ts_parse_table[LARGE_STATE_COUNT][SYMBOL_COUNT] = {
  [0] = {
    [ts_builtin_sym_end] = ACTIONS(1),
    [anon_sym_LPAREN] = ACTIONS(1),
    [anon_sym_RPAREN] = ACTIONS(1),
    [anon_sym_DOT] = ACTIONS(1),
    [anon_sym_POUND_LPAREN] = ACTIONS(1),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(1),
    [anon_sym_SQUOTE] = ACTIONS(1),
    [anon_sym_BQUOTE] = ACTIONS(1),
    [anon_sym_COMMA_AT] = ACTIONS(1),
    [anon_sym_COMMA] = ACTIONS(1),
    [sym_identifier] = ACTIONS(1),
    [sym_vertical_bar_symbol] = ACTIONS(1),
    [sym_number] = ACTIONS(1),
    [sym_string] = ACTIONS(1),
    [aux_sym_boolean_token1] = ACTIONS(1),
    [aux_sym_boolean_token2] = ACTIONS(1),
    [sym_character] = ACTIONS(1),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [1] = {
    [sym_program] = STATE(41),
    [sym__form] = STATE(3),
    [sym__datum] = STATE(3),
    [sym_list] = STATE(3),
    [sym_improper_list] = STATE(3),
    [sym_vector] = STATE(3),
    [sym_bytevector] = STATE(3),
    [sym_abbreviation] = STATE(3),
    [sym__atom] = STATE(3),
    [sym_boolean] = STATE(3),
    [aux_sym_program_repeat1] = STATE(3),
    [ts_builtin_sym_end] = ACTIONS(5),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(17),
    [sym_vertical_bar_symbol] = ACTIONS(17),
    [sym_number] = ACTIONS(19),
    [sym_string] = ACTIONS(17),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(17),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [2] = {
    [sym__datum] = STATE(6),
    [sym_list] = STATE(6),
    [sym_improper_list] = STATE(6),
    [sym_vector] = STATE(6),
    [sym_bytevector] = STATE(6),
    [sym_abbreviation] = STATE(6),
    [sym__atom] = STATE(6),
    [sym_boolean] = STATE(6),
    [aux_sym_list_repeat1] = STATE(6),
    [anon_sym_LPAREN] = ACTIONS(23),
    [anon_sym_RPAREN] = ACTIONS(25),
    [anon_sym_DOT] = ACTIONS(27),
    [anon_sym_POUND_LPAREN] = ACTIONS(29),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(31),
    [anon_sym_SQUOTE] = ACTIONS(33),
    [anon_sym_BQUOTE] = ACTIONS(33),
    [anon_sym_COMMA_AT] = ACTIONS(33),
    [anon_sym_COMMA] = ACTIONS(35),
    [sym_identifier] = ACTIONS(37),
    [sym_vertical_bar_symbol] = ACTIONS(39),
    [sym_number] = ACTIONS(37),
    [sym_string] = ACTIONS(39),
    [aux_sym_boolean_token1] = ACTIONS(41),
    [aux_sym_boolean_token2] = ACTIONS(41),
    [sym_character] = ACTIONS(39),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [3] = {
    [sym__form] = STATE(5),
    [sym__datum] = STATE(5),
    [sym_list] = STATE(5),
    [sym_improper_list] = STATE(5),
    [sym_vector] = STATE(5),
    [sym_bytevector] = STATE(5),
    [sym_abbreviation] = STATE(5),
    [sym__atom] = STATE(5),
    [sym_boolean] = STATE(5),
    [aux_sym_program_repeat1] = STATE(5),
    [ts_builtin_sym_end] = ACTIONS(43),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(45),
    [sym_vertical_bar_symbol] = ACTIONS(45),
    [sym_number] = ACTIONS(47),
    [sym_string] = ACTIONS(45),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(45),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [4] = {
    [sym__datum] = STATE(6),
    [sym_list] = STATE(6),
    [sym_improper_list] = STATE(6),
    [sym_vector] = STATE(6),
    [sym_bytevector] = STATE(6),
    [sym_abbreviation] = STATE(6),
    [sym__atom] = STATE(6),
    [sym_boolean] = STATE(6),
    [aux_sym_list_repeat1] = STATE(6),
    [anon_sym_LPAREN] = ACTIONS(23),
    [anon_sym_RPAREN] = ACTIONS(49),
    [anon_sym_DOT] = ACTIONS(51),
    [anon_sym_POUND_LPAREN] = ACTIONS(29),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(31),
    [anon_sym_SQUOTE] = ACTIONS(33),
    [anon_sym_BQUOTE] = ACTIONS(33),
    [anon_sym_COMMA_AT] = ACTIONS(33),
    [anon_sym_COMMA] = ACTIONS(35),
    [sym_identifier] = ACTIONS(37),
    [sym_vertical_bar_symbol] = ACTIONS(39),
    [sym_number] = ACTIONS(37),
    [sym_string] = ACTIONS(39),
    [aux_sym_boolean_token1] = ACTIONS(41),
    [aux_sym_boolean_token2] = ACTIONS(41),
    [sym_character] = ACTIONS(39),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [5] = {
    [sym__form] = STATE(5),
    [sym__datum] = STATE(5),
    [sym_list] = STATE(5),
    [sym_improper_list] = STATE(5),
    [sym_vector] = STATE(5),
    [sym_bytevector] = STATE(5),
    [sym_abbreviation] = STATE(5),
    [sym__atom] = STATE(5),
    [sym_boolean] = STATE(5),
    [aux_sym_program_repeat1] = STATE(5),
    [ts_builtin_sym_end] = ACTIONS(53),
    [anon_sym_LPAREN] = ACTIONS(55),
    [anon_sym_POUND_LPAREN] = ACTIONS(58),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(61),
    [anon_sym_SQUOTE] = ACTIONS(64),
    [anon_sym_BQUOTE] = ACTIONS(64),
    [anon_sym_COMMA_AT] = ACTIONS(64),
    [anon_sym_COMMA] = ACTIONS(67),
    [sym_identifier] = ACTIONS(70),
    [sym_vertical_bar_symbol] = ACTIONS(70),
    [sym_number] = ACTIONS(73),
    [sym_string] = ACTIONS(70),
    [aux_sym_boolean_token1] = ACTIONS(76),
    [aux_sym_boolean_token2] = ACTIONS(76),
    [sym_character] = ACTIONS(70),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [6] = {
    [sym__datum] = STATE(6),
    [sym_list] = STATE(6),
    [sym_improper_list] = STATE(6),
    [sym_vector] = STATE(6),
    [sym_bytevector] = STATE(6),
    [sym_abbreviation] = STATE(6),
    [sym__atom] = STATE(6),
    [sym_boolean] = STATE(6),
    [aux_sym_list_repeat1] = STATE(6),
    [anon_sym_LPAREN] = ACTIONS(79),
    [anon_sym_RPAREN] = ACTIONS(82),
    [anon_sym_DOT] = ACTIONS(84),
    [anon_sym_POUND_LPAREN] = ACTIONS(86),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(89),
    [anon_sym_SQUOTE] = ACTIONS(92),
    [anon_sym_BQUOTE] = ACTIONS(92),
    [anon_sym_COMMA_AT] = ACTIONS(92),
    [anon_sym_COMMA] = ACTIONS(95),
    [sym_identifier] = ACTIONS(98),
    [sym_vertical_bar_symbol] = ACTIONS(101),
    [sym_number] = ACTIONS(98),
    [sym_string] = ACTIONS(101),
    [aux_sym_boolean_token1] = ACTIONS(104),
    [aux_sym_boolean_token2] = ACTIONS(104),
    [sym_character] = ACTIONS(101),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [7] = {
    [sym__datum] = STATE(4),
    [sym_list] = STATE(4),
    [sym_improper_list] = STATE(4),
    [sym_vector] = STATE(4),
    [sym_bytevector] = STATE(4),
    [sym_abbreviation] = STATE(4),
    [sym__atom] = STATE(4),
    [sym_boolean] = STATE(4),
    [aux_sym_list_repeat1] = STATE(4),
    [anon_sym_LPAREN] = ACTIONS(23),
    [anon_sym_RPAREN] = ACTIONS(107),
    [anon_sym_POUND_LPAREN] = ACTIONS(29),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(31),
    [anon_sym_SQUOTE] = ACTIONS(33),
    [anon_sym_BQUOTE] = ACTIONS(33),
    [anon_sym_COMMA_AT] = ACTIONS(33),
    [anon_sym_COMMA] = ACTIONS(35),
    [sym_identifier] = ACTIONS(109),
    [sym_vertical_bar_symbol] = ACTIONS(109),
    [sym_number] = ACTIONS(111),
    [sym_string] = ACTIONS(109),
    [aux_sym_boolean_token1] = ACTIONS(41),
    [aux_sym_boolean_token2] = ACTIONS(41),
    [sym_character] = ACTIONS(109),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [8] = {
    [sym__datum] = STATE(11),
    [sym_list] = STATE(11),
    [sym_improper_list] = STATE(11),
    [sym_vector] = STATE(11),
    [sym_bytevector] = STATE(11),
    [sym_abbreviation] = STATE(11),
    [sym__atom] = STATE(11),
    [sym_boolean] = STATE(11),
    [aux_sym_list_repeat1] = STATE(11),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_RPAREN] = ACTIONS(113),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(115),
    [sym_vertical_bar_symbol] = ACTIONS(115),
    [sym_number] = ACTIONS(117),
    [sym_string] = ACTIONS(115),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(115),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [9] = {
    [sym__datum] = STATE(13),
    [sym_list] = STATE(13),
    [sym_improper_list] = STATE(13),
    [sym_vector] = STATE(13),
    [sym_bytevector] = STATE(13),
    [sym_abbreviation] = STATE(13),
    [sym__atom] = STATE(13),
    [sym_boolean] = STATE(13),
    [aux_sym_list_repeat1] = STATE(13),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_RPAREN] = ACTIONS(119),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(121),
    [sym_vertical_bar_symbol] = ACTIONS(121),
    [sym_number] = ACTIONS(123),
    [sym_string] = ACTIONS(121),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(121),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [10] = {
    [sym__datum] = STATE(9),
    [sym_list] = STATE(9),
    [sym_improper_list] = STATE(9),
    [sym_vector] = STATE(9),
    [sym_bytevector] = STATE(9),
    [sym_abbreviation] = STATE(9),
    [sym__atom] = STATE(9),
    [sym_boolean] = STATE(9),
    [aux_sym_list_repeat1] = STATE(9),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_RPAREN] = ACTIONS(125),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(127),
    [sym_vertical_bar_symbol] = ACTIONS(127),
    [sym_number] = ACTIONS(129),
    [sym_string] = ACTIONS(127),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(127),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [11] = {
    [sym__datum] = STATE(13),
    [sym_list] = STATE(13),
    [sym_improper_list] = STATE(13),
    [sym_vector] = STATE(13),
    [sym_bytevector] = STATE(13),
    [sym_abbreviation] = STATE(13),
    [sym__atom] = STATE(13),
    [sym_boolean] = STATE(13),
    [aux_sym_list_repeat1] = STATE(13),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_RPAREN] = ACTIONS(131),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(121),
    [sym_vertical_bar_symbol] = ACTIONS(121),
    [sym_number] = ACTIONS(123),
    [sym_string] = ACTIONS(121),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(121),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [12] = {
    [sym__datum] = STATE(2),
    [sym_list] = STATE(2),
    [sym_improper_list] = STATE(2),
    [sym_vector] = STATE(2),
    [sym_bytevector] = STATE(2),
    [sym_abbreviation] = STATE(2),
    [sym__atom] = STATE(2),
    [sym_boolean] = STATE(2),
    [aux_sym_list_repeat1] = STATE(2),
    [anon_sym_LPAREN] = ACTIONS(23),
    [anon_sym_RPAREN] = ACTIONS(133),
    [anon_sym_POUND_LPAREN] = ACTIONS(29),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(31),
    [anon_sym_SQUOTE] = ACTIONS(33),
    [anon_sym_BQUOTE] = ACTIONS(33),
    [anon_sym_COMMA_AT] = ACTIONS(33),
    [anon_sym_COMMA] = ACTIONS(35),
    [sym_identifier] = ACTIONS(135),
    [sym_vertical_bar_symbol] = ACTIONS(135),
    [sym_number] = ACTIONS(137),
    [sym_string] = ACTIONS(135),
    [aux_sym_boolean_token1] = ACTIONS(41),
    [aux_sym_boolean_token2] = ACTIONS(41),
    [sym_character] = ACTIONS(135),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [13] = {
    [sym__datum] = STATE(13),
    [sym_list] = STATE(13),
    [sym_improper_list] = STATE(13),
    [sym_vector] = STATE(13),
    [sym_bytevector] = STATE(13),
    [sym_abbreviation] = STATE(13),
    [sym__atom] = STATE(13),
    [sym_boolean] = STATE(13),
    [aux_sym_list_repeat1] = STATE(13),
    [anon_sym_LPAREN] = ACTIONS(139),
    [anon_sym_RPAREN] = ACTIONS(82),
    [anon_sym_POUND_LPAREN] = ACTIONS(142),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(145),
    [anon_sym_SQUOTE] = ACTIONS(148),
    [anon_sym_BQUOTE] = ACTIONS(148),
    [anon_sym_COMMA_AT] = ACTIONS(148),
    [anon_sym_COMMA] = ACTIONS(151),
    [sym_identifier] = ACTIONS(154),
    [sym_vertical_bar_symbol] = ACTIONS(154),
    [sym_number] = ACTIONS(157),
    [sym_string] = ACTIONS(154),
    [aux_sym_boolean_token1] = ACTIONS(160),
    [aux_sym_boolean_token2] = ACTIONS(160),
    [sym_character] = ACTIONS(154),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [14] = {
    [sym__datum] = STATE(43),
    [sym_list] = STATE(43),
    [sym_improper_list] = STATE(43),
    [sym_vector] = STATE(43),
    [sym_bytevector] = STATE(43),
    [sym_abbreviation] = STATE(43),
    [sym__atom] = STATE(43),
    [sym_boolean] = STATE(43),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(163),
    [sym_vertical_bar_symbol] = ACTIONS(163),
    [sym_number] = ACTIONS(165),
    [sym_string] = ACTIONS(163),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(163),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [15] = {
    [sym__datum] = STATE(42),
    [sym_list] = STATE(42),
    [sym_improper_list] = STATE(42),
    [sym_vector] = STATE(42),
    [sym_bytevector] = STATE(42),
    [sym_abbreviation] = STATE(42),
    [sym__atom] = STATE(42),
    [sym_boolean] = STATE(42),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(167),
    [sym_vertical_bar_symbol] = ACTIONS(167),
    [sym_number] = ACTIONS(169),
    [sym_string] = ACTIONS(167),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(167),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [16] = {
    [sym__datum] = STATE(33),
    [sym_list] = STATE(33),
    [sym_improper_list] = STATE(33),
    [sym_vector] = STATE(33),
    [sym_bytevector] = STATE(33),
    [sym_abbreviation] = STATE(33),
    [sym__atom] = STATE(33),
    [sym_boolean] = STATE(33),
    [anon_sym_LPAREN] = ACTIONS(7),
    [anon_sym_POUND_LPAREN] = ACTIONS(9),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(11),
    [anon_sym_SQUOTE] = ACTIONS(13),
    [anon_sym_BQUOTE] = ACTIONS(13),
    [anon_sym_COMMA_AT] = ACTIONS(13),
    [anon_sym_COMMA] = ACTIONS(15),
    [sym_identifier] = ACTIONS(171),
    [sym_vertical_bar_symbol] = ACTIONS(171),
    [sym_number] = ACTIONS(173),
    [sym_string] = ACTIONS(171),
    [aux_sym_boolean_token1] = ACTIONS(21),
    [aux_sym_boolean_token2] = ACTIONS(21),
    [sym_character] = ACTIONS(171),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [17] = {
    [sym__datum] = STATE(29),
    [sym_list] = STATE(29),
    [sym_improper_list] = STATE(29),
    [sym_vector] = STATE(29),
    [sym_bytevector] = STATE(29),
    [sym_abbreviation] = STATE(29),
    [sym__atom] = STATE(29),
    [sym_boolean] = STATE(29),
    [anon_sym_LPAREN] = ACTIONS(23),
    [anon_sym_POUND_LPAREN] = ACTIONS(29),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(31),
    [anon_sym_SQUOTE] = ACTIONS(33),
    [anon_sym_BQUOTE] = ACTIONS(33),
    [anon_sym_COMMA_AT] = ACTIONS(33),
    [anon_sym_COMMA] = ACTIONS(35),
    [sym_identifier] = ACTIONS(175),
    [sym_vertical_bar_symbol] = ACTIONS(175),
    [sym_number] = ACTIONS(177),
    [sym_string] = ACTIONS(175),
    [aux_sym_boolean_token1] = ACTIONS(41),
    [aux_sym_boolean_token2] = ACTIONS(41),
    [sym_character] = ACTIONS(175),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [18] = {
    [anon_sym_LPAREN] = ACTIONS(179),
    [anon_sym_RPAREN] = ACTIONS(179),
    [anon_sym_DOT] = ACTIONS(181),
    [anon_sym_POUND_LPAREN] = ACTIONS(179),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(179),
    [anon_sym_SQUOTE] = ACTIONS(179),
    [anon_sym_BQUOTE] = ACTIONS(179),
    [anon_sym_COMMA_AT] = ACTIONS(179),
    [anon_sym_COMMA] = ACTIONS(181),
    [sym_identifier] = ACTIONS(181),
    [sym_vertical_bar_symbol] = ACTIONS(179),
    [sym_number] = ACTIONS(181),
    [sym_string] = ACTIONS(179),
    [aux_sym_boolean_token1] = ACTIONS(179),
    [aux_sym_boolean_token2] = ACTIONS(179),
    [sym_character] = ACTIONS(179),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [19] = {
    [ts_builtin_sym_end] = ACTIONS(183),
    [anon_sym_LPAREN] = ACTIONS(183),
    [anon_sym_RPAREN] = ACTIONS(183),
    [anon_sym_POUND_LPAREN] = ACTIONS(183),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(183),
    [anon_sym_SQUOTE] = ACTIONS(183),
    [anon_sym_BQUOTE] = ACTIONS(183),
    [anon_sym_COMMA_AT] = ACTIONS(183),
    [anon_sym_COMMA] = ACTIONS(185),
    [sym_identifier] = ACTIONS(183),
    [sym_vertical_bar_symbol] = ACTIONS(183),
    [sym_number] = ACTIONS(185),
    [sym_string] = ACTIONS(183),
    [aux_sym_boolean_token1] = ACTIONS(183),
    [aux_sym_boolean_token2] = ACTIONS(183),
    [sym_character] = ACTIONS(183),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [20] = {
    [ts_builtin_sym_end] = ACTIONS(187),
    [anon_sym_LPAREN] = ACTIONS(187),
    [anon_sym_RPAREN] = ACTIONS(187),
    [anon_sym_POUND_LPAREN] = ACTIONS(187),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(187),
    [anon_sym_SQUOTE] = ACTIONS(187),
    [anon_sym_BQUOTE] = ACTIONS(187),
    [anon_sym_COMMA_AT] = ACTIONS(187),
    [anon_sym_COMMA] = ACTIONS(189),
    [sym_identifier] = ACTIONS(187),
    [sym_vertical_bar_symbol] = ACTIONS(187),
    [sym_number] = ACTIONS(189),
    [sym_string] = ACTIONS(187),
    [aux_sym_boolean_token1] = ACTIONS(187),
    [aux_sym_boolean_token2] = ACTIONS(187),
    [sym_character] = ACTIONS(187),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [21] = {
    [ts_builtin_sym_end] = ACTIONS(179),
    [anon_sym_LPAREN] = ACTIONS(179),
    [anon_sym_RPAREN] = ACTIONS(179),
    [anon_sym_POUND_LPAREN] = ACTIONS(179),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(179),
    [anon_sym_SQUOTE] = ACTIONS(179),
    [anon_sym_BQUOTE] = ACTIONS(179),
    [anon_sym_COMMA_AT] = ACTIONS(179),
    [anon_sym_COMMA] = ACTIONS(181),
    [sym_identifier] = ACTIONS(179),
    [sym_vertical_bar_symbol] = ACTIONS(179),
    [sym_number] = ACTIONS(181),
    [sym_string] = ACTIONS(179),
    [aux_sym_boolean_token1] = ACTIONS(179),
    [aux_sym_boolean_token2] = ACTIONS(179),
    [sym_character] = ACTIONS(179),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [22] = {
    [ts_builtin_sym_end] = ACTIONS(191),
    [anon_sym_LPAREN] = ACTIONS(191),
    [anon_sym_RPAREN] = ACTIONS(191),
    [anon_sym_POUND_LPAREN] = ACTIONS(191),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(191),
    [anon_sym_SQUOTE] = ACTIONS(191),
    [anon_sym_BQUOTE] = ACTIONS(191),
    [anon_sym_COMMA_AT] = ACTIONS(191),
    [anon_sym_COMMA] = ACTIONS(193),
    [sym_identifier] = ACTIONS(191),
    [sym_vertical_bar_symbol] = ACTIONS(191),
    [sym_number] = ACTIONS(193),
    [sym_string] = ACTIONS(191),
    [aux_sym_boolean_token1] = ACTIONS(191),
    [aux_sym_boolean_token2] = ACTIONS(191),
    [sym_character] = ACTIONS(191),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [23] = {
    [ts_builtin_sym_end] = ACTIONS(195),
    [anon_sym_LPAREN] = ACTIONS(195),
    [anon_sym_RPAREN] = ACTIONS(195),
    [anon_sym_POUND_LPAREN] = ACTIONS(195),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(195),
    [anon_sym_SQUOTE] = ACTIONS(195),
    [anon_sym_BQUOTE] = ACTIONS(195),
    [anon_sym_COMMA_AT] = ACTIONS(195),
    [anon_sym_COMMA] = ACTIONS(197),
    [sym_identifier] = ACTIONS(195),
    [sym_vertical_bar_symbol] = ACTIONS(195),
    [sym_number] = ACTIONS(197),
    [sym_string] = ACTIONS(195),
    [aux_sym_boolean_token1] = ACTIONS(195),
    [aux_sym_boolean_token2] = ACTIONS(195),
    [sym_character] = ACTIONS(195),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [24] = {
    [ts_builtin_sym_end] = ACTIONS(199),
    [anon_sym_LPAREN] = ACTIONS(199),
    [anon_sym_RPAREN] = ACTIONS(199),
    [anon_sym_POUND_LPAREN] = ACTIONS(199),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(199),
    [anon_sym_SQUOTE] = ACTIONS(199),
    [anon_sym_BQUOTE] = ACTIONS(199),
    [anon_sym_COMMA_AT] = ACTIONS(199),
    [anon_sym_COMMA] = ACTIONS(201),
    [sym_identifier] = ACTIONS(199),
    [sym_vertical_bar_symbol] = ACTIONS(199),
    [sym_number] = ACTIONS(201),
    [sym_string] = ACTIONS(199),
    [aux_sym_boolean_token1] = ACTIONS(199),
    [aux_sym_boolean_token2] = ACTIONS(199),
    [sym_character] = ACTIONS(199),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [25] = {
    [anon_sym_LPAREN] = ACTIONS(191),
    [anon_sym_RPAREN] = ACTIONS(191),
    [anon_sym_DOT] = ACTIONS(193),
    [anon_sym_POUND_LPAREN] = ACTIONS(191),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(191),
    [anon_sym_SQUOTE] = ACTIONS(191),
    [anon_sym_BQUOTE] = ACTIONS(191),
    [anon_sym_COMMA_AT] = ACTIONS(191),
    [anon_sym_COMMA] = ACTIONS(193),
    [sym_identifier] = ACTIONS(193),
    [sym_vertical_bar_symbol] = ACTIONS(191),
    [sym_number] = ACTIONS(193),
    [sym_string] = ACTIONS(191),
    [aux_sym_boolean_token1] = ACTIONS(191),
    [aux_sym_boolean_token2] = ACTIONS(191),
    [sym_character] = ACTIONS(191),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [26] = {
    [anon_sym_LPAREN] = ACTIONS(195),
    [anon_sym_RPAREN] = ACTIONS(195),
    [anon_sym_DOT] = ACTIONS(197),
    [anon_sym_POUND_LPAREN] = ACTIONS(195),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(195),
    [anon_sym_SQUOTE] = ACTIONS(195),
    [anon_sym_BQUOTE] = ACTIONS(195),
    [anon_sym_COMMA_AT] = ACTIONS(195),
    [anon_sym_COMMA] = ACTIONS(197),
    [sym_identifier] = ACTIONS(197),
    [sym_vertical_bar_symbol] = ACTIONS(195),
    [sym_number] = ACTIONS(197),
    [sym_string] = ACTIONS(195),
    [aux_sym_boolean_token1] = ACTIONS(195),
    [aux_sym_boolean_token2] = ACTIONS(195),
    [sym_character] = ACTIONS(195),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [27] = {
    [anon_sym_LPAREN] = ACTIONS(183),
    [anon_sym_RPAREN] = ACTIONS(183),
    [anon_sym_DOT] = ACTIONS(185),
    [anon_sym_POUND_LPAREN] = ACTIONS(183),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(183),
    [anon_sym_SQUOTE] = ACTIONS(183),
    [anon_sym_BQUOTE] = ACTIONS(183),
    [anon_sym_COMMA_AT] = ACTIONS(183),
    [anon_sym_COMMA] = ACTIONS(185),
    [sym_identifier] = ACTIONS(185),
    [sym_vertical_bar_symbol] = ACTIONS(183),
    [sym_number] = ACTIONS(185),
    [sym_string] = ACTIONS(183),
    [aux_sym_boolean_token1] = ACTIONS(183),
    [aux_sym_boolean_token2] = ACTIONS(183),
    [sym_character] = ACTIONS(183),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [28] = {
    [anon_sym_LPAREN] = ACTIONS(203),
    [anon_sym_RPAREN] = ACTIONS(203),
    [anon_sym_DOT] = ACTIONS(205),
    [anon_sym_POUND_LPAREN] = ACTIONS(203),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(203),
    [anon_sym_SQUOTE] = ACTIONS(203),
    [anon_sym_BQUOTE] = ACTIONS(203),
    [anon_sym_COMMA_AT] = ACTIONS(203),
    [anon_sym_COMMA] = ACTIONS(205),
    [sym_identifier] = ACTIONS(205),
    [sym_vertical_bar_symbol] = ACTIONS(203),
    [sym_number] = ACTIONS(205),
    [sym_string] = ACTIONS(203),
    [aux_sym_boolean_token1] = ACTIONS(203),
    [aux_sym_boolean_token2] = ACTIONS(203),
    [sym_character] = ACTIONS(203),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [29] = {
    [anon_sym_LPAREN] = ACTIONS(207),
    [anon_sym_RPAREN] = ACTIONS(207),
    [anon_sym_DOT] = ACTIONS(209),
    [anon_sym_POUND_LPAREN] = ACTIONS(207),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(207),
    [anon_sym_SQUOTE] = ACTIONS(207),
    [anon_sym_BQUOTE] = ACTIONS(207),
    [anon_sym_COMMA_AT] = ACTIONS(207),
    [anon_sym_COMMA] = ACTIONS(209),
    [sym_identifier] = ACTIONS(209),
    [sym_vertical_bar_symbol] = ACTIONS(207),
    [sym_number] = ACTIONS(209),
    [sym_string] = ACTIONS(207),
    [aux_sym_boolean_token1] = ACTIONS(207),
    [aux_sym_boolean_token2] = ACTIONS(207),
    [sym_character] = ACTIONS(207),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [30] = {
    [anon_sym_LPAREN] = ACTIONS(211),
    [anon_sym_RPAREN] = ACTIONS(211),
    [anon_sym_DOT] = ACTIONS(213),
    [anon_sym_POUND_LPAREN] = ACTIONS(211),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(211),
    [anon_sym_SQUOTE] = ACTIONS(211),
    [anon_sym_BQUOTE] = ACTIONS(211),
    [anon_sym_COMMA_AT] = ACTIONS(211),
    [anon_sym_COMMA] = ACTIONS(213),
    [sym_identifier] = ACTIONS(213),
    [sym_vertical_bar_symbol] = ACTIONS(211),
    [sym_number] = ACTIONS(213),
    [sym_string] = ACTIONS(211),
    [aux_sym_boolean_token1] = ACTIONS(211),
    [aux_sym_boolean_token2] = ACTIONS(211),
    [sym_character] = ACTIONS(211),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [31] = {
    [ts_builtin_sym_end] = ACTIONS(211),
    [anon_sym_LPAREN] = ACTIONS(211),
    [anon_sym_RPAREN] = ACTIONS(211),
    [anon_sym_POUND_LPAREN] = ACTIONS(211),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(211),
    [anon_sym_SQUOTE] = ACTIONS(211),
    [anon_sym_BQUOTE] = ACTIONS(211),
    [anon_sym_COMMA_AT] = ACTIONS(211),
    [anon_sym_COMMA] = ACTIONS(213),
    [sym_identifier] = ACTIONS(211),
    [sym_vertical_bar_symbol] = ACTIONS(211),
    [sym_number] = ACTIONS(213),
    [sym_string] = ACTIONS(211),
    [aux_sym_boolean_token1] = ACTIONS(211),
    [aux_sym_boolean_token2] = ACTIONS(211),
    [sym_character] = ACTIONS(211),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [32] = {
    [anon_sym_LPAREN] = ACTIONS(187),
    [anon_sym_RPAREN] = ACTIONS(187),
    [anon_sym_DOT] = ACTIONS(189),
    [anon_sym_POUND_LPAREN] = ACTIONS(187),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(187),
    [anon_sym_SQUOTE] = ACTIONS(187),
    [anon_sym_BQUOTE] = ACTIONS(187),
    [anon_sym_COMMA_AT] = ACTIONS(187),
    [anon_sym_COMMA] = ACTIONS(189),
    [sym_identifier] = ACTIONS(189),
    [sym_vertical_bar_symbol] = ACTIONS(187),
    [sym_number] = ACTIONS(189),
    [sym_string] = ACTIONS(187),
    [aux_sym_boolean_token1] = ACTIONS(187),
    [aux_sym_boolean_token2] = ACTIONS(187),
    [sym_character] = ACTIONS(187),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [33] = {
    [ts_builtin_sym_end] = ACTIONS(207),
    [anon_sym_LPAREN] = ACTIONS(207),
    [anon_sym_RPAREN] = ACTIONS(207),
    [anon_sym_POUND_LPAREN] = ACTIONS(207),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(207),
    [anon_sym_SQUOTE] = ACTIONS(207),
    [anon_sym_BQUOTE] = ACTIONS(207),
    [anon_sym_COMMA_AT] = ACTIONS(207),
    [anon_sym_COMMA] = ACTIONS(209),
    [sym_identifier] = ACTIONS(207),
    [sym_vertical_bar_symbol] = ACTIONS(207),
    [sym_number] = ACTIONS(209),
    [sym_string] = ACTIONS(207),
    [aux_sym_boolean_token1] = ACTIONS(207),
    [aux_sym_boolean_token2] = ACTIONS(207),
    [sym_character] = ACTIONS(207),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [34] = {
    [anon_sym_LPAREN] = ACTIONS(199),
    [anon_sym_RPAREN] = ACTIONS(199),
    [anon_sym_DOT] = ACTIONS(201),
    [anon_sym_POUND_LPAREN] = ACTIONS(199),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(199),
    [anon_sym_SQUOTE] = ACTIONS(199),
    [anon_sym_BQUOTE] = ACTIONS(199),
    [anon_sym_COMMA_AT] = ACTIONS(199),
    [anon_sym_COMMA] = ACTIONS(201),
    [sym_identifier] = ACTIONS(201),
    [sym_vertical_bar_symbol] = ACTIONS(199),
    [sym_number] = ACTIONS(201),
    [sym_string] = ACTIONS(199),
    [aux_sym_boolean_token1] = ACTIONS(199),
    [aux_sym_boolean_token2] = ACTIONS(199),
    [sym_character] = ACTIONS(199),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
  [35] = {
    [ts_builtin_sym_end] = ACTIONS(203),
    [anon_sym_LPAREN] = ACTIONS(203),
    [anon_sym_RPAREN] = ACTIONS(203),
    [anon_sym_POUND_LPAREN] = ACTIONS(203),
    [anon_sym_POUNDu8_LPAREN] = ACTIONS(203),
    [anon_sym_SQUOTE] = ACTIONS(203),
    [anon_sym_BQUOTE] = ACTIONS(203),
    [anon_sym_COMMA_AT] = ACTIONS(203),
    [anon_sym_COMMA] = ACTIONS(205),
    [sym_identifier] = ACTIONS(203),
    [sym_vertical_bar_symbol] = ACTIONS(203),
    [sym_number] = ACTIONS(205),
    [sym_string] = ACTIONS(203),
    [aux_sym_boolean_token1] = ACTIONS(203),
    [aux_sym_boolean_token2] = ACTIONS(203),
    [sym_character] = ACTIONS(203),
    [sym_comment] = ACTIONS(3),
    [sym_block_comment] = ACTIONS(3),
  },
};

static const uint16_t ts_small_parse_table[] = {
  [0] = 4,
    ACTIONS(215), 1,
      anon_sym_RPAREN,
    ACTIONS(217), 1,
      sym_number,
    STATE(38), 1,
      aux_sym_bytevector_repeat1,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [14] = 4,
    ACTIONS(219), 1,
      anon_sym_RPAREN,
    ACTIONS(221), 1,
      sym_number,
    STATE(40), 1,
      aux_sym_bytevector_repeat1,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [28] = 4,
    ACTIONS(223), 1,
      anon_sym_RPAREN,
    ACTIONS(225), 1,
      sym_number,
    STATE(39), 1,
      aux_sym_bytevector_repeat1,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [42] = 4,
    ACTIONS(227), 1,
      anon_sym_RPAREN,
    ACTIONS(229), 1,
      sym_number,
    STATE(39), 1,
      aux_sym_bytevector_repeat1,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [56] = 4,
    ACTIONS(225), 1,
      sym_number,
    ACTIONS(232), 1,
      anon_sym_RPAREN,
    STATE(39), 1,
      aux_sym_bytevector_repeat1,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [70] = 2,
    ACTIONS(234), 1,
      ts_builtin_sym_end,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [78] = 2,
    ACTIONS(236), 1,
      anon_sym_RPAREN,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
  [86] = 2,
    ACTIONS(238), 1,
      anon_sym_RPAREN,
    ACTIONS(3), 2,
      sym_comment,
      sym_block_comment,
};

static const uint32_t ts_small_parse_table_map[] = {
  [SMALL_STATE(36)] = 0,
  [SMALL_STATE(37)] = 14,
  [SMALL_STATE(38)] = 28,
  [SMALL_STATE(39)] = 42,
  [SMALL_STATE(40)] = 56,
  [SMALL_STATE(41)] = 70,
  [SMALL_STATE(42)] = 78,
  [SMALL_STATE(43)] = 86,
};

static const TSParseActionEntry ts_parse_actions[] = {
  [0] = {.entry = {.count = 0, .reusable = false}},
  [1] = {.entry = {.count = 1, .reusable = false}}, RECOVER(),
  [3] = {.entry = {.count = 1, .reusable = true}}, SHIFT_EXTRA(),
  [5] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_program, 0),
  [7] = {.entry = {.count = 1, .reusable = true}}, SHIFT(7),
  [9] = {.entry = {.count = 1, .reusable = true}}, SHIFT(8),
  [11] = {.entry = {.count = 1, .reusable = true}}, SHIFT(36),
  [13] = {.entry = {.count = 1, .reusable = true}}, SHIFT(16),
  [15] = {.entry = {.count = 1, .reusable = false}}, SHIFT(16),
  [17] = {.entry = {.count = 1, .reusable = true}}, SHIFT(3),
  [19] = {.entry = {.count = 1, .reusable = false}}, SHIFT(3),
  [21] = {.entry = {.count = 1, .reusable = true}}, SHIFT(22),
  [23] = {.entry = {.count = 1, .reusable = true}}, SHIFT(12),
  [25] = {.entry = {.count = 1, .reusable = true}}, SHIFT(30),
  [27] = {.entry = {.count = 1, .reusable = false}}, SHIFT(15),
  [29] = {.entry = {.count = 1, .reusable = true}}, SHIFT(10),
  [31] = {.entry = {.count = 1, .reusable = true}}, SHIFT(37),
  [33] = {.entry = {.count = 1, .reusable = true}}, SHIFT(17),
  [35] = {.entry = {.count = 1, .reusable = false}}, SHIFT(17),
  [37] = {.entry = {.count = 1, .reusable = false}}, SHIFT(6),
  [39] = {.entry = {.count = 1, .reusable = true}}, SHIFT(6),
  [41] = {.entry = {.count = 1, .reusable = true}}, SHIFT(25),
  [43] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_program, 1),
  [45] = {.entry = {.count = 1, .reusable = true}}, SHIFT(5),
  [47] = {.entry = {.count = 1, .reusable = false}}, SHIFT(5),
  [49] = {.entry = {.count = 1, .reusable = true}}, SHIFT(31),
  [51] = {.entry = {.count = 1, .reusable = false}}, SHIFT(14),
  [53] = {.entry = {.count = 1, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2),
  [55] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(7),
  [58] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(8),
  [61] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(36),
  [64] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(16),
  [67] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(16),
  [70] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(5),
  [73] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(5),
  [76] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_program_repeat1, 2), SHIFT_REPEAT(22),
  [79] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(12),
  [82] = {.entry = {.count = 1, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2),
  [84] = {.entry = {.count = 1, .reusable = false}}, REDUCE(aux_sym_list_repeat1, 2),
  [86] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(10),
  [89] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(37),
  [92] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(17),
  [95] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(17),
  [98] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(6),
  [101] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(6),
  [104] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(25),
  [107] = {.entry = {.count = 1, .reusable = true}}, SHIFT(23),
  [109] = {.entry = {.count = 1, .reusable = true}}, SHIFT(4),
  [111] = {.entry = {.count = 1, .reusable = false}}, SHIFT(4),
  [113] = {.entry = {.count = 1, .reusable = true}}, SHIFT(19),
  [115] = {.entry = {.count = 1, .reusable = true}}, SHIFT(11),
  [117] = {.entry = {.count = 1, .reusable = false}}, SHIFT(11),
  [119] = {.entry = {.count = 1, .reusable = true}}, SHIFT(32),
  [121] = {.entry = {.count = 1, .reusable = true}}, SHIFT(13),
  [123] = {.entry = {.count = 1, .reusable = false}}, SHIFT(13),
  [125] = {.entry = {.count = 1, .reusable = true}}, SHIFT(27),
  [127] = {.entry = {.count = 1, .reusable = true}}, SHIFT(9),
  [129] = {.entry = {.count = 1, .reusable = false}}, SHIFT(9),
  [131] = {.entry = {.count = 1, .reusable = true}}, SHIFT(20),
  [133] = {.entry = {.count = 1, .reusable = true}}, SHIFT(26),
  [135] = {.entry = {.count = 1, .reusable = true}}, SHIFT(2),
  [137] = {.entry = {.count = 1, .reusable = false}}, SHIFT(2),
  [139] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(7),
  [142] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(8),
  [145] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(36),
  [148] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(16),
  [151] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(16),
  [154] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(13),
  [157] = {.entry = {.count = 2, .reusable = false}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(13),
  [160] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_list_repeat1, 2), SHIFT_REPEAT(22),
  [163] = {.entry = {.count = 1, .reusable = true}}, SHIFT(43),
  [165] = {.entry = {.count = 1, .reusable = false}}, SHIFT(43),
  [167] = {.entry = {.count = 1, .reusable = true}}, SHIFT(42),
  [169] = {.entry = {.count = 1, .reusable = false}}, SHIFT(42),
  [171] = {.entry = {.count = 1, .reusable = true}}, SHIFT(33),
  [173] = {.entry = {.count = 1, .reusable = false}}, SHIFT(33),
  [175] = {.entry = {.count = 1, .reusable = true}}, SHIFT(29),
  [177] = {.entry = {.count = 1, .reusable = false}}, SHIFT(29),
  [179] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_bytevector, 3),
  [181] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_bytevector, 3),
  [183] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_vector, 2),
  [185] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_vector, 2),
  [187] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_vector, 3),
  [189] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_vector, 3),
  [191] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_boolean, 1),
  [193] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_boolean, 1),
  [195] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_list, 2),
  [197] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_list, 2),
  [199] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_improper_list, 5),
  [201] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_improper_list, 5),
  [203] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_bytevector, 2),
  [205] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_bytevector, 2),
  [207] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_abbreviation, 2),
  [209] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_abbreviation, 2),
  [211] = {.entry = {.count = 1, .reusable = true}}, REDUCE(sym_list, 3),
  [213] = {.entry = {.count = 1, .reusable = false}}, REDUCE(sym_list, 3),
  [215] = {.entry = {.count = 1, .reusable = true}}, SHIFT(35),
  [217] = {.entry = {.count = 1, .reusable = true}}, SHIFT(38),
  [219] = {.entry = {.count = 1, .reusable = true}}, SHIFT(28),
  [221] = {.entry = {.count = 1, .reusable = true}}, SHIFT(40),
  [223] = {.entry = {.count = 1, .reusable = true}}, SHIFT(21),
  [225] = {.entry = {.count = 1, .reusable = true}}, SHIFT(39),
  [227] = {.entry = {.count = 1, .reusable = true}}, REDUCE(aux_sym_bytevector_repeat1, 2),
  [229] = {.entry = {.count = 2, .reusable = true}}, REDUCE(aux_sym_bytevector_repeat1, 2), SHIFT_REPEAT(39),
  [232] = {.entry = {.count = 1, .reusable = true}}, SHIFT(18),
  [234] = {.entry = {.count = 1, .reusable = true}},  ACCEPT_INPUT(),
  [236] = {.entry = {.count = 1, .reusable = true}}, SHIFT(34),
  [238] = {.entry = {.count = 1, .reusable = true}}, SHIFT(24),
};

#ifdef __cplusplus
extern "C" {
#endif
#ifdef _WIN32
#define extern __declspec(dllexport)
#endif

extern const TSLanguage *tree_sitter_vibe(void) {
  static const TSLanguage language = {
    .version = LANGUAGE_VERSION,
    .symbol_count = SYMBOL_COUNT,
    .alias_count = ALIAS_COUNT,
    .token_count = TOKEN_COUNT,
    .external_token_count = EXTERNAL_TOKEN_COUNT,
    .state_count = STATE_COUNT,
    .large_state_count = LARGE_STATE_COUNT,
    .production_id_count = PRODUCTION_ID_COUNT,
    .field_count = FIELD_COUNT,
    .max_alias_sequence_length = MAX_ALIAS_SEQUENCE_LENGTH,
    .parse_table = &ts_parse_table[0][0],
    .small_parse_table = ts_small_parse_table,
    .small_parse_table_map = ts_small_parse_table_map,
    .parse_actions = ts_parse_actions,
    .symbol_names = ts_symbol_names,
    .symbol_metadata = ts_symbol_metadata,
    .public_symbol_map = ts_symbol_map,
    .alias_map = ts_non_terminal_alias_map,
    .alias_sequences = &ts_alias_sequences[0][0],
    .lex_modes = ts_lex_modes,
    .lex_fn = ts_lex,
    .primary_state_ids = ts_primary_state_ids,
  };
  return &language;
}
#ifdef __cplusplus
}
#endif
