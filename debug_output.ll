; ModuleID = 'vibe'
source_filename = "vibe"
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

@.str.0 = constant [6 x i8] c"World\00"

declare i32 @printf(ptr, ...)

define void @hello(ptr %0) {
entry:
  ret void
}

define i32 @main() {
entry:
  call void @hello(ptr @.str.0)
  ret i32 0
}
