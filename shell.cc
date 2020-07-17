#include <cstdio>
#include <unistd.h>
#include "shell.hh"
#include <string.h>
#include <signal.h>
#include <sys/wait.h>

int yyparse(void);

void Shell::prompt() {
  if (isatty(0)) {
    printf("myshell>");
    fflush(stdout);
  }
}

void sigIntHandler (int sig) {
  if (sig == SIGINT) {
    printf("\n");
    Shell::prompt();
  }
}

void sigChildHandler (int sig) {
  if (sig == SIGCHLD) {
    while (waitpid(-1, NULL, WNOHANG) > 0) {
    }
  }
}

int main() {
  Shell::prompt();

  // handle SIGINT
  struct sigaction sa_int;
  sa_int.sa_handler = sigIntHandler;
  sigemptyset(&sa_int.sa_mask);
  sa_int.sa_flags = SA_RESTART;

  int error_int = sigaction(SIGINT, &sa_int, NULL);
  if (error_int) {
    perror("sigaction");
    exit(-1);
  }

  /*
  // handle SIGCHILD
  struct sigaction sa_child;
  sa_child.sa_handler = sigChildHandler;
  sigemptyset(&sa_child.sa_mask);
  sa_child.sa_flags = SA_RESTART;

  int error_child = sigaction(SIGCHLD, &sa_child, NULL);
  if (error_child) {
    perror("sigaction");
    exit(-1);
  }
  */

  char s[20];
  fflush(stdout);
  fgets(s, 20, stdin);
  if (!strcmp(s, "exit\n")) {
    printf("Exiting...\n");
    exit(1);
  }

  yyparse();
}

Command Shell::_currentCommand;
