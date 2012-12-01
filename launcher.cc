/*
    Author: Daniel (dmilith) Dettlaff
    © 2012 - VerKnowSys
*/


#include <iostream>
#include <string>
#include <fstream>
#include <sstream>


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

    char *arguments[argc];
    stringstream cmd;
    cmd << string(DEFAULT_SOFIN_SCRIPTNAME);
    if (argc > 1) {
        for (int i = 1; i < argc; ++i) {
            cmd << " " + string(argv[i]);
        }
    }
    parse((char*)(cmd.str().c_str()), arguments);
    execute(arguments, getuid());

    return 0;
}
