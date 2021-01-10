#include "parser.h"
#include "helper.h"
#include "defaults.h"

#include <err.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <err.h>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/wait.h>

int finished = 0;

int is_finished() {
    return finished;
}

static int parse_cd(struct str_list_head* arg_head) {
    size_t arg_count = get_str_list_size(arg_head);
    
    if (arg_count == 0) {
        char* home = getenv("HOME");
        if (home) {
            return change_dir(home);
        }
    } else if (arg_count == 1) {
        char* new_dir = STAILQ_FIRST(arg_head)->str;
        if (strcmp("-", new_dir) == 0) {
            char* old_dir = getenv("OLDPWD");
            if (old_dir) {
                printf("%s\n", old_dir);
                return change_dir(old_dir);
            } else {
                warnx("cd: OLDPWD not set");
                return 1;
            }
        } else {
            return change_dir(new_dir);
        }
    } else {
        warnx("cd: too many arguments");			
        return 1;
    }

    return 0;
}

static int parse_pwd() { // ignoring arguments like bash
		char* cwd = get_working_dir();
		printf("%s\n", cwd);
		free(cwd);

        return 0;
}

static void parse_exit(struct str_list_head* arg_head, int return_value) {
    if (get_str_list_size(arg_head) > 0) {
        warnx("exit: too many arguments");
    }
    exit(return_value);
}

static int parse_general(char* command, struct str_list_head* arg_head) {
    pid_t pid = fork();
    if (pid == -1) {
        err(1, "fork");
    } else if (pid == 0) { // child
        struct sigaction original_handler = { .sa_handler = SIG_DFL };
        set_sigint_handler(&original_handler);

        size_t args_len = get_str_list_size(arg_head) + 2;
        char** args = (char**)malloc_checked(sizeof(char*) * args_len);
        args[0] = command;
        args[args_len - 1] = 0;
        char** arg = args+1;
        
        struct str_entry *item;
        STAILQ_FOREACH(item, arg_head, str_entries) {
            *arg = item->str;
            ++arg;
        }

        execvp(command, args);
        err(UNKNOWN_COMMAND_ERROR, "%s", command);
    }
    
    int status;
    if (waitpid(pid, &status, 0) == -1) {
        err(1, "wait");
    }

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        dprintf(2, "Killed by signal %d.\n", WTERMSIG(status));
        if (WTERMSIG(status) == SIGINT) {
            finished = 1;
        }
        return WTERMSIG(status) + 128;
    } else {
        errx(1, "Child exited through unsupported operation");
    }
}

int parse_line(struct program_list_head* commands, struct list_str_list_head* args, int old_return_value) {
    finished = 0;

	struct program_entry* command = STAILQ_FIRST(commands);
	struct list_str_entry* arg =  STAILQ_FIRST(args);
    
    int return_value = old_return_value;

    while (command != NULL && !is_finished()) {
        switch (command->type) {
            case COMMAND_CD:
                return_value = parse_cd(arg->list);
                break;
            case COMMAND_PWD:
                return_value = parse_pwd();
                break;
            case COMMAND_EXIT:
                parse_exit(arg->list, return_value);
                break;
            case COMMAND_GENERAL:
                return_value = parse_general(command->command, arg->list);
                break;
            default:
                errx(1, "Unsupported command type.");
        }

        command = STAILQ_NEXT(command, program_entries);
        arg = STAILQ_NEXT(arg, list_str_entries);
    }

    clear_program_list(commands);
    clear_list_str_list(args);

    return return_value;
}