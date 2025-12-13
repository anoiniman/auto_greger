SRCS = ./src/render.c ./src/stencil.c
DEPENDS := $(patsubst %.c,%.d,$(SRCS))
SRC_DIR = src

LOBJ_DIR = src
LOBJS = $(subst src/,src/,$(SRCS:.c=.o))

RAY_DIR = ../../../raylib-5.5_linux_amd64
LINUX_CC = gcc
CFLAGS = -g -Wall -Wpedantic -Wextra -fPIC\
	 -L/usr/include/lua5.4 -L$(RAY_DIR)/lib -I$(RAY_DIR)/include\
	 -I$(RAY_DIR)/include/GLFW
LINUX_LIBS = -llua5.4 -lraylib -lGL

# gcc -shared -fPIC -L/usr/include/lua5.4 -llua5.4 -L../../../raylib-5.5_linux_amd64/lib -lraylib -I../../../raylib-5.5_linux_amd64/include render.c -o librender.so


all: linux

-include $(DEPENDS)

linux: $(LOBJS)
	$(LINUX_CC) -shared $(CFLAGS) $(LOBJS) -o ./librender.so $(LINUX_LIBS)

#$(LOBJ_DIR)/%.o: $(SRC_DIR)/%.c $(SRC_DIR)/%.h
#$$(wildcard $(SRC_DIR)/$$*.h)
#.SECONDEXPANSION:
$(LOBJ_DIR)/%.o: $(SRC_DIR)/%.c Makefile
	$(LINUX_CC) -shared -MMD -MP -c $< -o $@ $(CFLAGS)

clean:
	rm -f $(LOBJS) $(DEPENDS)
