
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

#define MAXFILENAME 1024

void yyerror(const char * s);
int yylex();

int max_files;
int n_files;
char** files;

int compareFiles(const void* file1, const void* file2) {
  const char* filename1 = *(const char**) file1;
  const char* filename2 = *(const char**) file2;

  return strcasecmp(filename1, filename2);
}

void expandWildcard(char* prefix, char* suffix) {
  if (suffix[0] == 0) {
    if (n_files == max_files) {
      max_files *= 2;
      files = (char **) realloc(files, max_files * sizeof(char *));
    }
    // printf("%s\n", prefix);
    files[n_files] = prefix;
    n_files++;
    return;
  }

  // get next component in suffix
  char* s = strchr(suffix, '/');
  char component[MAXFILENAME];
  if (s != NULL) {
    strncpy(component, suffix, s - suffix);
    suffix = s + 1;
  }
  else {
    // copy rest of suffix if last component
    strcpy(component, suffix);
    suffix += strlen(suffix);
  }

  // examine component
  char new_prefix[MAXFILENAME];
  if (strchr(component, '*') == NULL && strchr(component, '?') == NULL) {
    // concat component with prefix if no wildcard
    if (prefix == NULL) {
      sprintf(new_prefix, "%s", component);
    }
    else {
      sprintf(new_prefix, "%s/%s", prefix, component);
    }
    expandWildcard(new_prefix, suffix);  // move on to next component
    return;  
  }

  // translate wildcards to regex
  char* regex = (char*) malloc(2 * strlen(component) + 10);
  *regex = '^';
  regex++;
  char* c = component;
  while (*c) {
    if (*c == '*') {
      *regex = '.';
      regex++;
      *regex = '*';
      regex++;
    }
    else if (*c == '?') {
      *regex = '.';
      regex++;
    }
    else if (*c == '.') {
      *regex = '\\';
      regex++;
      *regex = '.';
      regex++;
    }
    else {
      *regex = *c;
      regex++;
    }
    c++;
  }
  *regex = '$';
  regex++;
  *regex = 0;

  // compile regex
  regex_t re;
  int result = regcomp(&re, regex, REG_EXTENDED|REG_NOSUB);
  if (result != 0) {
    perror("regcomp");
    return;
  }

  // set up dir
  char* dir;
  if (prefix == NULL) {
    // set dir to current dir if prefix is empty
    dir = (char *)".";
  }
  else {
    dir = prefix;
  }

  DIR* d = opendir(dir);
  if (d == NULL) {
    return;
  }

  // check what entries match
  struct dirent* ent;
  regmatch_t match;
  while ((ent = readdir(d)) != NULL) {
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      if (prefix == NULL) {
        sprintf(new_prefix, "%s", ent->d_name);
      }
      else {
        sprintf(new_prefix, "%s/%s", prefix, ent->d_name);
      }

      if (ent->d_name[0] == '.') {
        if (component[0] == '.') {
          // if user has specified hidden files
          expandWildcard(new_prefix, suffix);
        }
      }
      else {
        expandWildcard(new_prefix, suffix);
      }
    }
  }
  closedir(d);
}

void expandWildcardsIfNecessary(std::string* arg_s) {
  const char* arg_cc = arg_s->c_str();
  char* arg_c = new char[strlen(arg_cc) + 1];
  strcpy(arg_c, arg_cc);

  // check if argument has wildcard
  if (strchr(arg_c, '*') == NULL && strchr(arg_c, '?') == NULL) {
    Command::_currentSimpleCommand->insertArgument(arg_s);
    return;
  }

  files = (char **) malloc(max_files * sizeof(char *));

  expandWildcard(NULL, arg_c);
  for (int i = 0; i < n_files; i++) {
    printf("%s 1\n", files[i]);
  }

  qsort(files, n_files, sizeof(char *), compareFiles);
  for (int i = 0; i < n_files; i++) {
    printf("%s\n", files[i]);
  }

  for (int i = 0; i < n_files; i++) {
    // printf("%s %d\n", files[i], n_files);
    std::string* new_arg = new std::string(files[i]);
    Command::_currentSimpleCommand->insertArgument(new_arg);
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
    max_files = 10;
    n_files = 0;
    expandWildcardsIfNecessary($2);
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
