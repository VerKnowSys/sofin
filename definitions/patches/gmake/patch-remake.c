Fix parallel builds. One port that exhibits this issue is webkit-gtk >= 1.8.

http://savannah.gnu.org/bugs/?30653

Index: remake.c
===================================================================
RCS file: /sources/make/make/remake.c,v
retrieving revision 1.147
diff -u -r1.147 remake.c
--- remake.c	13 Jul 2010 01:20:42 -0000	1.147
+++ remake.c	5 Aug 2010 01:02:18 -0000
@@ -614,6 +614,12 @@
                 d->file->dontcare = file->dontcare;
               }
 
+	    /* We may have already encountered this file earlier in the same
+	     * pass before we knew we'd be updating this target. In that 
+	     * case calling update_file now would result in the file being 
+	     * inappropriately pruned so we toggle the considered bit back 
+	     * off first. */
+            d->file->considered = !considered;
 
 	    dep_status |= update_file (d->file, depth);
 
Index: tests/scripts/features/parallelism
===================================================================
RCS file: /sources/make/make/tests/scripts/features/parallelism,v
retrieving revision 1.16
diff -u -r1.16 parallelism
--- tests/scripts/features/parallelism	5 Jul 2010 18:32:03 -0000	1.16
+++ tests/scripts/features/parallelism	5 Aug 2010 01:02:18 -0000
@@ -164,6 +164,27 @@
 
 rmfiles('inc.mk');
 
+utouch(-15, 'file2');
+utouch(-10, 'file4');
+utouch(-5,  'file1');
+
+run_make_test(q!
+.INTERMEDIATE: file3
+
+file4: file3
+	@mv -f $< $@
+
+file3: file2
+	@touch $@
+
+file2: file1
+	@touch $@
+!,
+              '--no-print-directory -j2');
+
+rmfiles('file1', 'file2', 'file3', 'file4');
+
+
 if ($all_tests) {
     # Implicit files aren't properly recreated during parallel builds
     # Savannah bug #26864
