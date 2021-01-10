all: build mysh 

build:
	mkdir -p build

mysh: build/mysh.lex.c build/mysh.y.c
	gcc -Wall -Wextra -o mysh build/mysh.lex.c build/mysh.y.c -lreadline

build/mysh.lex.c: mysh.lex
	flex -o build/mysh.lex.c mysh.lex

build/mysh.y.c: mysh.y
	bison --verbose -d -o build/mysh.y.c mysh.y

clean: 
	rm -rf build
	rm -f mysh
