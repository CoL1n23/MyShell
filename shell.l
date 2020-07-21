
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
#include "y.tab.hh"

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


[^ \t\n|&<>$][^ \t\n|&<>]* {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

\$\([^\t\n]*\) {
  /* subshell */
  // create two pipes
  int pin[2], pout[2];
  pipe(pin);   // pin: parent writes command, child reads and executes
  pipe(pout);  // pout: child sends output, parents reads and prints

  // save stdin/stdout/stderr
  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2); 
 
  int ret = fork();
  if (ret == 0) {
    // child process
    // redirect input/output
    dup2(pin[0], 0);
    dup2(pout[1], 1);
    close(pout[1]);
    close(pin[1]);   // close writing end of pin
    close(pout[0]);  // close reading end of pout
    
    // read from parent process
    char result[100];
    read(pin[0], result, 100);
    close(pin[0]);
    for (int i = 0; i < strlen(result) + 2; i++) {
      fprintf(stderr, "%c\n", result[i]);
    }
    result[strlen(result)] = '\0';
    fprintf(stderr, "%s %d\n", result, strlen(result));

    /*
    // get argument list
    int n_space = 0;
    for (int i = 0; i < strlen(result); i++) {
      if (result[i] == ' ') {
        n_space++;
      }
    }

    char** args = new char*[n_space + 2];
    args[n_space + 1] = NULL;
    char* token = strtok(result, " ");
    int index = 0;
    while (token != NULL) {
      args[index] = token;
      token = strtok(NULL, " ");
      index++;
    }

    for (int i = 0; i < args.size(); i++) {
      fprintf("%s\n", args[i];
    }
    */

    // execute argument list
    execvp("/proc/self/exe", NULL);
    perror("execvp subshell");
    _exit(1);
  }
  else if (ret > 0) {
    // parent process
    // redirect input/output
    dup2(pout[0], 0);
    dup2(pin[1], 1);
    close(pout[0]);
    close(pin[0]);   // close reading end of pin
    close(pout[1]);  // close writing end of pout

    // get content in $(...)
    char* sub_command = new char[strlen(yytext) - 2];
    sub_command[strlen(sub_command) - 1] = '\n'; 
    
    int index = 0;
    for (int i = 2; i < strlen(yytext) - 1; i++) {
      sub_command[index] = yytext[i];
      index++;
    }

    // write to child process
    write(pin[1], sub_command, strlen(sub_command) + 1);
    // write(pin[1], "exit\n", 5);

    close(pin[1]);
  }
  else {
    // fork failed
    perror("fork subshell");
    exit(1);
  }

  dup2(tmpin, 0);
  dup2(tmpout, 1);
  dup2(tmperr, 2);
  close(tmpin);
  close(tmpout);
  close(tmperr);
}

