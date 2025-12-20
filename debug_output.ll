; ModuleID = 'vibe'
source_filename = "vibe"
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

%Lexer = type { ptr, i64, i64, i32, i32 }

declare ptr @malloc(i64)

declare void @free(ptr)

define ptr @lex_init(ptr %0, i64 %1) {
entry:
  %2 = call ptr @malloc(i64 40)
  %3 = getelementptr %Lexer, ptr %2, i32 0, i32 0
  %4 = getelementptr %Lexer, ptr %2, i32 0, i32 1
  %5 = getelementptr %Lexer, ptr %2, i32 0, i32 2
  %6 = getelementptr %Lexer, ptr %2, i32 0, i32 3
  %7 = getelementptr %Lexer, ptr %2, i32 0, i32 4
  store ptr %0, ptr %3, align 8
  store i64 %1, ptr %4, align 8
  store i64 0, ptr %5, align 8
  store i32 1, ptr %6, align 4
  store i32 1, ptr %7, align 4
  ret ptr %2
}
