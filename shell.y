
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
#include <string.h>
#include <sys/types.h>
#include <regex.h>
#include <dirent.h>
#include "shell.hh"

void yyerror(const char * s);
int yylex();

void expandWildcards(std::string* arg_s) {
  const char* arg_c = arg_s->c_str();
  if (strchr(arg_c, '*') == NULL && strchr(arg_c, '?' == NULL)) {
    Command::_currentSimpleCommand->insertArgument(arg_s);
    return;
  }

  char* regex = (char *)malloc(2 * strlen(arg_c) + 10);
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
  while ((ent = readdir(dir)) != NULL) {
    if (regexec(ent->d_name, re) == 0) {
      std::string new_arg = std::string(ent->d_name);
      Command::_currentSimpleCommand->insertArgument(&new_arg);
    }
  }
  closedir(dir);
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
