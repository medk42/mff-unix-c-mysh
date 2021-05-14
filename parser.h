#ifndef PARSER_H_
#define PARSER_H_

#include "list.h"

int is_finished();
int parse_line(struct program_list___head* commands, struct str_list_list___head* args, int old_return_value);

#endif