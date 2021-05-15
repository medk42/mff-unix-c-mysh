#ifndef LIST_H_
#define LIST_H_

#include "helper.h"

#include <sys/queue.h>
#include <stdlib.h>



STAILQ_HEAD(str_list___head, str_list___entry);

struct str_list___entry {
	char* str;
	STAILQ_ENTRY(str_list___entry) str_entries;
};

void str_list___append(char* str, struct str_list___head* head);
void str_list___clear(struct str_list___head* head);
size_t str_list___get_size(struct str_list___head* head);



struct redirection_data {
	char* read_file;
	char* write_file;
	int write_file_append;
};



STAILQ_HEAD(program_list___head, program_list___entry);

typedef enum {
	COMMAND_CD, COMMAND_PWD, COMMAND_EXIT, COMMAND_GENERAL, END_COMMAND_PIPE
} command_type;

struct program_list___entry {
	command_type type;
	char* command;
	struct redirection_data redirections;
	STAILQ_ENTRY(program_list___entry) program_entries;
};

void program_list___append(command_type type, char* command, struct program_list___head* head, struct redirection_data redirections);
void program_list___clear(struct program_list___head* head);
size_t program_list___get_size(struct program_list___head* head);



STAILQ_HEAD(str_list_list___head, str_list_list___entry);

struct str_list_list___entry {
	struct str_list___head* list;
	STAILQ_ENTRY(str_list_list___entry) list_str_entries;
};

void str_list_list___append_empty_str_list(struct str_list_list___head* head);
void str_list_list___append_to_last(char* str, struct str_list_list___head* head);
size_t str_list_list___get_size(struct str_list_list___head* head);
void str_list_list___clear(struct str_list_list___head* head);

#endif