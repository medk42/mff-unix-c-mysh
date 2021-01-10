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
#include <sys/types.h>
#include <sys/wait.h>

#define MAX_CMD_LENGTH 4096
#define MAX_PROMPT_LENGTH 256
#define SYNTAX_ERROR 254
#define UNKNOWN_COMMAND_ERROR 127
#define COMMAND_TOO_LONG_MESSAGE "Command is too long (longer than %d)"


int yylex();
void yyerror(char* s);

static char* get_working_dir();
static void change_dir(char* new_dir);
void set_input_string(const char* in);
void end_lexical_scan(void);
void parse_file(FILE* in);
static void add_to_str_list(char* str);
static void clear_str_list();
static char* strdup_checked(const char* str);
static void* malloc_checked(size_t count);
static size_t get_str_list_size();
static void int_handler(int intno);
static void set_sigint_handler(struct sigaction *handler);

STAILQ_HEAD(str_list_head, str_entry) str_head = STAILQ_HEAD_INITIALIZER(str_head);

struct str_entry {
	char* str;
	STAILQ_ENTRY(str_entry) str_entries;
};

int return_value = 0;
size_t lineno = 1;


struct sigaction interactive_handler = { .sa_handler = int_handler, .sa_flags = SA_RESTART };
struct sigaction ignore_handler = { .sa_handler = SIG_IGN, .sa_flags = SA_RESTART };
struct sigaction original_handler = { .sa_handler = SIG_DFL };
%}

%union {
	char* str;
}

%token<str> WORD
%token CD PWD EXIT SEM NL

%type<str> program

%%

file:
	line
	| line NL file { ++lineno; }
	;

line:
	%empty
	| command 
	| command SEM line
	;

command:
	CD arguments { // parsing arguments
		size_t arg_count = get_str_list_size();
		return_value = 0;
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
					return_value = 1;
				}
			} else {
				change_dir(new_dir);
			}
		} else {
			warnx("cd: too many arguments");			
			return_value = 1;
		}

		clear_str_list();
	}
	| PWD arguments { // ignoring arguments like bash
		return_value = 0;
		clear_str_list();
		char* cwd = get_working_dir();
		printf("%s\n", cwd);
		free(cwd);
	}
	| EXIT arguments {
		if (get_str_list_size() > 0) {
			warnx("exit: too many arguments");
		}
		exit(return_value);
	}
	| program arguments { 
		pid_t pid = fork();
		if (pid == -1) {
			err(1, "fork");
		} else if (pid == 0) { // child
			set_sigint_handler(&original_handler);

			size_t args_len = get_str_list_size() + 2;
			char **args = (char**) malloc_checked(sizeof(char*) * args_len);
			args[0] = $1;
			args[args_len - 1] = 0;
			char **arg = args+1;
			
			struct str_entry *item;
			STAILQ_FOREACH(item, &str_head, str_entries) {
				*arg = item->str;
				++arg;
			}

			execvp($1, args);
			err(UNKNOWN_COMMAND_ERROR, "%s", $1);
		}

		free($1);
		clear_str_list();
		
		int status;
		if (waitpid(pid, &status, 0) == -1) {
			err(1, "wait");
		}

		if (WIFEXITED(status)) {
			return_value = WEXITSTATUS(status);
		} else if (WIFSIGNALED(status)) {
			return_value = WTERMSIG(status) + 128;
			dprintf(2, "Killed by signal %d.\n", WTERMSIG(status));
			if (WTERMSIG(status) == SIGINT) {
				YYACCEPT;
			}
		} else {
			errx(1, "Child exited through unsupported operation");
		}
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
		warn("cd: %s", new_dir);
		return_value = 1;
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

static void* malloc_checked(size_t count) {
	void* res = malloc(count);
	if (res == NULL) {
		errx(1, "Out of memory");
	}
	return res;
}

static void add_to_str_list(char* str) {
	struct str_entry *elem = malloc_checked(sizeof(struct str_entry));
	
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



static char* get_prompt() {
	char* cwd = get_working_dir();
	char* prompt = (char*) malloc_checked(sizeof(char) * MAX_PROMPT_LENGTH);
	char* home = getenv("HOME");

	if (!home) {
		home = "";
	}

	int at_home = strcmp(cwd, home) == 0; 

	if (at_home) {
		free(cwd);
		cwd = "~";
	}

	if (snprintf(prompt, MAX_PROMPT_LENGTH, "mysh:%s$ ", cwd) >= MAX_PROMPT_LENGTH) {
		warnx("Prompt length limited to %d characters.", MAX_PROMPT_LENGTH);
	}

	if (!at_home) {
		free(cwd);
	}

	return prompt;
}

static void int_handler(int intno) {
	if (intno == SIGINT) {
		write(1, "\n", 1); // Move to a new line 
		rl_on_new_line(); // Regenerate the prompt on a newline
		rl_replace_line("", 0); // Clear the previous text
		rl_redisplay();
	}
}

static void set_sigint_handler(struct sigaction *handler) {
	if (sigaction(SIGINT, handler, NULL) == -1) {
		err(1, "Couldn't register signal handler");
	}
}

int parse_string(const char* in) {
  set_input_string(in);
  int rv = yyparse();
  end_lexical_scan();
  return rv;
}

int run_interactive() {
	while (1) {
		char* prompt = get_prompt();

		set_sigint_handler(&interactive_handler);
		char* line = readline(prompt);
		set_sigint_handler(&ignore_handler);

		free(prompt);

		if (line == NULL) {
			write(1, "\n", 1); 
			return return_value;
		}
		
		if (strlen(line) <= MAX_CMD_LENGTH) {
			parse_string(line);

			if (line && *line) {
				add_history(line);
			}
		} else {
			warnx(COMMAND_TOO_LONG_MESSAGE, MAX_CMD_LENGTH);
		}
		free(line);
	}
}

int run_argument(char* command) {
	set_sigint_handler(&ignore_handler);

	if (strlen(command) <= MAX_CMD_LENGTH) {
		parse_string(command);
		return return_value;
	} else {
		warnx(COMMAND_TOO_LONG_MESSAGE, MAX_CMD_LENGTH);
	}
	return 0;
}

int run_file(char* file) {
	set_sigint_handler(&ignore_handler);

	FILE* in = fopen(file, "r");
	if (in == NULL) {
		err(1, "%s", file);
	}

	parse_file(in);
	fclose(in);

	return return_value;
}


int main(int argc, char** argv) {
	--argc;
	++argv;
	if (argc > 0) {
		if (strcmp(*argv, "-c") == 0) {
			if (argc > 1) {
				char* command = *(argv + 1);
				return run_argument(command);
			} else {
				errx(2, "-c: option requires an argument");
			}
		} else {
			char* file = *argv;
			return run_file(file);
		}
	} else {
		return run_interactive();
	}

	return 0;
}

void yyerror(char *s) {
	extern char* yytext;
	dprintf(2, "error:%ld: %s near unexpected token '%s'\n", lineno, s, yytext);
	return_value = SYNTAX_ERROR;
}


