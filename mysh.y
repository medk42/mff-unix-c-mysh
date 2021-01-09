%{
#include <stdio.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <signal.h>
#include <err.h>
#include <unistd.h>
#include <sys/queue.h>
#include <string.h>
#include <stdlib.h>

#define MAX_CMD_LENGTH 4096

int yylex();
void yyerror(char* s);

static char* get_working_dir();
static void change_dir(char* new_dir);
void set_input_string(const char* in);
void end_lexical_scan(void);
static void add_to_str_list(char* str);
static void clear_str_list();
static char* strdup_checked(const char* str);
static size_t get_str_list_size();

STAILQ_HEAD(str_list_head, str_entry) str_head = STAILQ_HEAD_INITIALIZER(str_head);

struct str_entry {
	char* str;
	STAILQ_ENTRY(str_entry) str_entries;
};
%}

%union {
	char* str;
}

%token<str> WORD
%token CD PWD EXIT

%type<str> program

%%

line:
   command
	;	

command:
	CD arguments { // parsing arguments
		size_t arg_count = get_str_list_size();
		if (arg_count == 0) {
			char* home = getenv("HOME");
			if (home) {
				change_dir(home);
			}
		} else if (arg_count == 1) {
			char* new_dir = STAILQ_FIRST(&str_head)->str;
			if (strcmp("-", new_dir) == 0) {
				char* old_dir = getenv("OLDPWD");
				if (old_dir) {
					printf("%s\n", old_dir);
					change_dir(old_dir);
				} else {
					warnx("cd: OLDPWD not set");
				}
			} else {
				change_dir(new_dir);
			}
		} else {
			warnx("cd: too many arguments");			
		}

		clear_str_list();
	}
	| PWD arguments { // ignoring arguments like bash
		clear_str_list();
		char* cwd = get_working_dir();
		printf("%s\n", cwd);
		free(cwd);
	}
	| EXIT arguments {
		if (get_str_list_size() > 0) {
			warnx("exit: too many arguments");
		}
		_exit(0); // TODO add correct return value
	}
	| program arguments { 
		printf("Program: %s\nArgs: ", $1);
		struct str_entry *item;
		STAILQ_FOREACH(item, &str_head, str_entries) {
			printf("%s, ", item->str);
		}
		printf("\n");

		free($1);
		clear_str_list();
	}
	;

program:
	WORD { $$ = strdup_checked($1); }
	;

arguments:
	%empty { clear_str_list(); }
	| arguments WORD { add_to_str_list($2); }
	| arguments CD { add_to_str_list("cd"); }
	| arguments PWD { add_to_str_list("pwd"); }
	| arguments EXIT { add_to_str_list("exit"); }
	;

%%

static char* get_working_dir() {
	char* cwd = getcwd(NULL, 0);
	if (cwd == NULL) {
		err(1, "getcwd");
	}
	return cwd;
}

static void change_dir(char* new_dir) {
	char* old_dir = get_working_dir();
	
	if (chdir(new_dir) == -1) {
		free(old_dir);
		warn("cd");
		return;
	}

	if (setenv("PWD", new_dir, 1) == -1) {
		err(1, "setenv");
	}

	if (setenv("OLDPWD", old_dir, 1) == -1) {
		err(1, "setenv");
	}

	free(old_dir);
}

static char* strdup_checked(const char* str) {
	char* res = strdup(str);
	if (res == NULL) {
		err(1, "Out of memory");
	}
	return res;
}

static void add_to_str_list(char* str) {
	struct str_entry *elem = malloc(sizeof(struct str_entry));
	if (elem == NULL) {
		errx(1, "Out of memory");
	}
	
	elem->str = strdup_checked(str);

	STAILQ_INSERT_TAIL(&str_head, elem, str_entries);
}

static void clear_str_list() {
	struct str_entry *second, *first = STAILQ_FIRST(&str_head);
	while (first != NULL) {
		second = STAILQ_NEXT(first, str_entries);
		free(first->str);
		free(first);
		first = second;
	}
	STAILQ_INIT(&str_head);
}

static size_t get_str_list_size() {
	size_t size = 0;
	struct str_entry *item;
	STAILQ_FOREACH(item, &str_head, str_entries) {
		size++;
	}
	return size;
}

static void int_handler(int intno) {
	if (intno == SIGINT) {
		write(1, "\n", 1); // Move to a new line 
		rl_on_new_line(); // Regenerate the prompt on a newline
		rl_replace_line("", 0); // Clear the previous text
		rl_redisplay();
	}
}

int parse_string(const char* in) {
  set_input_string(in);
  int rv = yyparse();
  end_lexical_scan();
  return rv;
}

int main() {
	struct sigaction handler = { 0 };
	handler.sa_handler = int_handler;
	
	if (sigaction(SIGINT, &handler, NULL) == -1) {
		err(1, "Couldn't register signal handler");
	}

	while (1) {
		char *line = readline("> ");
		if (line == NULL) {
			write(1, "\n", 1); 
			execlp("ls", "ls", NULL); // TODO remove
			break;
		}
		
		if (strlen(line) <= MAX_CMD_LENGTH) {
			parse_string(line);

			if (line && *line) {
				add_history(line);
			}
		} else {
			warnx("Command is too long (longer than %d)", MAX_CMD_LENGTH);
		}
		free(line);
	}
	return 0;
}

void yyerror(char *s) {
	fprintf(stderr, "error: %s\n", s);
}


