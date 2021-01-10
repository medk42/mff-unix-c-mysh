%code requires {
	int get_return_value();
}

%{
#include "helper.h"
#include "defaults.h"
#include "list.h"

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

extern int yylex();
void yyerror(char* s);

struct str_list_head str_head = STAILQ_HEAD_INITIALIZER(str_head);

int return_value = 0;
size_t lineno = 1;

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
		size_t arg_count = get_str_list_size(&str_head);
		return_value = 0;
		if (arg_count == 0) {
			char* home = getenv("HOME");
			if (home) {
				return_value = change_dir(home);
			}
		} else if (arg_count == 1) {
			char* new_dir = STAILQ_FIRST(&str_head)->str;
			if (strcmp("-", new_dir) == 0) {
				char* old_dir = getenv("OLDPWD");
				if (old_dir) {
					printf("%s\n", old_dir);
					return_value = change_dir(old_dir);
				} else {
					warnx("cd: OLDPWD not set");
					return_value = 1;
				}
			} else {
				return_value = change_dir(new_dir);
			}
		} else {
			warnx("cd: too many arguments");			
			return_value = 1;
		}

		clear_str_list(&str_head);
	}
	| PWD arguments { // ignoring arguments like bash
		return_value = 0;
		clear_str_list(&str_head);
		char* cwd = get_working_dir();
		printf("%s\n", cwd);
		free(cwd);
	}
	| EXIT arguments {
		if (get_str_list_size(&str_head) > 0) {
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

			size_t args_len = get_str_list_size(&str_head) + 2;
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
		clear_str_list(&str_head);
		
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
	%empty { clear_str_list(&str_head); }
	| arguments WORD { add_to_str_list($2, &str_head); }
	| arguments CD { add_to_str_list("cd", &str_head); }
	| arguments PWD { add_to_str_list("pwd", &str_head); }
	| arguments EXIT { add_to_str_list("exit", &str_head); }
	;

%%

void yyerror(char *s) {
	extern char* yytext;
	dprintf(2, "error:%ld: %s near unexpected token '%s'\n", lineno, s, yytext);
	return_value = SYNTAX_ERROR;
}

int get_return_value() {
	return return_value;
}