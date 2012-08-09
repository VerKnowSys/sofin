--- third-party/libutp/utypes.h.orig	2012-08-09 19:50:35.072765981 +0200
+++ third-party/libutp/utypes.h	2012-08-09 19:51:10.300584784 +0200
@@ -36,7 +36,11 @@
 typedef char * str;
 
 #ifndef __cplusplus
+#ifdef HAVE_STDBOOL_H
+#include <stdbool.h>
+#else
 typedef uint8 bool;
 #endif
+#endif
 
 #endif //__UTYPES_H__
