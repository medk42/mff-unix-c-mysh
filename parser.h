#ifndef PARSER_H_
#define PARSER_H_

#include "list.h"

int is_finished();
int parse_line(struct program_list_head* commands, struct list_str_list_head* args, int old_return_value);

#endif