/*
    Author: Daniel (dmilith) Dettlaff
    © 2013 - VerKnowSys
*/


#include <stdio.h>
#include <stdlib.h>

#ifdef __FreeBSD__
    #include <sys/param.h>
#endif

#ifdef __APPLE__
    #include <sys/types.h>
    #include <sys/sysctl.h>
    #include <string.h>
#endif

#ifdef __linux__
    #include <gnu/libc-version.h>
    #include <string.h>
#endif

int main(int argc, char *argv[]) {

    /* for FreeBSD, give major and minor version from OS cause there's only one FreeBSD :} */
    #ifdef __FreeBSD__
        const int modifier = 100000;
        char buff[16];
        FILE *in;
        in = popen("/sbin/sysctl -n kern.osreldate", "r");
        fgets(buff, sizeof(buff), in);
        pclose(in);
        int ver = atoi(buff);
        int major = ver / modifier;
        printf("%1d.%1d\n", major, (ver - (major * modifier)) / 1000);
    #endif

    /* for Darwin, give major version of OS */
    #ifdef __APPLE__
        char buff[16];
        FILE *in;
        in = popen("/usr/bin/defaults read /System/Library/CoreServices/SystemVersion ProductUserVisibleVersion | /usr/bin/cut -d . -f1-2", "r");
        fgets(buff, sizeof(buff), in);
        pclose(in);
        printf("%s", buff);
    #endif

    /* for Linux distribution, just give glibc major and minor version */
    #ifdef __linux__
        char* version = new char[5];
        strncpy(version, gnu_get_libc_version(), 4);
        printf("%s\n", version);
        delete version;
    #endif

    #if defined(__minix)
        char buff[16];
        FILE *in;
        in = popen("/usr/bin/uname -r | /usr/bin/cut -d. -f1-2", "r");
        fgets(buff, sizeof(buff), in);
        pclose(in);
        printf("%s", buff);
    #endif

    return EXIT_SUCCESS;
}
