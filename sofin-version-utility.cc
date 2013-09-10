/*
    Author: Daniel (dmilith) Dettlaff
    © 2013 - VerKnowSys
*/


#include <stdio.h>
#include <stdlib.h>

#ifdef __linux__
    #include <gnu/libc-version.h>
    #include <string.h>
#endif

#ifdef __FreeBSD__
    #include <sys/param.h>
#endif

#ifdef __APPLE__
    #include <sys/types.h>
    #include <sys/sysctl.h>
    #include <string.h>
#endif


int main(int argc, char *argv[]) {

    /* for Linux distribution, just give glibc major and minor version */
    #ifdef __linux__
        char* version = new char[5];
        strncpy(version, gnu_get_libc_version(), 4);
        printf("%s\n", version);
        delete version;
    #endif

    /* for FreeBSD, give major and minor version from OS cause there's only one FreeBSD :} */
    #ifdef __FreeBSD__
        const int modifier = 100000;
        int major = __FreeBSD_version / modifier;
        printf("%1d.%1d\n", major, (__FreeBSD_version - (major * modifier)) / 1000);
    #endif

    /* for Darwin, give major version of OS */
    #ifdef __APPLE__
        const int significant = 4;
        int mib[2];
        size_t len;
        char *kernelVersion, *version;
        mib[0] = CTL_KERN;
        mib[1] = KERN_OSRELEASE;
        sysctl(mib, 2, NULL, &len, NULL, 0);
        kernelVersion = (char*)malloc(len * sizeof(char));
        sysctl(mib, 2, kernelVersion, &len, NULL, 0);
        version = new char[significant];
        strncpy(version, kernelVersion, significant);
        free(kernelVersion);
        printf("%s\n", version);
        delete version;
    #endif

    return EXIT_SUCCESS;
}
