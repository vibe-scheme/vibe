target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

declare i32 @printf(i8* nocapture, ...)

@hello_string = external constant [14 x i8]
define void @hello(i8* %name) {
  %format = getelementptr [14 x i8], [14 x i8]* @hello_string, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* %format, i8* %name)
  ret void

}
