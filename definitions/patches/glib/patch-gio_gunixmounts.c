--- gio/gunixmounts.c.orig	2011-06-05 19:18:49.000000000 -0400
+++ gio/gunixmounts.c	2011-11-09 04:20:49.000000000 -0500
@@ -135,6 +135,9 @@ struct _GUnixMountMonitor {
 
   GFileMonitor *fstab_monitor;
   GFileMonitor *mtab_monitor;
+
+  guint mount_poller_source;
+  GList *mount_poller_mounts;
 };
 
 struct _GUnixMountMonitorClass {
@@ -146,6 +149,8 @@ static GUnixMountMonitor *the_mount_moni
 static GList *_g_get_unix_mounts (void);
 static GList *_g_get_unix_mount_points (void);
 
+static guint64 mount_poller_time = 0;
+
 G_DEFINE_TYPE (GUnixMountMonitor, g_unix_mount_monitor, G_TYPE_OBJECT);
 
 #define MOUNT_POLL_INTERVAL 4000
@@ -172,6 +177,7 @@ G_DEFINE_TYPE (GUnixMountMonitor, g_unix
 #endif
 
 #if defined(HAVE_GETMNTINFO) && defined(HAVE_FSTAB_H) && defined(HAVE_SYS_MOUNT_H)
+#include <sys/param.h>
 #include <sys/ucred.h>
 #include <sys/mount.h>
 #include <fstab.h>
@@ -222,20 +228,28 @@ g_unix_is_mount_path_system_internal (co
     "/",              /* we already have "Filesystem root" in Nautilus */ 
     "/bin",
     "/boot",
+    "/compat/linux/proc",
+    "/compat/linux/sys",
     "/dev",
     "/etc",
     "/home",
     "/lib",
     "/lib64",
+    "/libexec",
     "/media",
     "/mnt",
     "/opt",
+    "/rescue",
     "/root",
     "/sbin",
     "/srv",
     "/tmp",
     "/usr",
+    "/usr/X11R6",
     "/usr/local",
+    "/usr/obj",
+    "/usr/ports",
+    "/usr/src",
     "/var",
     "/var/log/audit", /* https://bugzilla.redhat.com/show_bug.cgi?id=333041 */
     "/var/tmp",       /* https://bugzilla.redhat.com/show_bug.cgi?id=335241 */
@@ -271,6 +285,7 @@ guess_system_internal (const char *mount
     "devfs",
     "devpts",
     "ecryptfs",
+    "fdescfs",
     "kernfs",
     "linprocfs",
     "proc",
@@ -1056,6 +1071,10 @@ get_mounts_timestamp (void)
       if (stat (monitor_file, &buf) == 0)
 	return (guint64)buf.st_mtime;
     }
+  else
+    {
+      return mount_poller_time;
+    }
   return 0;
 }
 
@@ -1198,6 +1217,13 @@ g_unix_mount_monitor_finalize (GObject *
       g_object_unref (monitor->mtab_monitor);
     }
 
+  if (monitor->mount_poller_source > 0)
+    {
+      g_source_remove (monitor->mount_poller_source);
+      g_list_foreach (monitor->mount_poller_mounts, (GFunc)g_unix_mount_free, NULL);
+      g_list_free (monitor->mount_poller_mounts);
+    }
+
   the_mount_monitor = NULL;
 
   G_OBJECT_CLASS (g_unix_mount_monitor_parent_class)->finalize (object);
@@ -1278,6 +1304,51 @@ mtab_file_changed (GFileMonitor      *mo
   g_signal_emit (mount_monitor, signals[MOUNTS_CHANGED], 0);
 }
 
+static gboolean
+mount_change_poller (gpointer user_data)
+{
+  GUnixMountMonitor *mount_monitor;
+  GList *current_mounts;
+  gboolean has_changed = FALSE;
+
+  mount_monitor = user_data;
+  current_mounts = _g_get_unix_mounts ();
+
+  if (g_list_length (current_mounts) != g_list_length (mount_monitor->mount_poller_mounts))
+    {
+      g_list_foreach (mount_monitor->mount_poller_mounts, (GFunc)g_unix_mount_free, NULL);
+      has_changed = TRUE;
+    }
+  else
+    {
+      int i;
+
+      for (i = 0; i < g_list_length (current_mounts); i++)
+        {
+          GUnixMountEntry *m1;
+	  GUnixMountEntry *m2;
+
+	  m1 = (GUnixMountEntry *)g_list_nth_data (current_mounts, i);
+	  m2 = (GUnixMountEntry *)g_list_nth_data (mount_monitor->mount_poller_mounts, i);
+          if (! has_changed && g_unix_mount_compare (m1, m2) != 0)
+            has_changed = TRUE;
+
+	  g_unix_mount_free (m2);
+	}
+    }
+
+  g_list_free (mount_monitor->mount_poller_mounts);
+  mount_monitor->mount_poller_mounts = current_mounts;
+
+  if (has_changed)
+    {
+      mount_poller_time = (guint64)time (NULL);
+      g_signal_emit (mount_monitor, signals[MOUNTS_CHANGED], 0);
+    }
+
+  return TRUE;
+}
+
 static void
 g_unix_mount_monitor_init (GUnixMountMonitor *monitor)
 {
@@ -1300,6 +1371,12 @@ g_unix_mount_monitor_init (GUnixMountMon
       
       g_signal_connect (monitor->mtab_monitor, "changed", (GCallback)mtab_file_changed, monitor);
     }
+  else
+    {
+      monitor->mount_poller_mounts = _g_get_unix_mounts ();
+      mount_poller_time = (guint64)time (NULL);
+      monitor->mount_poller_source = g_timeout_add_seconds (3, (GSourceFunc)mount_change_poller, monitor);
+    }
 }
 
 /**
