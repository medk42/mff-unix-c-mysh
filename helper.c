#include "helper.h"
#include "defaults.h"

#include <err.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>

char* get_working_dir() {
	char* cwd = getcwd(NULL, 0);
	if (cwd == NULL) {
		err(1, "getcwd");
	}
	return cwd;
}

int change_dir(char* new_dir) {
	char* old_dir = get_working_dir();
	
	if (chdir(new_dir) == -1) {
		free(old_dir);
		warn("cd: %s", new_dir);
		return 1;
	}

	if (setenv("PWD", new_dir, 1) == -1) {
		err(1, "setenv");
	}

	if (setenv("OLDPWD", old_dir, 1) == -1) {
		err(1, "setenv");
	}

	free(old_dir);

    return 0;
}

char* strdup_checked(const char* str) {
	char* res = strdup(str);
	if (res == NULL) {
		err(1, "Out of memory");
	}
	return res;
}

void* malloc_checked(size_t count) {
	void* res = malloc(count);
	if (res == NULL) {
		errx(1, "Out of memory");
	}
	return res;
}

char* get_prompt() {
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

void set_sigint_handler(struct sigaction *handler) {
	if (sigaction(SIGINT, handler, NULL) == -1) {
		err(1, "Couldn't register signal handler");
	}
}