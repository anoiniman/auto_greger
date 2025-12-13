#include "/usr/include/lua5.4/lua.h"
#include "/usr/include/lua5.4/lualib.h"
#include "/usr/include/lua5.4/lauxlib.h"

#include "raylib.h"
// #include "stencil"

// gcc getch.c -shared -o getch.so -fPIC -L/usr/include/lua5.4 -llua5.4
#include <stdio.h>

Camera camera;
int camera_mode;
static int close(lua_State *L) {
    // UnloadShader(BLOOM_SHADER);
    CloseWindow();
    return 0;
}

static int render(lua_State *L) {
    // lua_gettable(L, -1); // gets World on the stack
    // auto block_set_table = lua_getfield(L, -1, "blocks");

    if (IsCursorHidden()) UpdateCamera(&camera, camera_mode);
    if (IsMouseButtonPressed(MOUSE_BUTTON_RIGHT)) {
        if (IsCursorHidden()) EnableCursor();
        else DisableCursor();
    }

    BeginDrawing();
        ClearBackground(BLACK);
        BeginMode3D(camera);
        // world:render();
        EndMode3D();
    EndDrawing();

    if (WindowShouldClose()) {
        close(L);
        lua_pushinteger(L, 1);
        return 1;
    }
    lua_pushinteger(L, 2);
    return 1;
}

static int init(lua_State *L) {
    SetConfigFlags(FLAG_VSYNC_HINT);
    InitWindow(1280, 720, "VirtuCraft Renderer");

    camera = (Camera){ 0 };
    camera.position =   (Vector3) { 0, 10, 10};
    camera.target   =   (Vector3) { 0, 0, 0};
    camera.up       =   (Vector3) {0, 1, 0};
    camera.fovy = 45;
    // type = rl.CAMERA_ORTHOGRAPHIC

    camera_mode = CAMERA_FREE;
    return 0;
}

static const struct luaL_Reg mylib [] = {
    {"init", init},
    {"render", render},
    {"close", close},
    {NULL, NULL}
};

int luaopen_librender(lua_State *L) {
    luaL_newlib(L, mylib);
    return 1;
}
