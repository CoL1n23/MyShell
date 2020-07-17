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
   
    if (_multi_output == true) {
      printf("Ambiguous output redirect.\n");
      exit(1);
    }
    else if (_multi_input == true) {
      printf("Ambiguous input redirect.\n");
      exit(1);
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

      extern char** environ;
      // creat child process to execute child process
      ret = fork();
      if (ret == 0 ) {
        // child process
	if (!strcmp(_simpleCommands[i]->_arguments[0], "printenv")) {
	  char** p = environ;
	  while (*p != NULL) {
	    print("%s\n", p);
	    p++;
	  }
	  exit(0);
	}
	
	// initialize args c_string array to contain args
        const char** args = (const char **) malloc((_simpleCommands[i]->_arguments.size() + 1) * sizeof(const char *));
	
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
        exit(1);
      }
    }

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
