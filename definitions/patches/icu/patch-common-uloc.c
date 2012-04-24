$FreeBSD: ports/devel/icu/files/patch-common-uloc.c,v 1.1 2011/12/23 14:54:18 crees Exp $

From http://bugs.icu-project.org/trac/ticket/8984

Submitted by: Andrei Lavreniyuk <andy.lavr@gmail.com> (thanks!)

--- common/uloc.c
+++ common/uloc.c
@@ -1797,7 +1797,7 @@
                 int32_t variantLen = _deleteVariant(variant, uprv_min(variantSize, (nameCapacity-len)), variantToCompare, n);
                 len -= variantLen;
                 if (variantLen > 0) {
-                    if (name[len-1] == '_') { /* delete trailing '_' */
+                    if (len > 0 && name[len-1] == '_') { /* delete trailing '_' */
                         --len;
                     }
                     addKeyword = VARIANT_MAP[j].keyword;
@@ -1805,7 +1805,7 @@
                     break;
                 }
             }
-            if (name[len-1] == '_') { /* delete trailing '_' */
+            if (len > 0 && len <= nameCapacity && name[len-1] == '_') { /* delete trailing '_' */
                 --len;
             }
         }
