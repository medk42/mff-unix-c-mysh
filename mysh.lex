%option nounput noinput noyywrap

%{
#include "mysh.y.h"
#include "helper.h"
%}

word	[^ \t;#\n|]+

%%

"cd" { return CD; }

"pwd" { return PWD; }

"exit" { return EXIT; }

";" { return SEM; }

"|" { return PIPE; }

\n { return NL; }

"#"[^\n]* {}

"<"[ ]*{word} {
	yylval.str = skip_spaces(yytext + 1);
	return READ;
}

">>"[ ]*{word} {
	yylval.str = skip_spaces(yytext + 2);
	return APPEND;
}

">"[ ]*{word} {
	yylval.str = skip_spaces(yytext + 1);
	return WRITE;
}

{word} { yylval.str = yytext; return WORD; }

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
