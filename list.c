#include "list.h"
#include <err.h>

void str_list___append(char* str, struct str_list___head* head) {
	struct str_list___entry* elem = (struct str_list___entry*)malloc_checked(sizeof(struct str_list___entry));

	elem->str = strdup_checked(str);

	STAILQ_INSERT_TAIL(head, elem, str_entries);
}

void str_list___clear(struct str_list___head* head) {
	struct str_list___entry* first = STAILQ_FIRST(head);
	struct str_list___entry* second;
	while (first != NULL) {
		second = STAILQ_NEXT(first, str_entries);
		free(first->str);
		free(first);
		first = second;
	}
	STAILQ_INIT(head);
}

size_t str_list___get_size(struct str_list___head* head) {
	size_t size = 0;
	struct str_list___entry* item;
	STAILQ_FOREACH(item, head, str_entries) {
		size++;
	}
	return size;
}



void program_list___append(command_type type, char* command, struct program_list___head* head) {
	struct program_list___entry* elem = (struct program_list___entry*)malloc_checked(sizeof(struct program_list___entry));

	if (type == COMMAND_GENERAL) {
		elem->command = strdup_checked(command);
	}
	elem->type = type;

	STAILQ_INSERT_TAIL(head, elem, program_entries);
}

void program_list___clear(struct program_list___head* head) {
	struct program_list___entry* first = STAILQ_FIRST(head);
	struct program_list___entry* second;
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

size_t program_list___get_size(struct program_list___head* head) {
	size_t size = 0;
	struct program_list___entry* item;
	STAILQ_FOREACH(item, head, program_entries) {
		size++;
	}
	return size;
}



static struct str_list___head* get_last_list(struct str_list_list___head* head) {
	if (str_list_list___get_size(head) == 0) {
		errx(1, "couldn't get last list");
	}

	struct str_list_list___entry* last = STAILQ_FIRST(head);
	struct str_list_list___entry* act = STAILQ_NEXT(last, list_str_entries);
	while (act != NULL) {
		last = act;
		act = STAILQ_NEXT(last, list_str_entries);
	}

	return last->list;
}

void str_list_list___append_empty_str_list(struct str_list_list___head* head) {
	struct str_list_list___entry* list = (struct str_list_list___entry*)malloc_checked(sizeof(struct str_list_list___entry));

	list->list = (struct str_list___head*)malloc_checked(sizeof(struct str_list___head));
	STAILQ_INIT(list->list);

	STAILQ_INSERT_TAIL(head, list, list_str_entries);
}

void str_list_list___append_to_last(char* str, struct str_list_list___head* head) {
	struct str_list___head* last = get_last_list(head);

	str_list___append(str, last);
}

size_t str_list_list___get_size(struct str_list_list___head* head) {
	size_t size = 0;
	struct str_list_list___entry* item;
	STAILQ_FOREACH(item, head, list_str_entries) {
		size++;
	}
	return size;
}

void str_list_list___clear(struct str_list_list___head* head) {
	struct str_list_list___entry* first = STAILQ_FIRST(head);
	struct str_list_list___entry* second;
	while (first != NULL) {
		second = STAILQ_NEXT(first, list_str_entries);
		str_list___clear(first->list);
		free(first->list);
		free(first);
		first = second;
	}
	STAILQ_INIT(head);
}