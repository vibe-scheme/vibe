; ModuleID = 'vibe'
source_filename = "vibe"
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

declare ptr @malloc(i64)

declare void @free(ptr)

define ptr @lex_init(ptr %0, i64 %1) {
entry:
}
