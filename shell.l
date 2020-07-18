
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr  );

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
  char yytext_trimed[size];
  yytext_trimed[size - 1] = '\0';
  int pos = 0;
  /*
  for (int i = 0; i < size; i++) {
    if (yytext[i] == '\') {
      pos = i;
      break;
    }
  }
  for (int i = 0; i < size; i++) {
    if (i != pos) {
      yytext_trimed[counter] = yytext[i];
      counter++;
    }
  }
  yylval.cpp_string = new std::string(yytext_trimed);
  return WORD;
  */
}


[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
