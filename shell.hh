#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {

  static void prompt();
  static void sigIntHandler(int sig);
  static void sigChildHandler(int sig);
  static Command _currentCommand;
};

#endif
