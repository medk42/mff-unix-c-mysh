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
#include <sys/stat.h>
#include <signal.h>
#include <sys/wait.h>
#include <fcntl.h>

int finished = 0;

int is_finished() {
	return finished;
}

static int parse_cd(struct str_list___head* arg_head, int parse_only) {
	size_t arg_count = str_list___get_size(arg_head);
	
	if (arg_count == 0) {
		char* home = getenv("HOME");
		if (home) {
			return parse_only ? 0 : change_dir(home);
		}
	} else if (arg_count == 1) {
		char* new_dir = STAILQ_FIRST(arg_head)->str;
		if (strcmp("-", new_dir) == 0) {
			char* old_dir = getenv("OLDPWD");
			if (old_dir) {
				printf("%s\n", old_dir);
				return parse_only ? 0 : change_dir(old_dir);
			} else {
				warnx("cd: OLDPWD not set");
				return 1;
			}
		} else {
			return parse_only ? 0 : change_dir(new_dir);
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

static void parse_exit(struct str_list___head* arg_head, int return_value, int parse_only) {
	if (str_list___get_size(arg_head) > 0) {
		warnx("exit: too many arguments");
	}

	if (!parse_only) {
		exit(return_value);
	}
}

static pid_t parse_general(char* command, struct str_list___head* arg_head) {
	pid_t pid = fork();
	if (pid == -1) {
		err(1, "fork");
	} else if (pid == 0) { // child
		struct sigaction original_handler = { .sa_handler = SIG_DFL };
		set_sigint_handler(&original_handler);

		size_t args_len = str_list___get_size(arg_head) + 2;
		char** args = (char**)malloc_checked(sizeof(char*) * args_len);
		args[0] = command;
		args[args_len - 1] = 0;
		char** arg = args+1;
		
		struct str_list___entry *item;
		STAILQ_FOREACH(item, arg_head, str_entries) {
			*arg = item->str;
			++arg;
		}

		execvp(command, args);
		err(UNKNOWN_COMMAND_ERROR, "%s", command);
	}
	
	return pid;
}

static size_t count_commands_in_pipe(struct program_list___entry* command) {
	size_t count = 0;

	while (command != NULL && command->type != END_COMMAND_PIPE) {
		command = STAILQ_NEXT(command, program_entries);
		++count;
	}

	return count;
}

static int* init_pipes(size_t pipe_count) {
	int* fildes = (int*)malloc_checked(sizeof(int) * 2 * pipe_count);

	int* fildes_iter = fildes;
	for (size_t i = 0; i < pipe_count; ++i, fildes_iter += 2) {
		if (pipe(fildes_iter) == -1) {
			err(1, "fildes");
		}
		if (fcntl(fildes_iter[0], F_SETFD, FD_CLOEXEC) == -1) {
			err(1, "fcntl");
		}
		if (fcntl(fildes_iter[1], F_SETFD, FD_CLOEXEC) == -1) {
			err(1, "fcntl");
		}
	}

	return fildes;
}

static void pipes_close_write(int* fildes, size_t pipe_count) {
	for (size_t i = 1; i < 2 * pipe_count; i += 2) {
		close_checked(fildes[i]);
	}
}

static void pipes_close_read(int* fildes, size_t pipe_count) {
	for (size_t i = 0; i < 2 * pipe_count; i += 2) {
		close_checked(fildes[i]);
	}
}

static int wait_for_child(pid_t pid) {
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

static int wait_for_children(pid_t* children, size_t count, int return_value) {
	if (count == 0) {
		return return_value;
	}

	for (size_t i = 0; i < count - 1; ++i, ++children) {
		if (*children != -1) {
			wait_for_child(*children);
		}
	}

	if (*children != -1) {
		return_value = wait_for_child(*children);
	}

	return return_value;
}

void handle_redirections(struct redirection_data redirections) {
	if (redirections.read_file) {
		int fd = open_checked(redirections.read_file, O_RDONLY);
		dup2_checked(fd, 0);
		close_checked(fd);
	}

	if (redirections.write_file) {
		int fd;
		mode_t mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;

		if (redirections.write_file_append) {
			fd = open_mode_checked(redirections.write_file, O_WRONLY | O_CREAT | O_APPEND, mode);
		} else {
			fd = open_mode_checked(redirections.write_file, O_WRONLY | O_CREAT | O_TRUNC, mode);
		}

		dup2_checked(fd, 1);
		close_checked(fd);
	} 
}

int parse_line(struct program_list___head* commands, struct str_list_list___head* args, int old_return_value) {
	finished = 0;

	struct program_list___entry* command = STAILQ_FIRST(commands);
	struct str_list_list___entry* arg =  STAILQ_FIRST(args);
	
	int return_value = old_return_value;

	int stdin_orig = dup_checked(0);
	int stdout_orig = dup_checked(1);

	while (command != NULL) {
		size_t command_count = count_commands_in_pipe(command);
		size_t pipe_count = command_count - 1;
		int* fildes = init_pipes(pipe_count);
		pid_t* children = (pid_t*)malloc_checked(sizeof(pid_t) * command_count);

		pid_t* act_child = children;
		int* act_fildes = fildes;
		for (size_t i = 0; i < command_count; ++i, ++act_child, act_fildes += 2) {
			*act_child = -1;

			if (i > 0) {
				dup2_checked(act_fildes[-2], 0);
			}
			if (i < command_count - 1) {
				dup2_checked(act_fildes[1], 1);
			}

			handle_redirections(command->redirections);

			switch (command->type) { // TODO bind pipes, cd,pwd,exit only work outside of pipes, only print with pipes
				case COMMAND_CD:
					// last argument means parse-only meaning print error messages for incorrect arguments and set return value, 
					// but don't actually do the action, neither cd nor exit should do anything when using in pipes, but should
					// still parse errors and set return value
					return_value = parse_cd(arg->list, command_count != 1);
					break;
				case COMMAND_PWD:
					return_value = parse_pwd();
					break;
				case COMMAND_EXIT:
					// see "case COMMAND_CD" for last argument
					parse_exit(arg->list, return_value, command_count != 1);
					break;
				case COMMAND_GENERAL:
					*act_child = parse_general(command->command, arg->list);
					break;
				default:
					errx(1, "Unsupported command type.");
			}

			dup2_checked(stdin_orig, 0);
			dup2_checked(stdout_orig, 1);

			command = STAILQ_NEXT(command, program_entries);
			arg = STAILQ_NEXT(arg, list_str_entries);
		}

		pipes_close_write(fildes, pipe_count);

		// passing return_value since cd/exit and such may have already set their return value in this variable and if they were the last command, we can not change it
		return_value = wait_for_children(children, command_count, return_value);
		pipes_close_read(fildes, pipe_count);

		free(children);
		free(fildes);

		command = STAILQ_NEXT(command, program_entries);
	}
	
	close_checked(stdin_orig);
	close_checked(stdout_orig);

	program_list___clear(commands);
	str_list_list___clear(args);

	return return_value;
}