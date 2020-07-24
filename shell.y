
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE TWOGREAT  GREATGREAT AMPERSAND GREATAMPERSAND GREATGREATAMPERSAND LESS PIPE

%{
//#define yylex yylex
#include <cstdio>
#include <cstring>
#include <string.h>
#include <sys/types.h>
#include <regex.h>
#include <dirent.h>
#include <ctype.h>
#include <stdlib.h>
#include "shell.hh"

void yyerror(const char * s);
int yylex();

int compareFiles(const void* file1, const void* file2) {
  char* cp1 = strdup((const char *)file1);
  char* cp2 = strdup((const char *)file2);
 
  /* 
  int index = 0;    
  while (cp1[index] != '\0') {
    cp1[index] = tolower(cp1[index]);
    index++;
  }
  index = 0;
  while (cp2[index] != '\0') {
    cp2[index] = tolower(cp2[index]);
    index++;
  }
  */
  //printf("%s %s\n", cp1, cp2);
  int ret_val = strcmp(cp2, cp1);
  free(cp1);
  free(cp2);
  return ret_val;
}

void expandWildcards(std::string* arg_s) {
  const char* arg_c = arg_s->c_str();
  if (strchr(arg_c, '*') == NULL && strchr(arg_c, '?') == NULL) {
    Command::_currentSimpleCommand->insertArgument(arg_s);
    return;
  }

  char* regex = (char*)malloc(2 * strlen(arg_c) + 10);
  *regex = '^';
  regex++;
  while (*arg_c) {
    if (*arg_c == '*') {
      *regex = '.';
      regex++;
      *regex = '*';
      regex++;
    }
    else if (*arg_c == '?') {
      *regex = '.';
      regex++;
    }
    else if (*arg_c == '.') {
      *regex = '\\';
      regex++;
      *regex = '.';
      regex++;
    }
    else {
      *regex = *arg_c;
      regex++;
    }
    arg_c++;
  }
  *regex = '$';
  regex++;
  *regex = 0;

  regex_t re;
  int result = regcomp(&re, regex, REG_EXTENDED|REG_NOSUB);
  if (result != 0) {
    perror("regcomp");
    return;
  }

  DIR* dir = opendir(".");
  if (dir == NULL) {
    perror("opendir");
    return;
  }

  struct dirent* ent;
  int max = 10;
  int n_files = 0;
  char** files = (char **) malloc(max * sizeof(char *));
  regmatch_t match;
  while ((ent = readdir(dir)) != NULL) {
    if (regexec(&re, ent->d_name, 0, &match, 0) == 0) {
      if (n_files == max) {
        max *= 2;
        files = (char **) realloc(files, max * sizeof(char *));
      }
      if (ent->d_name[0] == '.') {
        if (arg_c[0] == '.') {
        files[n_files] = strdup(ent->d_name);
        n_files++;
        }
      }
      else {
        files[n_files] = strdup(ent->d_name);
        n_files++;
      }
    }
  }
  closedir(dir);

  qsort(files, n_files, sizeof(char *), compareFiles);

  for (int i = 0; i < n_files; i++) {
    std::string* new_arg = new std::string(files[i]);
    Command::_currentSimpleCommand->insertArgument(new_arg);
  }

  for (int i = 0; i < max; i++) {
    free(files[i]);
  }
  free(files);
}
%}

%%

goal:
  command_list
  ;

arg_list:
  arg_list WORD {
    /* printf("   Yacc: insert argument \"%s\"\n", $2->c_str()); */
    expandWildcards($2);
    /* Command::_currentSimpleCommand->insertArgument( $2 ); */
  }
  | /* can be empty */
  ;

cmd_and_args:
  WORD {
    /* printf("   Yacc: insert command \"%s\"\n", $1->c_str()); */
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  } arg_list {
    Shell::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

pipe_list:
  pipe_list PIPE cmd_and_args
  | cmd_and_args
  ;

io_modifier:
  GREATGREAT WORD {
    /* append output to file */
    /* printf("   Yacc: insert output \"%s\"\n", $2->c_str()); */
    
    /* set _multi_output to true if multiple output redirections are identified */
    if (Shell::_currentCommand._outFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }

    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._append = true;
  }
  | GREAT WORD {
    /* redirect output to file */
    /* printf("   Yacc: insert output \"%s\"\n", $2->c_str()); */
    
    /* set _multi_output to true if multiple output redirections are identified */
    if (Shell::_currentCommand._outFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }

    Shell::_currentCommand._outFile = $2;
  }
  | GREATGREATAMPERSAND WORD {
    /* append stdout and stderr to file */
    /* printf("   Yacc: insert output \"%s\"\n", $2->c_str()); */
    
    /* set _multi_output to true if multiple output redirections are identified */
    if (Shell::_currentCommand._outFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }
    /* set _multi_output to true if multiple error redirections are identified */
    if (Shell::_currentCommand._errFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }

    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = new std::string ($2->c_str());
    Shell::_currentCommand._append = true;
  }
  | TWOGREAT WORD{
    /* redirect stderr to file */
    /* printf("   Yacc: insert output \"%s\"\n", $2->c_str()); */
    
    /* set _multi_output to true if multiple error redirections are identified */
    if (Shell::_currentCommand._errFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }

    Shell::_currentCommand._errFile = $2;
  }
  | GREATAMPERSAND WORD {
    /* redirect stdout and stderr to file */
    /* printf("   Yacc: insert output \"%s\"\n", $2->c_str()); */
    
    /* set _multi_output to true if multiple output redirections are identified */
    if (Shell::_currentCommand._outFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }
    /* set _multi_output to true if multiple error redirections are identified */
    if (Shell::_currentCommand._errFile != NULL) {
      Shell::_currentCommand._multi_output = true;
    }
    
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = new std::string ($2->c_str());
  }
  | LESS WORD {
    /* redirect input to file */
    /* printf("   Yacc: insert input \"%s\"\n", $2->c_str()); */
    
    /* set _multi_output to true if multiple output redirections are identified */
    if (Shell::_currentCommand._inFile != NULL) {
      Shell::_currentCommand._multi_input = true;
    }

    Shell::_currentCommand._inFile = $2;
  }
  ;

io_modifier_list:
  io_modifier_list io_modifier
  | /* can be empty */
  ;

background_optional:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  | /* can be empty */
  ;

command_line:
  pipe_list io_modifier_list background_optional NEWLINE {
    /* printf("   Yacc: Execute command\n"); */
    Shell::_currentCommand.execute();
  }
  | NEWLINE {
    Shell::_currentCommand.execute();
  }
  | error NEWLINE {
    yyerrok;
  }
  ;

command_list:
  command_line
  | command_list command_line
  ;

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
