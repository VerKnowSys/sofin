--- src/type1/t1load.c.orig	2012-04-07 12:20:49.000000000 +0200
+++ src/type1/t1load.c	2012-04-07 12:21:10.000000000 +0200
@@ -71,6 +71,13 @@
 #include "t1errors.h"
 
 
+#ifdef FT_CONFIG_OPTION_INCREMENTAL
+#define IS_INCREMENTAL  ( face->root.internal->incremental_interface != 0 )
+#else
+#define IS_INCREMENTAL  0
+#endif
+
+
   /*************************************************************************/
   /*                                                                       */
   /* The macro FT_COMPONENT is used in trace mode.  It is an implicit      */
@@ -1030,7 +1037,8 @@
   static int
   read_binary_data( T1_Parser  parser,
                     FT_Long*   size,
-                    FT_Byte**  base )
+                    FT_Byte**  base,
+                    FT_Bool    incremental )
   {
     FT_Byte*  cur;
     FT_Byte*  limit = parser->root.limit;
@@ -1065,8 +1073,12 @@
       }
     }
 
-    FT_ERROR(( "read_binary_data: invalid size field\n" ));
-    parser->root.error = T1_Err_Invalid_File_Format;
+    if( !incremental )
+    {
+      FT_ERROR(( "read_binary_data: invalid size field\n" ));
+      parser->root.error = T1_Err_Invalid_File_Format;
+    }
+
     return 0;
   }
 
@@ -1387,16 +1399,17 @@
       FT_Byte*  base;
 
 
-      /* If the next token isn't `dup' we are done. */
-      if ( parser->root.cursor + 4 < parser->root.limit            &&
-           ft_strncmp( (char*)parser->root.cursor, "dup", 3 ) != 0 )
+      /* If we are out of data, or if the next token isn't `dup', */
+      /* we are done.                                             */
+      if ( parser->root.cursor + 4 >= parser->root.limit          ||
+          ft_strncmp( (char*)parser->root.cursor, "dup", 3 ) != 0 )
         break;
 
       T1_Skip_PS_Token( parser );       /* `dup' */
 
       idx = T1_ToInt( parser );
 
-      if ( !read_binary_data( parser, &size, &base ) )
+      if ( !read_binary_data( parser, &size, &base, IS_INCREMENTAL ) )
         return;
 
       /* The binary string is followed by one token, e.g. `NP' */
@@ -1582,7 +1595,7 @@
         cur++;                              /* skip `/' */
         len = parser->root.cursor - cur;
 
-        if ( !read_binary_data( parser, &size, &base ) )
+        if ( !read_binary_data( parser, &size, &base, IS_INCREMENTAL ) )
           return;
 
         /* for some non-standard fonts like `Optima' which provides */
@@ -1871,7 +1884,7 @@
 
 
         parser->root.cursor = start_binary;
-        if ( !read_binary_data( parser, &s, &b ) )
+        if ( !read_binary_data( parser, &s, &b, IS_INCREMENTAL ) )
           return T1_Err_Invalid_File_Format;
         have_integer = 0;
       }
@@ -1884,7 +1897,7 @@
 
 
         parser->root.cursor = start_binary;
-        if ( !read_binary_data( parser, &s, &b ) )
+        if ( !read_binary_data( parser, &s, &b, IS_INCREMENTAL ) )
           return T1_Err_Invalid_File_Format;
         have_integer = 0;
       }
@@ -2160,9 +2173,7 @@
       type1->subrs_len   = loader.subrs.lengths;
     }
 
-#ifdef FT_CONFIG_OPTION_INCREMENTAL
-    if ( !face->root.internal->incremental_interface )
-#endif
+    if ( !IS_INCREMENTAL )
       if ( !loader.charstrings.init )
       {
         FT_ERROR(( "T1_Open_Face: no `/CharStrings' array in face\n" ));
