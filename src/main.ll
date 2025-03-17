; Vibe main program
define i32 @main(i32 %argc, i8** %argv) {
  ; Initialize runtime
  call void @init_runtime()
  
  ; Parse command line arguments
  %i = alloca i32
  store i32 1, i32* %i
  
  ; Check for --repl flag
  %repl_mode = alloca i1
  store i1 false, i1* %repl_mode
  
  ; Check for --image flag
  %image_mode = alloca i1
  store i1 false, i1* %image_mode
  %image_path = alloca i8*
  store i8* null, i8** %image_path
  
  br label %arg_loop
  
arg_loop:
  %idx = load i32, i32* %i
  %continue = icmp slt i32 %idx, %argc
  br i1 %continue, label %process_arg, label %check_mode
  
process_arg:
  %arg_ptr = getelementptr i8*, i8** %argv, i32 %idx
  %arg = load i8*, i8** %arg_ptr
  
  ; Check if it's --repl
  %is_repl = call i1 @string_equal(i8* %arg, i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.repl_flag, i64 0, i64 0))
  br i1 %is_repl, label %set_repl_mode, label %check_image_flag
  
check_image_flag:
  %is_image = call i1 @string_equal(i8* %arg, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.image_flag, i64 0, i64 0))
  br i1 %is_image, label %handle_image_flag, label %next_arg
  
handle_image_flag:
  store i1 true, i1* %image_mode
  %next_idx = add i32 %idx, 1
  %has_path = icmp slt i32 %next_idx, %argc
  br i1 %has_path, label %store_image_path, label %error_missing_path
  
store_image_path:
  %path_ptr = getelementptr i8*, i8** %argv, i32 %next_idx
  %path = load i8*, i8** %path_ptr
  store i8* %path, i8** %image_path
  %skip_idx = add i32 %idx, 2
  store i32 %skip_idx, i32* %i
  br label %arg_loop
  
error_missing_path:
  call void @print_string(i8* getelementptr inbounds ([33 x i8], [33 x i8]* @.str.missing_image_path, i64 0, i64 0))
  ret i32 1
  
set_repl_mode:
  store i1 true, i1* %repl_mode
  br label %next_arg
  
next_arg:
  %next_i = add i32 %idx, 1
  store i32 %next_i, i32* %i
  br label %arg_loop
  
check_mode:
  ; Load image if specified
  %should_load_image = load i1, i1* %image_mode
  br i1 %should_load_image, label %load_image, label %check_repl_mode
  
load_image:
  %image_path_val = load i8*, i8** %image_path
  %load_result = call i1 @read_image(i8* %image_path_val)
  %load_ok = icmp eq i1 %load_result, true
  br i1 %load_ok, label %check_repl_mode, label %error_load_failed
  
error_load_failed:
  call void @print_string(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.image_load_failed, i64 0, i64 0))
  ret i32 1
  
check_repl_mode:
  %should_start_repl = load i1, i1* %repl_mode
  br i1 %should_start_repl, label %start_repl, label %normal_mode
  
start_repl:
  ; Start REPL server on default port
  call void @start_repl_server(i32 7654)
  ret i32 0
  
normal_mode:
  ; TODO: Normal file evaluation mode
  ret i32 0
}

; String constants
@.str.repl_flag = private unnamed_addr constant [7 x i8] c"--repl\00"
@.str.image_flag = private unnamed_addr constant [8 x i8] c"--image\00"
@.str.missing_image_path = private unnamed_addr constant [33 x i8] c"Error: --image requires a path\0A\00"
@.str.image_load_failed = private unnamed_addr constant [28 x i8] c"Error: Failed to load image\0A\00"

; External functions
declare void @init_runtime()
declare i1 @string_equal(i8*, i8*)
declare void @print_string(i8*)
declare i1 @read_image(i8*)
declare void @start_repl_server(i32) 