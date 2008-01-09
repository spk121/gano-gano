#define _GNU_SOURCE
#define _XOPEN_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <termios.h>
#include <sys/stat.h>
#include <curses.h>
#include <libguile.h>
#include <pty.h>

int
open_pty_pair (int *amaster, int *aslave, char **name)
{
  int master, slave;
  struct termios tio;

  /* Get file descriptor of next available pseudo-terminal */
  master = getpt ();
  if (master < 0)
    return 0;

  printf ("Pseudo-terminal ID #%d\n", master);

  /* Change the ownership and access permissions to match the mastern
     terminal */
  if (grantpt (master) < 0 || unlockpt (master) < 0)
    goto close_master;

  *name = strdup(ptsname (master));
  if (*name == NULL)
    goto close_master;
  printf ("Pseudo-terminal slave name: %s\n", *name);

  slave = open (*name, O_RDWR);
  if (slave == -1)
    goto close_master;
  printf ("Slave ID #%d\n", slave);

  *amaster = master;
  *aslave = slave;

  if (tcgetattr (slave, &tio))
    goto close_slave;

  

  return 1;

 close_slave:
  close (slave);
  
 close_master:
  close (master);
  return 0;
}

int
open_terminal (char *pseudo_terminal_slave_name, 
	       int master_file_descriptor,
	       int slave_file_descriptor)
{
  int process_id;
  int name_length;
  struct termios terminal_attributes;
  char *s_flag;

  name_length = strlen(pseudo_terminal_slave_name);

  process_id = fork ();

  if (process_id == -1)
    {
      perror("fork");
      return 0;
    }
  else if (process_id == 0)
    {
      /* This is the child process */
      close (slave_file_descriptor);

      if (pseudo_terminal_slave_name[name_length - 2] == '/')
	{
	  asprintf (&s_flag, "-S%c/%d",
		    pseudo_terminal_slave_name[name_length - 1],
		    master_file_descriptor);
	}
      else
	{
	  printf ("error in name\n");
	  return 0;
	}

      printf ("xterm %s\n", s_flag);
      execlp ("xterm", "xterm", s_flag, NULL);
      /* Should not return */
      return 0;
    }
  else
    {
      /* This is the parent process */
      close (master_file_descriptor);

      /* Set to raw mode */
      tcgetattr (slave_file_descriptor, &terminal_attributes);
      cfmakeraw (&terminal_attributes);
      tcsetattr (slave_file_descriptor, TCSANOW, &terminal_attributes); 
      return process_id;
    }
  return 0;
}
    
int main(int argc, char **argv)
{
  int master, slave;
  pid_t pid;
  char name[512];
  int slave_read, slave_write;
  FILE *fp_slave_read, *fp_slave_write;
  SCREEN *screen;
  struct termios tio;
  struct winsize win;
  
  scm_init_guile ();

#if 0
  if (!open_pty_pair (&master, &slave, &name))
    {
      return EXIT_FAILURE;
    }
#else
  if (openpty (&master, &slave, name, &tio, &win) < 0)
    {
      return EXIT_FAILURE;
    }
#endif

  if (!(pid = open_terminal (name, master, slave)))
    {
      return EXIT_FAILURE;
    }
  
  slave_read = dup (slave);
  slave_write = dup (slave);
  close (slave);
  fp_slave_read = fdopen (slave_read, "r");
  fp_slave_write = fdopen (slave_write, "w");

  screen = newterm ("xterm", fp_slave_write, fp_slave_read);
  erase ();
  refresh ();

  scm_shell (argc, argv);

  endwin ();
  fclose (fp_slave_read);
  fclose (fp_slave_write);
  close (slave_write);
  close (slave_read);

  kill (pid, SIGTERM);
  return EXIT_SUCCESS;
}


