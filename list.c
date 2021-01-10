#include "list.h"

void add_to_str_list(char* str, struct str_list_head* head) {
	struct str_entry *elem = malloc_checked(sizeof(struct str_entry));
	
	elem->str = strdup_checked(str);

	STAILQ_INSERT_TAIL(head, elem, str_entries);
}

void clear_str_list(struct str_list_head* head) {
	struct str_entry *second, *first = STAILQ_FIRST(head);
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
	struct str_entry *item;
	STAILQ_FOREACH(item, head, str_entries) {
		size++;
	}
	return size;
}