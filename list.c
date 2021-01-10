#include "list.h"
#include <err.h>

void add_to_str_list(char* str, struct str_list_head* head) {
	struct str_entry* elem = (struct str_entry*)malloc_checked(sizeof(struct str_entry));

	elem->str = strdup_checked(str);

	STAILQ_INSERT_TAIL(head, elem, str_entries);
}

void clear_str_list(struct str_list_head* head) {
	struct str_entry* first = STAILQ_FIRST(head);
	struct str_entry* second;
	while (first != NULL) {
		second = STAILQ_NEXT(first, str_entries);
		free(first->str);
		free(first);
		first = second;
	}
	STAILQ_INIT(head);
}

size_t get_str_list_size(struct str_list_head* head) {
	size_t size = 0;
	struct str_entry* item;
	STAILQ_FOREACH(item, head, str_entries) {
		size++;
	}
	return size;
}



void add_to_program_list(command_type type, char* command, struct program_list_head* head) {
	struct program_entry* elem = (struct program_entry*)malloc_checked(sizeof(struct program_entry));

	if (type == COMMAND_GENERAL) {
		elem->command = strdup_checked(command);
	}
	elem->type = type;

	STAILQ_INSERT_TAIL(head, elem, program_entries);
}

void clear_program_list(struct program_list_head* head) {
	struct program_entry* first = STAILQ_FIRST(head);
	struct program_entry* second;
	while (first != NULL) {
		second = STAILQ_NEXT(first, program_entries);
		if (first->type == COMMAND_GENERAL) {
			free(first->command);
		}
		free(first);
		first = second;
	}
	STAILQ_INIT(head);
}

size_t get_program_list_size(struct program_list_head* head) {
	size_t size = 0;
	struct program_entry* item;
	STAILQ_FOREACH(item, head, program_entries) {
		size++;
	}
	return size;
}



static struct str_list_head* get_last_list(struct list_str_list_head* head) {
	if (get_list_str_list_size(head) == 0) {
		errx(1, "couldn't get last list");
	}

	struct list_str_entry* last = STAILQ_FIRST(head);
	struct list_str_entry* act = STAILQ_NEXT(last, list_str_entries);
	while (act != NULL) {
		last = act;
		act = STAILQ_NEXT(last, list_str_entries);
	}

	return last->list;
}

void auto_add_to_list_str_list(struct list_str_list_head* head) {
	struct list_str_entry* list = (struct list_str_entry*)malloc_checked(sizeof(struct list_str_entry));

	list->list = (struct str_list_head*)malloc_checked(sizeof(struct str_list_head));
	STAILQ_INIT(list->list);

	STAILQ_INSERT_TAIL(head, list, list_str_entries);
}

void add_to_last_list_str_list(char* str, struct list_str_list_head* head) {
	struct str_list_head* last = get_last_list(head);

	add_to_str_list(str, last);
}

size_t get_list_str_list_size(struct list_str_list_head* head) {
	size_t size = 0;
	struct list_str_entry* item;
	STAILQ_FOREACH(item, head, list_str_entries) {
		size++;
	}
	return size;
}

void clear_list_str_list(struct list_str_list_head* head) {
	struct list_str_entry* first = STAILQ_FIRST(head);
	struct list_str_entry* second;
	while (first != NULL) {
		second = STAILQ_NEXT(first, list_str_entries);
		clear_str_list(first->list);
		free(first);
		first = second;
	}
	STAILQ_INIT(head);
}