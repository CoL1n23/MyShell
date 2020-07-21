/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <iostream>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <string.h>
#include <stdlib.h>

#include "command.hh"
#include "shell.hh"


Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _append = false;
    _background = false;
    _multi_output = false;
    _multi_input = false;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _append = false;

    _background = false;

    _multi_output = false;
    _multi_input = false;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

void Command::printenv() {
  extern char** environ;
  char** p = environ;
  while (*p != NULL) {
    printf("%s\n", *p);
    p++;
  }
  exit(0);
}

void Command::setenv(int i) {
  char* arg1 = new char[_simpleCommands[i]->_arguments[1]->length() + 1];
  strcpy(arg1, _simpleCommands[i]->_arguments[1]->c_str());
  char* arg2 = new char[_simpleCommands[i]->_arguments[2]->length() + 1]; 
  strcpy(arg2, _simpleCommands[i]->_arguments[2]->c_str());
  char* equal = new char[2]{'=', '\0'};
  char* arg = new char[strlen(arg1) + strlen(arg2) + 2];
  strcpy(arg, arg1);
  strcat(arg, equal);
  strcat(arg, arg2);
  // fprintf(stderr, "%s\n", arg);
  if (putenv(arg)) {
    perror("putenv");
    exit(-1);
  }
}

void Command::unsetenv(int i) {
  extern char** environ;
  char** p = environ;
  int index = 0;
  while (p[index] != NULL) {
    char* name;
    const char s[2] = "=";
    name = strtok(p[index], s);
    // printf("%s\n", name);
    if (!strcmp(_simpleCommands[i]->_arguments[1]->c_str(), name)) {
      environ[index] = environ[index + 1];
    }
    index++;
  }
}

void Command::cd(int i) {
  if (_simpleCommands[i]->_arguments.size() == 1) {
    // change to home directory
    if (chdir(getenv("HOME"))) {
      perror("chdir");
      exit(-1);
    }
  }
  else {
    if (chdir(_simpleCommands[i]->_arguments[1]->c_str())) {
      printf("cd: can't cd to %s\n", _simpleCommands[i]->_arguments[1]->c_str());
      exit(-1);
    }
  }
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }

    // Print contents of Command data structure
    // print();

    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec
 
    // detect "exit" and exit shell
    if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "exit")) {
      printf("Exiting...\n");
      exit(1);
    }
    
    if (_multi_output == true) {
      printf("Ambiguous output redirect.\n");
    }
    else if (_multi_input == true) {
      printf("Ambiguous input redirect.\n");
    }

    // save stdin/stdout/stderr
    int tmpin = dup(0);
    int tmpout = dup(1);
    int tmperr = dup(2);

    // setup stderr
    int fderr;
    if (_errFile != NULL && _append == false) {
      fderr = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0664);
    }
    else if (_errFile != NULL && _append == true) {
      fderr = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0664);
    }
    else {
      fderr = dup(tmperr);
    }
    dup2(fderr, 2);
    close(fderr);

    // set initial input, to either inFile or stdin
    int fdin;
    if (_inFile != NULL) {
      fdin = open(_inFile->c_str(), O_RDONLY, 0444);
      if (fdin == -1) {
        perror(_inFile->c_str());
	exit(1);
      }
    }
    else {
      fdin = dup(tmpin);
    }
    
    int ret;
    int fdout;
    for (size_t i = 0; i < _simpleCommands.size(); i++) {
      // redirect input and error
      dup2(fdin, 0);
      close(fdin);
      dup2(fderr, 2);
      close(fderr);

      // setenv function
      if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "setenv")) {
	setenv(i);
	break;
      }

      // unsetenv function
      if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "unsetenv")) {
        unsetenv(i);
        break;
      }

      // cd function
      if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "cd")) {
        cd(i);
	break;
      }

      // setup output
      if (i == _simpleCommands.size() - 1) {
        // last simple command
	// redirect output to outFile or stdout
	if (_outFile != NULL && _append == false) {
          fdout = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0664);
	}
	else if (_outFile != NULL && _append == true) {
	  fdout = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0664);
	}
	else {
          fdout = dup(tmpout);
	}
      }
      else {
        // not last simple command
	// creat pipe
	int fdpipe[2];
	pipe(fdpipe);
	fdout = fdpipe[1];
	fdin = fdpipe[0];
      }

      // redirect output
      dup2(fdout, 1);
      close(fdout);

      // creat child process to execute child process
      ret = fork();
      if (ret == 0 ) {
        // child process
	
	// printenv function
	if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv")) {
	  printenv();
	}
	
	// initialize args c_string array to contain args
	const char** args = new const char*[_simpleCommands[i]->_arguments.size() + 1];
	
	// append NULL at end
	args[_simpleCommands[i]->_arguments.size()] = NULL;
	
	// convert all cpp_strings to c_strings
	for (size_t j = 0; j < _simpleCommands[i]->_arguments.size(); j++) {
          args[j] = _simpleCommands[i]->_arguments[j]->c_str();
	}

	// execute cmd_and_args
        execvp(_simpleCommands[i]->_arguments[0]->c_str(), (char* const*) args);
	
	// free allocated object
	free(args);

	// print error if execvp encounters error
	perror("execvp");
        _exit(1);
      }
    }  // end for

    // restore stdin/stdout
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperr, 2);
    close(tmpin);
    close(tmpout);
    close(tmperr);

    // handle background optional
    if (!_background) {
      waitpid(ret, NULL, 0);
    }

    // Clear to prepare for next command
    clear();

    // Print new prompt
    if (isatty(0)) {
      Shell::prompt();
    }
}

SimpleCommand * Command::_currentSimpleCommand;
