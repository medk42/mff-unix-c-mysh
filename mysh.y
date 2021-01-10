%code requires {
	int get_return_value();
}

%{
#include "helper.h"
#include "defaults.h"
#include "list.h"
#include "parser.h"

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
struct program_list_head program_head = STAILQ_HEAD_INITIALIZER(program_head);
struct list_str_list_head list_str_head = STAILQ_HEAD_INITIALIZER(list_str_head);

int return_value = 0;
size_t lineno = 1;
%}

%union {
	char* str;
}

%token<str> WORD
%token CD PWD EXIT SEM NL

%type<str> program

%%

file:
	line {
		return_value = parse_line(&program_head, &list_str_head, return_value);
		if (is_finished()) {
			YYACCEPT;
		}
	}
	| line NL file { 
		++lineno;

		return_value = parse_line(&program_head, &list_str_head, return_value);
		if (is_finished()) {
			YYACCEPT;
		}
	}
	;

line:
	%empty
	| command 
	| command SEM line
	;

command:
	CD arguments { add_to_program_list(COMMAND_CD, 0, &program_head); }
	| PWD arguments { add_to_program_list(COMMAND_PWD, 0, &program_head); }
	| EXIT arguments { add_to_program_list(COMMAND_EXIT, 0, &program_head); }
	| program arguments { 
		add_to_program_list(COMMAND_GENERAL, $1, &program_head);
		free($1);
	}
	;

program:
	WORD { $$ = strdup_checked($1); }
	;

arguments:
	%empty { auto_add_to_list_str_list(&list_str_head); }
	| arguments WORD { add_to_last_list_str_list($2, &list_str_head); }
	| arguments CD { add_to_last_list_str_list("cd", &list_str_head); }
	| arguments PWD { add_to_last_list_str_list("pwd", &list_str_head); }
	| arguments EXIT { add_to_last_list_str_list("exit", &list_str_head); }
	;

%%

void yyerror(char* s) {
	extern char* yytext;
	dprintf(2, "error:%ld: %s near unexpected token '%s'\n", lineno, s, yytext);
	return_value = SYNTAX_ERROR;
}

int get_return_value() {
	return return_value;
}