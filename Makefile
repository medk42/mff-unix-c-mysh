all: build mysh 

build:
	mkdir -p build

mysh: build/mysh.lex.c build/mysh.y.c build/helper.c build/helper.h build/defaults.h build/list.c build/list.h build/main.c build/parser.c build/parser.h
	gcc -Wall -Wextra -o mysh build/mysh.lex.c build/mysh.y.c build/helper.c build/list.c build/main.c build/parser.c -lreadline

build/mysh.lex.c: mysh.lex
	flex -o build/mysh.lex.c mysh.lex

build/mysh.y.c: mysh.y
	bison --verbose -d -o build/mysh.y.c mysh.y

build/helper.c: helper.c
	cp helper.c build/helper.c

build/helper.h: helper.h
	cp helper.h build/helper.h

build/defaults.h: defaults.h
	cp defaults.h build/defaults.h

build/list.c: list.c
	cp list.c build/list.c

build/list.h: list.h
	cp list.h build/list.h	

build/main.c: main.c
	cp main.c build/main.c

build/parser.c: parser.c
	cp parser.c build/parser.c

build/parser.h: parser.h
	cp parser.h build/parser.h

clean: 
	rm -rf build
	rm -f mysh
