#include <cstdio>
#include <cstdlib>
#include <regex.h>
#include <iostream>
#include <sys/types.h>
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
  
  // check for environ var expansion
  const char env_var[] = "^.*\\$\\{[^\\}]+\\}.*$";

  regex_t regex_env;
  int outcome_env = regcomp(&regex_env, env_var, REG_EXTENDED|REG_NOSUB);
  if (outcome_env != 0) {
    printf("error in regcomp\n");
    exit(1);
  }
  regmatch_t match_env;
  outcome_env = regexec(&regex_env, string, 0, &match_env, 0);
  printf("%s result env is %d\n", string, outcome_env);
  if (outcome_env == 0) {  // matches
    printf("match\n");
    int index = 0;
    int env_num = 0;
    while (string[index] != '\0') {
      if (string[index] == '$') {
        env_num++;
        index += 2;
      }
      index++;
    }

    index = 0;
    int* start_indices = new int[env_num];
    int* end_indices = new int[env_num];
    int counter = 0;
    while (string[index] != '\0') {
      if (string[index] == '{') {
        start_indices[counter] = index + 1;
      }
      else if (string[index] == '}') {
        end_indices[counter++] = index - 1;
      }
      index++;
    }

    char** env_names = new char*[env_num];
    for (int i = 0; i < env_num; i++) {
      env_names[i] = new char[end_indices[i] - start_indices[i] + 2];
      env_names[i][end_indices[i] - start_indices[i] + 1] = '\0';
      for (int j = 0; j < end_indices[i] - start_indices[i] + 1; j++) {
        env_names[i][j] = string[start_indices[i] + j];
      }
    }

    // get content in environ var
    char** env_strs = new char*[env_num];
    for (int i = 0; i < env_num; i++) {
      if (!strcmp(env_names[i], "$")) {
        env_strs[i] = new char[10];
        pid_t pid = getpid();
        sprintf(env_strs[i], "%d", pid);
      }
      else if (!strcmp(env_names[i], "?")) {
        printf("?\n");
      }
      else if (!strcmp(env_names[i], "!")) {
        printf("?\n");
      }
      else if (!strcmp(env_names[i], "_")) {
        printf("?\n");
      }
      else if (!strcmp(env_names[i], "SHELL")) {
        printf("?\n");
      }
      else {
        env_strs[i] = getenv(env_names[i]);
      }
      // printf("%s\n", env_strs[i]);
    }

    char** others = new char*[env_num + 1];
    int ctr = 0;
    for (int i = 0; i < env_num + 1; i++) {
      if (i == 0) {
        if (start_indices[i] == 2) {
          others[i] = NULL;
        }
        else {
          others[i] = new char[start_indices[i] - 1];
          others[i][start_indices[i] - 2] = '\0';
          for (int j = 0; j < start_indices[i] - 2; j++) {
            others[i][ctr++] = string[j];
          }
        }
      }
      else if (i == env_num) {
        if (end_indices[i - 1] == (int)strlen(string) - 2) {
          others[i] = NULL;
        }
        else {
          others[i] = new char[strlen(string) - end_indices[i - 1] - 2];
          others[i][end_indices[i - 1] - 2] = '\0';
          for (int j = end_indices[i - 1] + 2; j < (int)strlen(string); j++) {
            others[i][ctr++] = string[j];
          }
        }
      }
      else {
        if (end_indices[i - 1] == (start_indices[i] - 4)) {
          others[i] = NULL;
        }
        else {
          others[i] = new char[start_indices[i] - end_indices[i - 1] - 3];
          others[i][start_indices[i] - end_indices[i - 1] - 2] = '\0';
          for (int j = end_indices[i - 1] + 2; j < start_indices[i] - 2; j++) {
            others[i][ctr++] = string[j];
          }
        }
      }
      ctr = 0;
    }
    // concat everything to final result
    char* result = new char[1000];
    for (int i = 0; i < env_num; i++) {
      if (i == 0) {
        if (others[i] != NULL) {
          strcpy(result, others[i]);
        }
      }
      if (env_strs[i] != NULL) {
        strcat(result, env_strs[i]);
      }
      if (others[i + 1] != NULL) {
        strcat(result, others[i + 1]);
      }
    }
    // strcat(result, "wrong");
    // printf("%s\n", result);
    argument = new std::string(result);
  }

  // check for tilde expansion
  const char tilde1[] = "^~[/]?$";

  regex_t regex_t1;
  int outcome_t1 = regcomp(&regex_t1, tilde1, REG_EXTENDED|REG_NOSUB);
  if (outcome_t1 != 0) {
    printf("error in regcomp\n");
    exit(1);
  }
  regmatch_t match_t1;
  outcome_t1 = regexec(&regex_t1, string, 0, &match_t1, 0);
  printf("%s result t1 is %d\n", string, outcome_t1);
  if (outcome_t1 == 0) {
    printf("match2\n");
    argument = new std::string(getenv("HOME"));
  }

  const char tilde2[] = "^~[/]?[^\\]+$";

  regex_t regex_t2;
  int outcome_t2 = regcomp(&regex_t2, tilde2, REG_EXTENDED|REG_NOSUB);
  if (outcome_t2 != 0) {
    printf("error in regcomp\n");
    exit(1);
  }
  regmatch_t match_t2;
  outcome_t2 = regexec(&regex_t2, string, 0, &match_t2, 0);
  printf("%s result2 is %d\n", string, outcome_t2);
  if (outcome_t2 == 0) {
    char* username = new char[(int)argument->size()];
    for (int i = 1; i < (int)argument->size(); i++) {
      username[i - 1] = argument->c_str()[i];
    }
    username[(int)argument->size() - 1] = '\0';
    printf("%s\n", username);
    struct passwd *result = getpwnam(username);
    printf("%s\n", result->pw_dir);
    exit(0);
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
