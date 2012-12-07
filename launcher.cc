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


using namespace std;

#define DEFAULT_SHELL_COMMAND "/bin/sh"
#define DEFAULT_SOFIN_SCRIPTNAME "/usr/bin/sofin.sh"
#define EXECVP_EXIT 666
#define FORK_EXIT 667


void parse(char *line, char **argv) {
    while (*line != '\0') {
        while (*line == ' ' || *line == '\t' || *line == '\n') *line++ = '\0';
        *argv++ = line;
        while (*line != '\0' && *line != ' ' && *line != '\t' && *line != '\n') line++;
    }
    *argv = '\0';
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
    } else
        while (wait(&status) != pid);
}


int main(int argc, char const *argv[]) {

    char str[32];
    char *arguments[argc];
    stringstream cmd, lockfile;
    if (getuid() == 0)
        lockfile << "/var/run/.sofin-lock-" << getuid() << endl;
    else
        lockfile << "/Users/" << getuid() << "/.sofin-lock-" << getuid() << endl;

    cmd << string(DEFAULT_SOFIN_SCRIPTNAME);
    if (argc > 1) {
        for (int i = 1; i < argc; ++i) {
            cmd << " " << argv[i];
        }
        if ( // hacky but working way of dealing with tasks without need of locking:
            (strcmp(argv[1], "ver") == 0) ||
            (strcmp(argv[1], "version") == 0) ||
            (strcmp(argv[1], "list") == 0) ||
            (strcmp(argv[1], "installed") == 0) ||
            (strcmp(argv[1], "fulllist") == 0) ||
            (strcmp(argv[1], "fullinstalled") == 0) ||
            (strcmp(argv[1], "export") == 0) ||
            (strcmp(argv[1], "exp") == 0) ||
            (strcmp(argv[1], "exportapp") == 0) ||
            (strcmp(argv[1], "getshellvars") == 0) ||
            (strcmp(argv[1], "log") == 0) ||
            (strcmp(argv[1], "available") == 0)
        ) { // just execute without locking:
            parse((char*)cmd.str().c_str(), arguments);
            execute(arguments, getuid());
            return 0;
        }
    }

    while (true) {
        const char* lockff = lockfile.str().c_str();
        const int lfp = open(lockff, O_RDWR | O_CREAT, 0600);
        if (lfp < 0) {
            cerr << "Lock file occupied: " << lockff << ". Error: " << strerror(errno) << endl;
            exit(1); /* can not open */
        }
        if (lockf(lfp, F_TLOCK, 0) < 0) {
            cerr << ".";
            sleep(3);
        } else {
            sprintf(str, "%d\n", getpid());
            write(lfp, str, strlen(str)); /* record pid to lockfile */

            signal(SIGTSTP, SIG_IGN); /* ignore tty signals */
            signal(SIGTTOU, SIG_IGN);
            signal(SIGTTIN, SIG_IGN);

            parse((char*)cmd.str().c_str(), arguments);
            execute(arguments, getuid());
            break;
        }
    }
    return 0;
}
