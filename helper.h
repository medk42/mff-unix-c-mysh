#ifndef HELPER_H_
#define HELPER_H_

#include <signal.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

char* get_working_dir();
int change_dir(char* new_dir);
char* strdup_checked(const char* str);
void* malloc_checked(size_t count);
char* get_prompt();
void set_sigint_handler(struct sigaction* handler);
char* skip_spaces(char* str);
void replace_string(char** str, char* new_str);
void reset_string(char** str);
int dup2_checked(int oldfd, int newfd);
int dup_checked(int oldfd);
void close_checked(int fd);
int open_warn_checked(const char* pathname, int flags);
int open_mode_warn_checked(const char* pathname, int flags, mode_t mode);

#endif