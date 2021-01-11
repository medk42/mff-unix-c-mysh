%option nounput noinput noyywrap

%{
#include "mysh.y.h"
%}

%%

"cd" { return CD; }

"pwd" { return PWD; }

"exit" { return EXIT; }

";" { return SEM; }

"|" { return PIPE; }

\n { return NL; }

"#"[^\n]* {}

[^ \t;#\n]+ { yylval.str = yytext; return WORD; }

[ \t] {}

%%

void set_input_string(const char* in) {
  yy_scan_string(in);
}

void end_lexical_scan(void) {
  yy_delete_buffer(YY_CURRENT_BUFFER);
}

void parse_file(FILE* in) {
	yyin = in;
	yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE));
	yyparse();
}
