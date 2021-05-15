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

struct redirection_data redirections = { .read_file = NULL, .write_file = NULL, .write_file_append = 0 };

int return_value = 0;
size_t lineno = 1;
%}

%union {
	char* str;
}

%token<str> WORD WRITE APPEND READ
%token CD PWD EXIT SEM NL PIPE UNK

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
	command_pipe { program_list___append(END_COMMAND_PIPE, 0, &program_head, redirections); }
	| line SEM command_pipe { program_list___append(END_COMMAND_PIPE, 0, &program_head, redirections); }
	;

command_pipe:
	redirected_command
	| redirected_command PIPE command_pipe
	;

redirected_command:
	redirection_list command
	;

command:
	CD arguments redirection_list {
		program_list___append(COMMAND_CD, 0, &program_head, redirections);

		reset_string(&(redirections.write_file));
		reset_string(&(redirections.read_file));
	}
	| PWD arguments redirection_list {
		program_list___append(COMMAND_PWD, 0, &program_head, redirections);

		reset_string(&(redirections.write_file));
		reset_string(&(redirections.read_file));
	}
	| EXIT arguments redirection_list {
		program_list___append(COMMAND_EXIT, 0, &program_head, redirections);

		reset_string(&(redirections.write_file));
		reset_string(&(redirections.read_file));
	}
	| program arguments redirection_list {
		program_list___append(COMMAND_GENERAL, $1, &program_head, redirections);

		free($1);
		reset_string(&(redirections.write_file));
		reset_string(&(redirections.read_file));
	}
	;

program:
	WORD { $$ = strdup_checked($1); }
	;

arguments:
	%empty { str_list_list___append_empty_str_list(&list_str_head); }
	| arguments redirection_list WORD { str_list_list___append_to_last($3, &list_str_head); }
	| arguments redirection_list CD { str_list_list___append_to_last("cd", &list_str_head); }
	| arguments redirection_list PWD { str_list_list___append_to_last("pwd", &list_str_head); }
	| arguments redirection_list EXIT { str_list_list___append_to_last("exit", &list_str_head); }
	;

redirection_list:
	%empty
	| redirection_list redirection
	;

redirection:
	WRITE {
		replace_string(&(redirections.write_file), $1);
		redirections.write_file_append = 0;
	}
	| APPEND {
		replace_string(&(redirections.write_file), $1);
		redirections.write_file_append = 1;
	}
	| READ { replace_string(&(redirections.read_file), $1); }
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