#ifndef LIST_H_
#define LIST_H_

#include "helper.h"

#include <sys/queue.h>
#include <stdlib.h>



STAILQ_HEAD(str_list_head, str_entry);

struct str_entry {
	char* str;
	STAILQ_ENTRY(str_entry) str_entries;
};

void add_to_str_list(char* str, struct str_list_head* head);
void clear_str_list(struct str_list_head* head);
size_t get_str_list_size(struct str_list_head* head);



STAILQ_HEAD(program_list_head, program_entry);

typedef enum {
	COMMAND_CD, COMMAND_PWD, COMMAND_EXIT, COMMAND_GENERAL, END_COMMAND_PIPE
} command_type;

struct program_entry {
	command_type type;
	char* command;
	STAILQ_ENTRY(program_entry) program_entries;
};

void add_to_program_list(command_type type, char* command, struct program_list_head* head);
void clear_program_list(struct program_list_head* head);
size_t get_program_list_size(struct program_list_head* head);



STAILQ_HEAD(list_str_list_head, list_str_entry);

struct list_str_entry {
	struct str_list_head* list;
	STAILQ_ENTRY(list_str_entry) list_str_entries;
};

void auto_add_to_list_str_list(struct list_str_list_head* head);
void add_to_last_list_str_list(char* str, struct list_str_list_head* head);
size_t get_list_str_list_size(struct list_str_list_head* head);
void clear_list_str_list(struct list_str_list_head* head);

#endif