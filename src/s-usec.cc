#include <stdio.h>
#include <sys/time.h>


int main(void) {
    struct timeval now;
    gettimeofday(&now, NULL);
    printf("%ld%06ld\n", (long)now.tv_sec, (long)now.tv_usec);
    return 0;
}
