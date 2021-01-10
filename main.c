#include <err.h>
#include <readline/history.h>
#include <readline/readline.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

#include "defaults.h"
#include "helper.h"
#include "mysh.y.h"

void int_handler(int intno);

extern void set_input_string(const char* in);
extern void end_lexical_scan(void);
extern void parse_file(FILE* in);

struct sigaction interactive_handler = { .sa_handler = int_handler, .sa_flags = SA_RESTART };
struct sigaction ignore_handler = { .sa_handler = SIG_IGN, .sa_flags = SA_RESTART };

void int_handler(int intno) {
	if (intno == SIGINT) {
		write(1, "\n", 1);	   // Move to a new line
		rl_on_new_line();		// Regenerate the prompt on a newline
		rl_replace_line("", 0);  // Clear the previous text
		rl_redisplay();
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
			return get_return_value();
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
		return get_return_value();
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

	return get_return_value();
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