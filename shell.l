
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <stdio.h>

#include "y.tab.hh"
#include "command.hh"

static void yyunput (int c, char *buf_ptr);

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

"&" {
  return AMPERSAND;
}

">" {
  return GREAT;
}

">>" {
  return GREATGREAT;
}

">&" {
  return GREATAMPERSAND;
}

"2>" {
  return TWOGREAT;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"<" {
  return LESS;
}

"|" {
  return PIPE;
}

\"[^\t\n]*\" {
  /* string contains quotes */
  int size = strlen(yytext);
  int counter =  0;
  char yytext_trimed[size - 1];
  yytext_trimed[size - 2] = '\0';
  for (int i = 1; i < size - 1; i++) {
    yytext_trimed[counter] = yytext[i];
    counter++;
  }
  yylval.cpp_string = new std::string(yytext_trimed);
  return WORD;
}

[^ \t\n]*\\[^ \t\n]* {
  /* string contains slash */
  int size = strlen(yytext);
  int counter = 0;
  int pos[10];
  int index = 0;
  for (int i = 0; i < size; i++) {
    if (yytext[i] == '\\') {
      pos[index] = i;
      index++;
      i++;
    }
  }
  char yytext_trimed[size - index + 1];
  yytext_trimed[size - index] = '\0';
  int index_2 = 0;
  for (int i = 0; i < size; i++) {
    if (i != pos[index_2]) {
      yytext_trimed[counter] = yytext[i];
      counter++;
    }
    else {
      index_2++;
    }
  }
  yylval.cpp_string = new std::string(yytext_trimed);
  return WORD;
}

\$\(.*\) {
  /* subshell */
  // create two pipes
  int pin[2], pout[2];
  pipe(pin);   // pin: parent writes command, child reads and executes
  pipe(pout);  // pout: child sends output, parents reads and prints

  char* sub_command = new char[strlen(yytext) - 2];
  sub_command[strlen(sub_command) - 1] = '\0';

  int index = 0;
  for (int i = 2; i < strlen(yytext) - 1; i++) {
    sub_command[index] = yytext[i];
    index++;
  }

  write(pin[1], sub_command, strlen(sub_command) + 1);
  write(pin[1], "\n", 1);
  write(pin[1], "exit\n", 5);
  close(pin[1]);

  // save stdin/stdout/stderr
  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2); 

  dup2(pin[0], 0);
  dup2(pout[1], 1);
  close(pin[0]);
  close(pout[1]);

  int ret = fork();
  if (ret == 0) {
    // child process
    const char** args = new const char*[2];
    args[1] = "proc/self/exe";
    args[2]  = NULL;

    // execute argument list
    execvp("/proc/self/exe", (char* const*) args);
    perror("execvp subshell");
    _exit(1);
  }
  else if (ret > 0) {
    // parent process
    // restore stdin/stdout/stderr
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperr, 2);
    close(tmpin);
    close(tmpout);
    close(tmperr);

    // read input from child process
    char sub_result_char;
    char* sub_result = new char[1000];
    int counter = 0;
    while (read(pout[0], &sub_result_char, 1)) {
      if (sub_result_char == '\n' || sub_result_char == '\t') {
        sub_result[counter++] = ' ';
      }
      else {
        sub_result[counter++] = sub_result_char;
      }
    }
    sub_result[counter] = '\0';
    close(pout[0]);

    // write result to command line
    for (int i = strlen(sub_result) - 1; i >= 0; i--) {
      myunputc(sub_result[i]);
    }
  }
  else {
    // fork failed
    perror("fork subshell");
    exit(1);
  }
}

source[ ].* {
  /* source file */
  // get source file name
  char* filename = new char[strlen(yytext) - 6];
  filename[strlen(filename) - 1] = '\0';
  int index = 0;
  for (int i = 7; i < strlen(yytext); i++) {
    filename[index++] = yytext[i];
  }

  // read content in source file
  char* line = NULL;
  size_t length = 0;
  FILE* file = fopen(filename, "r");
  if (file == NULL) {
    perror("fopen");
    exit(1);
  }
  while (true) {
    ssize_t char_count = getline(&line, &length, file);
    if (char_count != -1) {
      // unput line in source file to shell
      for (int i = (int)(strlen(line) - 1); i >= 0; i--) {
        myunputc(line[i]);
      }
      myunputc('\n');
    }
    else {
      break;
    }
  }

  fclose(file);
  free(line);
}

[^ \n\t]*\$\{[^ \t\n|&<>]+\}[^ \n\t]* {
  /* environ var expansion */
  // get environ var name
  int index = 0;
  int env_num = 0;
  while (yytext[index] != '\0') {
    if (yytext[index] == '$') {
      env_num++;
      index += 2;
    }
    index++;
  }

  index = 0;
  int* start_indices = new int[env_num];
  int* end_indices = new int[env_num];
  int counter = 0;
  while (yytext[index] != '\0') {
    if (yytext[index] == '{') {
      start_indices[counter] = index + 1;
    }
    else if (yytext[index] == '}') {
      end_indices[counter++] = index - 1;
    }
    index++;
  }

  char** env_names = new char*[env_num];
  for (int i = 0; i < env_num; i++) {
    env_names[i] = new char[end_indices[i] - start_indices[i] + 2];
    env_names[i][end_indices[i] - start_indices[i] + 1] = '\0';
    for (int j = 0; j < end_indices[i] - start_indices[i] + 1; j++) {
      env_names[i][j] = yytext[start_indices[i] + j];
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
      env_strs[i] = new char[5];
      sprintf(env_strs[i], "%d", ret_code);
    }
    else if (!strcmp(env_names[i], "!")) {
      env_strs[i] = new char[10];
      sprintf(env_strs[i], "%d", last_bg);
    }
    else if (!strcmp(env_names[i], "_")) {
      env_strs[i] = prev_command;
    }
    else if (!strcmp(env_names[i], "SHELL")) {
      env_strs[i] = new char[100];
      readlink("/proc/self/exe", env_strs[i], 100);
    }
    else {
      dup2(1, 2);
      env_strs[i] = getenv(env_names[i]);
    }
    // printf("%s\n", env_strs[i]);
  }

  /*
  * following code just replaces content with env var and returns it
  */
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
          others[i][ctr++] = yytext[j];
        }
      }
    }
    else if (i == env_num) {
      if (end_indices[i - 1] == strlen(yytext) - 2) {
        others[i] = NULL;
      }
      else {
        others[i] = new char[strlen(yytext) - end_indices[i - 1] - 2];
        others[i][end_indices[i - 1] - 2] = '\0';
        for (int j = end_indices[i - 1] + 2; j < strlen(yytext); j++) {
          others[i][ctr++] = yytext[j];
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
          others[i][ctr++] = yytext[j];
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

  // printf("%s\n", result);
  if (result != NULL) {
    yylval.cpp_string = new std::string(result);
  }
  return WORD;
}

[^ \t\n|&<>$][^ \t\n|&<>]* {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
