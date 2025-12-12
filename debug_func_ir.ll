define void @hello(i8* %name) {
  %format = getelementptr [14 x i8], [14 x i8]* @hello_string, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* %format, i8* %name)
  ret void

}
