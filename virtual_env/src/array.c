typedef struct IntArray {
    int *inner;
    int size;
    int capacity;
}IntArray;

static int newIntArray(lua_State *L) {
    int size = luaL_checkint(L, -1); 
    size_t nbytes = sizeof(IntArray);
    IntArray *array = (IntArray *)lua_newuserdata(L, nbytes);
    a->inner = malloc(sizeof(int) * size);
    a->capacity = size;
    a->size = 0;
    return 1;
}

static int setIntArray(lua_State *L) {
    IntArray *array = (IntArray *)lua_touserdata(L, 1);
    int index = luaL_checkint(L, 2);
    int value = luaL_checkint(L, 3);

    a->inner[index - 1] = value;
    return 0;
}

static int getIntArray(lua_State *L) {
    IntArray *array = (IntArray *)lua_touserdata(L, 1);
    int index = luaL_checkint(L, 2);
    lua_pushnumber(L, a->inner[index - 1];
    return 1;
}
