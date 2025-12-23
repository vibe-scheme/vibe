; ModuleID = 'test_standalone'
source_filename = "test_standalone"
target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

define i32 @main() {
entry:
  ret i32 0
}
