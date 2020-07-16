#include <cstdio>
#include <unistd.h>
#include "shell.hh"
#include <string.h>
#include <signal.h>

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
  int pid = 0;
  printf("%d exited.\n", pid);
  printf("caught %d\n", sig);
}

int main() {
  Shell::prompt();

  struct sigaction signalAction;
  signalAction.sa_handler = sigIntHandler;
  sigemptyset(&signalAction.sa_mask);
  signalAction.sa_flags = SA_RESTART;

  int error = sigaction(SIGINT, &signalAction, NULL);
  if (error) {
    perror("sigaction");
    exit(-1);
  }

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
