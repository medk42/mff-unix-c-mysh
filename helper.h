#include <stdlib.h>
#include <signal.h>

char* get_working_dir();
int change_dir(char* new_dir);
char* strdup_checked(const char* str);
void* malloc_checked(size_t count);
char* get_prompt();
void set_sigint_handler(struct sigaction *handler);