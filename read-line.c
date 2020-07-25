/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048

extern void tty_raw_mode(void);

// Buffer where line is stored
int line_length;
char line_buffer[MAX_BUFFER_LINE];

// Cursor location
int cursor;

// Simple history array
// This history does not change. 
// Yours have to be updated.
int history_index;
char history[1000][2048];
/*= {
  "ls -al | grep x", 
  "ps -e",
  "cat read-line-example.c",
  "vi hello.c",
  "make",
  "ls -al | grep xxx | grep yyy"
};
*/
int history_length = 0;

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  // Set terminal in raw mode
  tty_raw_mode();

  history_length = 0;

  line_length = 0;
  cursor = 0;

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);

    if (ch>=32 && ch != 127) {
      // It is a printable character. 

      // If max number of character reached return.
      if (line_length==MAX_BUFFER_LINE-2) break; 

      if (cursor == line_length) {
        // add char to buffer.
        line_buffer[line_length]=ch;
	write(1,&ch,1);
      }
      else {
	// backup rear line_buffer
	char rear[line_length - cursor];
	for (int i = cursor; i < line_length; i++) {
	  rear[i - cursor] = line_buffer[i];
	}

	// insert at cursor position
	line_buffer[cursor] = ch;
	write(1,&ch,1);

	// restore rear line_buffer
	for (int i = cursor + 1; i < line_length + 1; i++) {
	  line_buffer[i] = rear[i - cursor - 1];
	  write(1,&rear[i - cursor - 1], 1);
	}

	// cursor goes back to previous position
	for (int i = cursor + 1; i < line_length + 1; i++) {
	  ch = 8;
	  write(1,&ch,1);
        }
      }
      line_length++;
      cursor++;
    }
    else if (ch==10) {
      // <Enter> was typed. Return line
      
      if (strlen(line_buffer) > 0) {
	strcpy(history[history_length++], line_buffer);
      }

      // Print newline
      write(1,&ch,1);

      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0]=0;
      break;
    }
    else if ((ch == 8 || ch == 127) && cursor > 0) {
      // <backspace> was typed. Remove previous character read.
      // Go back one character
      ch = 8;
      write(1,&ch,1);

      if (cursor == line_length) {
        // Write a space to erase the last character read
        ch = ' ';
        write(1,&ch,1);

        // Go back one character
        ch = 8;
        write(1,&ch,1);

        // Remove one character from buffer
        line_buffer[line_length - 1] = 0;
      }
      else {
	// move everything after cursor forward by 1
        for (int i = cursor; i < line_length; i++) {
          line_buffer[i - 1] = line_buffer[i];
	  write(1, &line_buffer[i - 1], 1);
	}

	// ease last character
	ch = ' ';
	write(1,&ch,1);
	line_buffer[line_length - 1] = 0;

	// bring cursor back to previous position
	for (int i = 0; i < line_length - cursor + 1; i++) {
	  ch = 8;
	  write(1,&ch,1);
	}
      }

      line_length--;
      cursor--;
    }
    else if (ch == 4 && cursor < line_length) {
      // handle ctrl-h
      for (int i = cursor; i < line_length - 1; i++) {
        line_buffer[i] = line_buffer[i + 1];
	write(1, &line_buffer[i + 1], 1);
      }

      ch = ' ';
      write(1, &ch, 1);
      line_buffer[line_length - 1] = 0;

      for (int i = 0; i < line_length - cursor; i++) {
	ch = 8;
	write(1,&ch,1);
      }

      line_length--;
    }
    else if (ch==1) {
      while (cursor > 0) {
	// go back one character
	ch = 8;
        write(1,&ch,1);

	cursor--;
      }
    }
    else if (ch==5) {
      while (cursor < line_length) {
        // go back one character
        ch = line_buffer[cursor];
        write(1,&ch,1);

        cursor++;
      }
    }
    else if (ch==27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //
      char ch1; 
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);
      if (ch1==91 && ch2==65) {
	// Up arrow. Print next line in history.

	// Erase old line
	// Print backspaces
	int i = 0;
	for (i =0; i < line_length; i++) {
	  ch = 8;
	  write(1,&ch,1);
	}

	// Print spaces on top
	for (i =0; i < line_length; i++) {
	  ch = ' ';
	  write(1,&ch,1);
	}

	// Print backspaces
	for (i =0; i < line_length; i++) {
	  ch = 8;
	  write(1,&ch,1);
	}	

	history_index++;
	if (history_index > history_length) {
          history_index = history_length;
	}
	// Copy line from history
	strcpy(line_buffer, history[history_length - history_index]);
	line_length = strlen(line_buffer);

	// echo line
	write(1, line_buffer, line_length);
      }
      else if (ch1 == 91 && ch2 == 66) {

      }
      else if (ch1 == 91 && ch2 == 68) {
        // left arrow
	if (cursor > 0) {
	  // go back one character
	  ch = 8;
          write(1,&ch,1);

	  cursor--;
	}
      }
      else if (ch1 == 91 && ch2 == 67) {
	// right arrow
        if (cursor < line_length) {
          ch = line_buffer[cursor];
	  write(1,&ch,1);
	  cursor++;
	}
      }
    }

  }

  // Add eol and null char at the end of string
  line_buffer[line_length]=10;
  line_length++;
  line_buffer[line_length]=0;

  return line_buffer;
}

