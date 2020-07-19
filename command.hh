#ifndef command_hh
#define command_hh

#include "simpleCommand.hh"

// Command Data Structure

struct Command {
  std::vector<SimpleCommand *> _simpleCommands;
  std::string * _outFile;
  std::string * _inFile;
  std::string * _errFile;
  bool _append;
  bool _background;
  bool _multi_output;
  bool _multi_input;

  Command();
  void insertSimpleCommand( SimpleCommand * simpleCommand );
  
  void printenv(int i);
  void setenv(int i);

  void clear();
  void print();
  void execute();

  static SimpleCommand *_currentSimpleCommand;
};

#endif
