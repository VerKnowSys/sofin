/*
    Author: Daniel (dmilith) Dettlaff
    © 2012 - VerKnowSys
*/


#include <iostream>
#include <string.h>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <errno.h>
#if defined(__FreeBSD__) || defined(__linux__)
    #include <cstdlib>
    #include <sys/wait.h>
#endif
#include <sys/user.h>


using namespace std;

#define DEFAULT_SHELL_COMMAND "/bin/sh"
#define DEFAULT_SOFIN_SCRIPTNAME "/usr/bin/sofin.sh"
#define SLEEP_TIME 2 /* seconds */

#define EXECVP_EXIT 666
#define FORK_EXIT 667
#define ACCESS_DENIED_EXIT 668


void parse(char *line, char **argv) {
    while (*line != '\0') {
        while (*line == ' ' || *line == '\t' || *line == '\n') *line++ = '\0';
        *argv++ = line;
        while (*line != '\0' && *line != ' ' && *line != '\t' && *line != '\n') line++;
    }
    *argv = NULL;
}


void execute(char **argv, int uid) {
    int status;
    pid_t  pid;
    if ((pid = fork()) < 0) {
        exit(FORK_EXIT);
    } else if (pid == 0) {
        if (execvp(*argv, argv) < 0) {
            exit(EXECVP_EXIT);
        }
    } else {
        while (wait(&status) != pid);
        if (status != 0) exit(1);
    }
}


int main(int argc, char const *argv[]) {

    char *arguments[argc];
    stringstream cmd;

    /* build command line */
    cmd << string(DEFAULT_SOFIN_SCRIPTNAME);
    if (argc > 1) {
        for (int i = 1; i < argc; ++i) {
            cmd << " " << argv[i];
        }
    }

    signal(SIGTSTP, SIG_IGN); /* ignore tty signals */
    signal(SIGTTOU, SIG_IGN);
    signal(SIGTTIN, SIG_IGN);

    parse((char*)cmd.str().c_str(), arguments);
    execute(arguments, getuid());
    return 0;
}
