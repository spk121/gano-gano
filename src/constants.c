#include <curses.h>
#include <stdio.h>
#include <string.h>

#define E(x) \
{if (pass == 0) do_export (#x); \
else if (pass == 1) do_define (#x, x); \
else do_alist (#x, x);}

void do_alist (char *name, int val);
void do_define (char *name, int val);
void do_export (char *name);
void print_gname (char *name);


int main()
{
  int pass;

  initscr ();

  for (pass = 0; pass < 3; pass ++)
    {
      if (pass == 0)
	{
	  printf ("(define-module (ncurses constants)\n");
	  printf (":export (\n");
	  printf ("\t*color-alist*\n");
	  printf ("\t*key-alist*\n");
	  printf ("\t*attrib-alist*\n");
	  printf ("\t*line-graphics-alist*\n");
	  printf ("\n");
	}
      
      /* Colors */

      if (pass == 2)
	printf("(define *color-alist* '(\n");

      E(COLOR_BLACK);
      E(COLOR_RED);
      E(COLOR_GREEN);
      E(COLOR_YELLOW);
      E(COLOR_BLUE);
      E(COLOR_MAGENTA);
      E(COLOR_CYAN);
      E(COLOR_WHITE);

      if (pass == 2)
	printf("))\n");

      /* Keys */
      
      if (pass == 2)
	printf("(define *key-alist* '(\n");

      E(KEY_BREAK);
      E(KEY_DOWN);
      E(KEY_UP);
      E(KEY_LEFT);
      E(KEY_RIGHT);
      E(KEY_HOME);
      E(KEY_BACKSPACE);
      E(KEY_F0);
      E(KEY_DL);
      E(KEY_IL);
      E(KEY_DC);
      E(KEY_IC);
      E(KEY_EIC);
      E(KEY_CLEAR);
      E(KEY_EOS);
      E(KEY_EOL);
      E(KEY_SF);
      E(KEY_SR);
      E(KEY_NPAGE);
      E(KEY_PPAGE);
      E(KEY_STAB);
      E(KEY_CTAB);
      E(KEY_CATAB);
      E(KEY_ENTER);
      E(KEY_SRESET);
      E(KEY_RESET);
      E(KEY_PRINT);
      E(KEY_LL);
      E(KEY_A1);
      E(KEY_A3);
      E(KEY_B2);
      E(KEY_C1);
      E(KEY_C3);
      E(KEY_BTAB);
      E(KEY_BEG);
      E(KEY_CANCEL);
      E(KEY_CLOSE);
      E(KEY_COMMAND);
      E(KEY_COPY);
      E(KEY_CREATE);
      E(KEY_END);
      E(KEY_EXIT);
      E(KEY_FIND);
      E(KEY_HELP);
      E(KEY_MARK);
      E(KEY_MESSAGE);
      E(KEY_MOUSE);
      E(KEY_MOVE);
      E(KEY_NEXT);
      E(KEY_OPEN);
      E(KEY_OPTIONS);
      E(KEY_PREVIOUS);
      E(KEY_REDO);
      E(KEY_REFERENCE);
      E(KEY_REFRESH);
      E(KEY_REPLACE);
      E(KEY_RESIZE);
      E(KEY_RESTART);
      E(KEY_RESUME);
      E(KEY_SAVE);
      E(KEY_SBEG);
      E(KEY_SCANCEL);
      E(KEY_SCOMMAND);
      E(KEY_SCOPY);
      E(KEY_SCREATE);
      E(KEY_SDC);
      E(KEY_SDL);
      E(KEY_SELECT);
      E(KEY_SEND);
      E(KEY_SEOL);
      E(KEY_SEXIT);
      E(KEY_SFIND);
      E(KEY_SHELP);
      E(KEY_SIC);
      E(KEY_SLEFT);
      E(KEY_SMESSAGE);
      E(KEY_SMOVE);
      E(KEY_SNEXT);
      E(KEY_SOPTIONS);
      E(KEY_SPREVIOUS);
      E(KEY_SPRINT);
      E(KEY_SREDO);
      E(KEY_SREPLACE);
      E(KEY_SRIGHT);
      E(KEY_SRSUME);
      E(KEY_SSAVE);
      E(KEY_SSUSPEND);
      E(KEY_SUNDO);
      E(KEY_SUSPEND);
      E(KEY_UNDO);
    
      if (pass == 2)
	printf("))\n");


      /* Attributes */

      if (pass == 2)
	printf("(define *attrib-alist* '(\n");

      E(A_NORMAL);
      E(A_STANDOUT);
      E(A_UNDERLINE);
      E(A_REVERSE);
      E(A_BLINK);
      E(A_DIM);
      E(A_BOLD);
      E(A_PROTECT);
      E(A_INVIS);
      E(A_ALTCHARSET);
      E(A_CHARTEXT);

      if (pass == 2)
	printf("))\n");

#if 1      
      /* Line Graphics */

      if (pass == 2)
	printf("(define *line-graphics-alist* '(\n");

      E(ACS_BLOCK);
      E(ACS_BOARD);
      E(ACS_BTEE);
      E(ACS_BULLET);
      E(ACS_CKBOARD);
      E(ACS_DARROW);
      E(ACS_DEGREE);
      E(ACS_DIAMOND);
      E(ACS_GEQUAL);
      E(ACS_HLINE);
      E(ACS_LANTERN);
      E(ACS_LARROW);
      E(ACS_LEQUAL);
      E(ACS_LLCORNER);
      E(ACS_LRCORNER);
      E(ACS_LTEE);
      E(ACS_NEQUAL);
      E(ACS_PI);
      E(ACS_PLMINUS);
      E(ACS_PLUS);
      E(ACS_RARROW);
      E(ACS_RTEE);
      E(ACS_S1);
      E(ACS_S3);
      E(ACS_S7);
      E(ACS_S9);
      E(ACS_STERLING);
      E(ACS_TTEE);
      E(ACS_UARROW);
      E(ACS_ULCORNER);
      E(ACS_URCORNER);
      E(ACS_VLINE);

      if (pass == 2)
	printf("))\n");
#endif

      

      if (pass == 0)
	printf ("))\n");
    }
  
  endwin ();

  return 0;
}

void do_alist (char *name, int val)
{
  printf ("\t(");
  print_gname (name);
  printf (" . %d)\n", val);
}

void do_define (char *name, int val)
{
  printf ("(define *");
  print_gname (name);
  printf ("* %d)\n", val);
}

void do_export (char *name)
{
  printf ("\t*");
  print_gname (name);
  printf ("*\n");
}

void print_gname (char *name)
{
  size_t len = strlen (name);
  int i;
  
  for (i = 0; i < len; i++)
    {
      if (isalnum (name[i]))
	{
	  printf ("%c", tolower (name[i]));
	}
      else
	{
	  printf ("-");
	}
    }
}

