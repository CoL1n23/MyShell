#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <sys/types.h>
#include <regex.h>
#include <pwd.h>
#include <string.h>
#include <unistd.h>
#include "simpleCommand.hh"

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}

void SimpleCommand::insertArgument( std::string * argument ) {
  const char* string = argument->c_str();
  // check for tilde expansion (has 3 parts)
  const char tilde1[] = "^~[/]?$";

  regex_t regex_t1;
  int outcome_t1 = regcomp(&regex_t1, tilde1, REG_EXTENDED|REG_NOSUB);
  if (outcome_t1 != 0) {
    printf("error in regcomp\n");
    exit(1);
  }
  regmatch_t match_t1;
  outcome_t1 = regexec(&regex_t1, string, 0, &match_t1, 0);
  // printf("%s result t1 is %d\n", string, outcome_t1);
  if (outcome_t1 == 0) {
    argument = new std::string(getenv("HOME"));
  }

  const char tilde2[] = "^~[/]?[^/]+$";

  regex_t regex_t2;
  int outcome_t2 = regcomp(&regex_t2, tilde2, REG_EXTENDED|REG_NOSUB);
  if (outcome_t2 != 0) {
    printf("error in regcomp\n");
    exit(1);
  }
  regmatch_t match_t2;
  outcome_t2 = regexec(&regex_t2, string, 0, &match_t2, 0);
  // printf("%s result t2 is %d\n", string, outcome_t2);
  if (outcome_t2 == 0) {
    char* username = new char[(int)argument->size()];
    for (int i = 1; i < (int)argument->size(); i++) {
      username[i - 1] = argument->c_str()[i];
    }
    username[(int)argument->size() - 1] = '\0';
    struct passwd *result = getpwnam(username);
    argument = new std::string(result->pw_dir);
  }

  const char tilde3[] = "^~[/]?[^/]+/.*$";

  regex_t regex_t3;
  int outcome_t3 = regcomp(&regex_t3, tilde3, REG_EXTENDED|REG_NOSUB);
  if (outcome_t3 != 0) {
    printf("error in regcomp\n");
    exit(1);
  }
  regmatch_t match_t3;
  outcome_t3 = regexec(&regex_t3, string, 0, &match_t3, 0);
  // printf("%s result t3 is %d\n", string, outcome_t3);
  if (outcome_t3 == 0) {
    int index = 2; // index of second slash
    while (argument->c_str()[index] != '/') {
      index++;
    }
    char* username = new char[index];
    username[index - 1] = '\0';
    for (int i = 1; i < index; i++) {
      username[i - 1] = argument->c_str()[i];
    }
    struct passwd *result = getpwnam(username);

    char* fullpath = new char[100];
    strcpy(fullpath, result->pw_dir);
    char* rest = new char[(int)argument->size() - index + 1];
    for (int i = index; i < (int)argument->size(); i++) {
      rest[i - index] = argument->c_str()[i];
    }
    rest[(int)argument->size() - index] = '\0';
    strcat(fullpath, rest);
    argument = new std::string(fullpath);
  }

  // simply add the argument to the vector
  _arguments.push_back(argument);
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << *arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}
