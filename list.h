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