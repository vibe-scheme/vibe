; ModuleID = 'lexer'
source_filename = "lexer"
target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

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

define i32 @lex_is_eof(ptr %0) {
entry:
  %1 = getelementptr %Lexer, ptr %2, i32 0, i32 2
  %2 = load i64, ptr %1, align 8
  %3 = getelementptr %Lexer, ptr %2, i32 0, i32 1
  %4 = load i64, ptr %3, align 8
  %5 = icmp ult i64 %2, %4
  %6 = zext i1 %5 to i32
  ret i32 %6
}

define i8 @lex_current_char(ptr %0) {
entry:
  %1 = call i32 @lex_is_eof(ptr %2)
  %2 = icmp ne i32 %1, 0
  br i1 %2, label %eof, label %not_eof

eof:                                              ; preds = %entry

not_eof:                                          ; preds = %entry

eof1:                                             ; No predecessors!
  ret i8 0

not_eof2:                                         ; No predecessors!
  %3 = getelementptr %Lexer, ptr %2, i32 0, i32 0
  %4 = load ptr, ptr %3, align 8
  %5 = getelementptr %Lexer, ptr %2, i32 0, i32 2
  %6 = load i64, ptr %5, align 8
  %7 = getelementptr i8, ptr %4, i64 %6
  %8 = load i8, ptr %7, align 1
  ret i8 %8
}

define void @lex_advance(ptr %0) {
entry:
  %1 = call i32 @lex_is_eof(ptr %2)
  %2 = icmp ne i32 %1, 0
  br i1 %2, label %done, label %advance

done:                                             ; preds = %entry

advance:                                          ; preds = %entry

done1:                                            ; No predecessors!
  ret void

advance2:                                         ; No predecessors!
  %3 = call i8 @lex_current_char(ptr %2)
  %4 = zext i8 %3 to i32
  %5 = icmp eq i32 %4, 10
  br i1 %5, label %newline, label %normal

newline:                                          ; preds = %advance2

normal:                                           ; preds = %advance2

newline3:                                         ; No predecessors!
  %6 = getelementptr %Lexer, ptr %2, i32 0, i32 3
  %7 = load i32, ptr %6, align 4
  %8 = add i32 %7, 1
  %9 = getelementptr %Lexer, ptr %2, i32 0, i32 4
  store i32 %8, ptr %6, align 4
  store i32 1, ptr %9, align 4
  br label %increment_pos

increment_pos:                                    ; preds = %newline3

normal4:                                          ; No predecessors!
  %10 = getelementptr %Lexer, ptr %2, i32 0, i32 4
  %11 = load i32, ptr %10, align 4
  %12 = add i32 %11, 1
  store i32 %12, ptr %10, align 4
  br label %increment_pos5

increment_pos5:                                   ; preds = %normal4

increment_pos6:                                   ; No predecessors!
  %13 = getelementptr %Lexer, ptr %2, i32 0, i32 2
  %14 = load i64, ptr %13, align 8
  %15 = add i64 %14, 1
  store i64 %15, ptr %13, align 8
  br label %done7
  ret void

done7:                                            ; preds = %increment_pos6
}

define void @lex_skip_whitespace(ptr %0) {
entry:

loop:                                             ; No predecessors!
  %1 = call i8 @lex_current_char(ptr %2)
  %2 = zext i8 %1 to i32
  %3 = icmp eq i32 %2, 32
  %4 = icmp eq i32 %2, 9
  %5 = icmp eq i32 %2, 10
  %6 = icmp eq i32 %2, 13
  %7 = or i1 %3, %4
  %8 = or i1 %5, %6
  %9 = or i1 %7, %8
  br i1 %9, label %skip, label %done

skip:                                             ; preds = %loop

done:                                             ; preds = %loop

skip1:                                            ; No predecessors!
  call void @lex_advance(ptr %2)
  br label %loop2

loop2:                                            ; preds = %skip1

done3:                                            ; No predecessors!
  ret void
}
