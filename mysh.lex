%option nounput noinput

%{
#include "mysh.y.h"
%}

%%

"cd" { return CD; }

"pwd" { return PWD; }

"exit" { return EXIT; }

";" { return SEM; }

"#"[^\n]* {}

[^ \t;]+ { yylval.str = yytext; return WORD; }

[ \t] {}

%%

void set_input_string(const char* in) {
  yy_scan_string(in);
}

void end_lexical_scan(void) {
  yy_delete_buffer(YY_CURRENT_BUFFER);
}
