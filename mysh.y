%code requires {
	int get_return_value();
}

%{
#include "helper.h"
#include "defaults.h"
#include "list.h"
#include "parser.h"

#include <stdio.h>
#include <sys/queue.h>
#include <stdlib.h>

extern int yylex();
void yyerror(char* s);

struct str_list___head str_head = STAILQ_HEAD_INITIALIZER(str_head);
struct program_list___head program_head = STAILQ_HEAD_INITIALIZER(program_head);
struct str_list_list___head list_str_head = STAILQ_HEAD_INITIALIZER(list_str_head);

int return_value = 0;
size_t lineno = 1;
%}

%union {
	char* str;
}

%token<str> WORD WRITE APPEND READ
%token CD PWD EXIT SEM NL PIPE

%type<str> program

%%

file:
	line_opt {
		return_value = parse_line(&program_head, &list_str_head, return_value);
		if (is_finished()) {
			YYACCEPT;
		}
	}
	| line_opt NL file { 
		++lineno;

		return_value = parse_line(&program_head, &list_str_head, return_value);
		if (is_finished()) {
			YYACCEPT;
		}
	}
	;

line_opt:
	%empty
	| SEM
	| line
	| line SEM
	;

line:
	command_pipe { program_list___append(END_COMMAND_PIPE, 0, &program_head); }
	| line SEM command_pipe { program_list___append(END_COMMAND_PIPE, 0, &program_head); }
	;

command_pipe:
	redirected_command
	| redirected_command PIPE command_pipe
	;

redirected_command:
	redirections command
	;

command:
	CD arguments redirections { program_list___append(COMMAND_CD, 0, &program_head); }
	| PWD arguments redirections { program_list___append(COMMAND_PWD, 0, &program_head); }
	| EXIT arguments redirections { program_list___append(COMMAND_EXIT, 0, &program_head); }
	| program arguments redirections { 
		program_list___append(COMMAND_GENERAL, $1, &program_head);
		free($1);
	}
	;

program:
	WORD { $$ = strdup_checked($1); }
	;

arguments:
	%empty { str_list_list___append_empty_str_list(&list_str_head); }
	| arguments redirections WORD { str_list_list___append_to_last($3, &list_str_head); }
	| arguments redirections CD { str_list_list___append_to_last("cd", &list_str_head); }
	| arguments redirections PWD { str_list_list___append_to_last("pwd", &list_str_head); }
	| arguments redirections EXIT { str_list_list___append_to_last("exit", &list_str_head); }
	;

redirections:
	%empty
	| redirections redirection
	;

redirection:
	WRITE { warnx("write %s", $1); }
	| READ { warnx("read %s", $1); }
	| APPEND { warnx("append %s", $1); }
	;

%%

void yyerror(char* s) {
	extern char* yytext;
	dprintf(2, "error:%ld: %s near unexpected token '%s'\n", lineno, s, yytext);
	return_value = SYNTAX_ERROR;

	program_list___clear(&program_head);
    str_list_list___clear(&list_str_head);
}

int get_return_value() {
	return return_value;
}