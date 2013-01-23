Add a fix for bug #30612 (http://savannah.gnu.org/bugs/index.php?30612)
from GNU make's CVS repository (revision 1.194).

Taken from pkgsrc repository:  devel/gmake/patches/patch-ah

--- read.c.orig	2010-07-13 01:20:42.000000000 +0000
+++ read.c
@@ -3028,7 +3028,7 @@ parse_file_seq (char **stringp, unsigned
             {
               /* This looks like the first element in an open archive group.
                  A valid group MUST have ')' as the last character.  */
-              const char *e = p + nlen;
+              const char *e = p;
               do
                 {
                   e = next_token (e);
@@ -3084,19 +3084,19 @@ parse_file_seq (char **stringp, unsigned
          Go to the next item in the string.  */
       if (flags & PARSEFS_NOGLOB)
         {
-          NEWELT (concat (2, prefix, tp));
+          NEWELT (concat (2, prefix, tmpbuf));
           continue;
         }
 
       /* If we get here we know we're doing glob expansion.
          TP is a string in tmpbuf.  NLEN is no longer used.
          We may need to do more work: after this NAME will be set.  */
-      name = tp;
+      name = tmpbuf;
 
       /* Expand tilde if applicable.  */
-      if (tp[0] == '~')
+      if (tmpbuf[0] == '~')
 	{
-	  tildep = tilde_expand (tp);
+	  tildep = tilde_expand (tmpbuf);
 	  if (tildep != 0)
             name = tildep;
 	}
@@ -3152,7 +3152,10 @@ parse_file_seq (char **stringp, unsigned
             else
               {
                 /* We got a chain of items.  Attach them.  */
-                (*newp)->next = found;
+		if (*newp)
+		  (*newp)->next = found;
+		else
+		  *newp = found;
 
                 /* Find and set the new end.  Massage names if necessary.  */
                 while (1)
