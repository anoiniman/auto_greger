#include "/usr/include/lua5.4/lua.h"
#include "/usr/include/lua5.4/lualib.h"
#include "/usr/include/lua5.4/lauxlib.h"

#include "raylib.h"
// #include "stencil"
// #include "dyn_array.c"

// gcc getch.c -shared -o getch.so -fPIC -L/usr/include/lua5.4 -llua5.4
#include <stdio.h>
#include <string.h>


Shader BLOOM_SHADER = { 0 };
Shader GREY_SHADER = { 0 };
Shader BLUR_SHADER = { 0 };
// Shader LIGHT_SHADER = { 0 };

Mesh cube_mesh = { 0 };
Model cube_model = { 0 };
Image color_image = { 0 };
Texture color_texture = { 0 };
RenderTexture2D target = { 0 };

Camera camera;
int camera_mode;

static int close(lua_State *L) {
    UnloadShader(BLOOM_SHADER);
    UnloadShader(GREY_SHADER);
    UnloadShader(BLUR_SHADER);
    // UnloadShader(LIGHT_SHADER);

    UnloadModel(cube_model);
    // UnloadMesh(cube_mesh);
    UnloadImage(color_image);
    CloseWindow();
    return 0;
}

void lua_print(lua_State *L, char *str) {
    lua_getglobal(L, "print");
    lua_pushstring(L, str);
    lua_pcall(L, 1, 0, 0);
}

void lua_printi(lua_State *L, int i) {
    lua_getglobal(L, "print");
    lua_pushinteger(L, i);
    lua_pcall(L, 1, 0, 0);
}

#define COLOR_ARR_SIZE 256
Color knownColors[COLOR_ARR_SIZE];
char *knownColorNames[COLOR_ARR_SIZE];
int knownColorIndex = -1;

static char *def_color_name = "NONE";

#define BLOCK_SIZE 0.8
#define SCALE BLOCK_SIZE * 0.06

// Expects color table to be at the top of the stack
Color *fromLuaColor(lua_State *L) {

    lua_rawgeti(L, -1, 1);
    // Early check cache
    char* name = lua_tostring(L, -1);
    for (int i = 0; i < COLOR_ARR_SIZE; i++) {
        if (i > knownColorIndex) break;

        char *clr_name = knownColorNames[i];
        if (!strcmp(name, clr_name)) return &knownColors[i];
    }
    // Here returns fine

    // Record new color
    lua_rawgeti(L, -2, 2);
    double r = lua_tonumber(L, -1);

    lua_rawgeti(L, -3, 3);
    double g = lua_tonumber(L, -1);

    lua_rawgeti(L, -4, 4);
    double b = lua_tonumber(L, -1);

    lua_rawgeti(L, -5, 5);
    double a = lua_tonumber(L, -1);

    lua_pop(L, -1);
    lua_pop(L, -1);
    lua_pop(L, -1);
    lua_pop(L, -1);

    lua_printi(L, r);
    lua_printi(L, g);
    lua_printi(L, b);
    lua_printi(L, a);
 
    knownColorIndex += 1;
    knownColorNames[knownColorIndex] = name;
    knownColors[knownColorIndex] = (Color) {r, g, b, a};

    return &knownColors[knownColorIndex];
}

Vector3 block_sizeV = { 0 };
static int world_render(lua_State *L) {
    double x = lua_tointeger(L, 1);
    double z = lua_tointeger(L, 2);
    double y = lua_tointeger(L, 3);
    Color *color = fromLuaColor(L);

    Vector3 pos = (Vector3) { 
        x*BLOCK_SIZE + SCALE * x,
        y*BLOCK_SIZE + SCALE * y,
        z*BLOCK_SIZE + SCALE * z
    };

    //DrawModel(cube_model, pos, 1, *color);
    DrawModel(cube_model, pos, 1, WHITE);
    return 0;
}

static int render(lua_State *L) {
    // expects first arg to be a function
    // and second arg to be the world table

    if (IsCursorHidden()) UpdateCamera(&camera, camera_mode);
    if (IsMouseButtonPressed(MOUSE_BUTTON_RIGHT)) {
        if (IsCursorHidden()) EnableCursor();
        else DisableCursor();
    }
    /*
    float cameraPos[3] = { camera.position.x, camera.position.y, camera.position.z };
    SetShaderValue(LIGHT_SHADER, LIGHT_SHADER.locs[SHADER_LOC_VECTOR_VIEW], cameraPos, SHADER_UNIFORM_VEC3);
    */


    BeginTextureMode(target);
        ClearBackground(BLACK);
        BeginMode3D(camera);
            lua_pcall(L, 1, 0, 0);
        EndMode3D();
    EndTextureMode();

    BeginDrawing();
        ClearBackground(BLACK);
        BeginShaderMode(BLOOM_SHADER);
            DrawTextureRec(
            target.texture,
            (Rectangle){ 0, 0, (float)target.texture.width, (float)-target.texture.height },
            (Vector2){ 0, 0 },
            WHITE
            );
        EndShaderMode();

        BeginShaderMode(BLUR_SHADER);
            DrawTextureRec(
            target.texture,
            (Rectangle){ 0, 0, (float)target.texture.width, (float)-target.texture.height },
            (Vector2){ 0, 0 },
            WHITE
            );
        EndShaderMode();
    EndDrawing();

    if (WindowShouldClose()) {
        close(L);
        lua_pushinteger(L, 1);
        return 1;
    }
    lua_pushinteger(L, 2);
    return 1;
}

Color a_color = { 0 };
static int init(lua_State *L) {
    SetConfigFlags(FLAG_VSYNC_HINT);
    int screenWidth = 1280;
    int screenHeight = 720;
    InitWindow(screenWidth, screenHeight, "VirtuCraft Renderer");

    camera = (Camera){ 0 };
    camera.position =   (Vector3) { 0, 10, 10};
    camera.target   =   (Vector3) { 0, 0, 0};
    camera.up       =   (Vector3) {0, 1, 0};
    camera.fovy = 45;
    // type = rl.CAMERA_ORTHOGRAPHIC
    BLOOM_SHADER = LoadShader(0, TextFormat("./virtual/def/bloom.fs", 330));
    GREY_SHADER = LoadShader(0, TextFormat("./virtual/def/greyscale.fs", 330));
    BLUR_SHADER = LoadShader(0, TextFormat("./virtual/def/blur.fs", 330));

    /*LIGHT_SHADER = LoadShader((TextFormat("virtual/def/lighting.vs", GLSL_VERSION),
                               TextFormat("virtaul/def/lighting.fs", GLSL_VERSION));
    LIGHT_SHADER.locs[SHADER_LOC_VECTOR_VIEW] = GetShaderLocation(shader, "viewPos");*/

    block_sizeV = (Vector3) { BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE };

    camera_mode = CAMERA_FREE;

    for (int i = 0; i < COLOR_ARR_SIZE; i++) knownColorNames[i] = def_color_name;
    cube_mesh = GenMeshCube(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE);
    cube_model = LoadModelFromMesh(cube_mesh);

    // a_color = (Color){167, 243, 244, 216};
    a_color = (Color){120, 198, 216, 250};
    Image color_image = GenImageColor(128, 128, a_color);
    color_texture = LoadTextureFromImage(color_image);
    target = LoadRenderTexture(screenWidth, screenHeight);

    cube_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = color_texture;
    return 0;
}

static const struct luaL_Reg mylib [] = {
    {"init", init},
    {"render", render},
    {"close", close},
    {"world_render", world_render},
    {NULL, NULL}
};

int luaopen_librender(lua_State *L) {
    luaL_newlib(L, mylib);
    return 1;
}
