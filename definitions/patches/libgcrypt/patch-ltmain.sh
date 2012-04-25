--- ltmain.sh	Wed Jul 17 15:42:41 2002
+++ ltmain.sh	Wed Jul 17 15:47:36 2002
@@ -2077,10 +2077,12 @@
 	fi

 	# Install the pseudo-library for information purposes.
+	if /usr/bin/false; then
 	func_basename "$file"
 	name="$func_basename_result"
 	instname="$dir/$name"i
 	func_show_eval "$install_prog $instname $destdir/$name" 'exit $?'
+	fi

 	# Maybe install the static library, too.
 	test -n "$old_library" && staticlibs="$staticlibs $dir/$old_library"
@@ -4560,8 +4562,16 @@
 	continue
 	;;
 
+      -pthread)
+        compile_command="$compile_command %%PTHREAD_LIBS%%"
+	finalize_command="$finalize_command %%PTHREAD_LIBS%%"
+	compiler_flags="$compiler_flags %%PTHREAD_LIBS%%"
+	continue;
+	;;	
+
       -module)
 	module=yes
+	build_old_libs=yes
 	continue
 	;;
 
