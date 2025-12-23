LSRCS = ./src/lib/render.c #./src/stencil.c
LDEPENDS := $(patsubst %.c,%.d,$(SRCS))

RSRCS = ./src/runner/main.c
RDEPENDS := $(patsubst %.c,%.d,$(SRCS))

LSRC_DIR = src/lib/
LOBJ_DIR = src/lib/
LOBJS = $(subst $(LOBJ_DIR),$(LOBJ_DIR),$(LSRCS:.c=.o))

RSRC_DIR = src/runner/
ROBJ_DIR = src/runner/
ROBJS = $(subst $(ROBJ_DIR),$(ROBJ_DIR),$(RSRCS:.c=.o))


RAY_DIR = ../../../raylib-5.5_linux_amd64
CC = gcc
CFLAGS = -g -Wall -Wextra -fPIC -O2\
	 -L/usr/include/lua5.4 -L$(RAY_DIR)/lib -I$(RAY_DIR)/include\
	 -I$(RAY_DIR)/include/GLFW
LIBS = -llua5.4 -lraylib -lGL

# gcc -shared -fPIC -L/usr/include/lua5.4 -llua5.4 -L../../../raylib-5.5_linux_amd64/lib -lraylib -I../../../raylib-5.5_linux_amd64/include render.c -o librender.so


all: lib runner

-include $(DEPENDS)

runner: $(ROBJS)
	$(CC) $(CFLAGS) $(ROBJS) -o ./run_virtual $(LIBS)

$(ROBJ_DIR)/%.o: $(RSRC_DIR)/%.c Makefile
	$(CC) -MMD -MP -c $< -o $@ $(CFLAGS)

lib: $(LOBJS)
	$(CC) -shared $(CFLAGS) $(LOBJS) -o ./librender.so $(LIBS)

$(LOBJ_DIR)/%.o: $(LSRC_DIR)/%.c Makefile
	$(CC) -shared -MMD -MP -c $< -o $@ $(CFLAGS)

clean:
	rm -f $(LOBJS) $(ROBJS) $(RDEPENDS) $(LDEPENDS)
