#include "/usr/include/lua5.4/lua.h"
#include "/usr/include/lua5.4/lualib.h"
#include "/usr/include/lua5.4/lauxlib.h"

#include "raylib.h"
#include "raymath.h"
#include "stencil.c"
// #include "dyn_array.c"

// gcc getch.c -shared -o getch.so -fPIC -L/usr/include/lua5.4 -llua5.4
#include <stdio.h>
#include <string.h>


Shader BLOOM_SHADER = { 0 };
Shader GREY_SHADER = { 0 };
Shader BLUR_SHADER = { 0 };
// Shader LIGHT_SHADER = { 0 };

Mesh cube_mesh = { 0 };

Mesh robot_mesh = { 0 };
Image robot_image = { 0 };
Texture robot_texture = { 0 };
Model robot_model = { 0 };


RenderTexture2D world_target = { 0 };
RenderTexture2D robot_target = { 0 };

Camera camera;
int camera_mode;

#define COLOR_ARR_SIZE 256
Image knownColorImages[COLOR_ARR_SIZE];
Texture knownColorTextures[COLOR_ARR_SIZE];
Model knownColorModels[COLOR_ARR_SIZE];

char *knownColorNames[COLOR_ARR_SIZE];

int kcIndex = -1;
static int close(lua_State *L) {
    UnloadShader(BLOOM_SHADER);
    UnloadShader(GREY_SHADER);
    UnloadShader(BLUR_SHADER);
    // UnloadShader(LIGHT_SHADER);

    for (int i = 0; i < kcIndex + 1; i++) {
        UnloadModel(knownColorModels[i]);
        UnloadTexture(knownColorTextures[i]);
        UnloadImage(knownColorImages[i]);
    }
    UnloadModel(robot_model);
    UnloadTexture(robot_texture);
    UnloadImage(robot_image);

    UnloadMesh(robot_mesh);
    UnloadMesh(cube_mesh);

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


static char *def_color_name = "NONE";

#define BLOCK_SIZE 0.8
#define SCALE BLOCK_SIZE * 0.06

// Expects color table to be at the top of the stack
Model *fromLuaColor(lua_State *L) {

    lua_rawgeti(L, -1, 1);
    // Early check cache
    char* name = lua_tostring(L, -1);
    for (int i = 0; i < COLOR_ARR_SIZE; i++) {
        if (i > kcIndex) break;

        char *clr_name = knownColorNames[i];
        if (!strcmp(name, clr_name)) return &knownColorModels[i];
    }

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
 
    kcIndex += 1;
    knownColorNames[kcIndex] = name;
    Model model = LoadModelFromMesh(cube_mesh);

    Color color = (Color){120, 198, 216, 250};
    Image color_image = GenImageColor(128, 128, color);
    Texture color_texture = LoadTextureFromImage(color_image);
    model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = color_texture;
    
    knownColorImages[kcIndex] = color_image;
    knownColorTextures[kcIndex] = color_texture;
    knownColorModels[kcIndex] = model;

    return &knownColorModels[kcIndex];
}

Vector3 block_sizeV = { 0 };
static int render_world(lua_State *L) {
    double x = lua_tointeger(L, 1);
    double z = lua_tointeger(L, 2);
    double y = lua_tointeger(L, 3);
    Model *model = fromLuaColor(L);

    Vector3 pos = (Vector3) { 
        x*BLOCK_SIZE + SCALE * x,
        y*BLOCK_SIZE + SCALE * y,
        z*BLOCK_SIZE + SCALE * z
    };

    DrawModel(*model, pos, 1, WHITE);

    /*
    Vector3 a_pos = (Vector3) {pos.x + BLOCK_SIZE/2 + SCALE, pos.y + BLOCK_SIZE/2, pos.z };
    Vector3 o_pos = (Vector3) {a_pos.x, a_pos.y, a_pos.z};
    DrawModel(outline_model, o_pos, 1, WHITE);
    o_pos = (Vector3) {a_pos.x - BLOCK_SIZE, a_pos.y, a_pos.z};
    if((int) pos.x <= 0) DrawModel(outline_model, o_pos, 1, WHITE);
    */

    return 0;
}

static int render_robot(lua_State *L) {
    // Robot coordinates
    double x = lua_tointeger(L, 1);
    double z = lua_tointeger(L, 2);
    double y = lua_tointeger(L, 3);

    double height_shift = 0.04;
    Vector3 pos = (Vector3) { 
        x*BLOCK_SIZE + SCALE * x,
        (y*BLOCK_SIZE + SCALE * y) + height_shift,
        z*BLOCK_SIZE + SCALE * z
    };
    
    Vector3 rotation = (Vector3) {
        1.0f,
        0.0f,
        0.0f
    };

    DrawModel(robot_model, pos, 1, WHITE); // Up position?
    pos.y -= height_shift;
    DrawModelEx(robot_model, pos, rotation, 180.0f, (Vector3){1.0, 1.0, 1.0}, WHITE);

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


    BeginTextureMode(world_target);
        ClearBackground(BLACK);
        BeginMode3D(camera);
            lua_pcall(L, 1, 0, 0);
        EndMode3D();
    EndTextureMode();

    BeginDrawing();
        ClearBackground(BLACK);
        BeginShaderMode(BLOOM_SHADER);
            DrawTextureRec(
            world_target.texture,
            (Rectangle){ 0, 0, (float)world_target.texture.width, (float)-world_target.texture.height },
            (Vector2){ 0, 0 },
            WHITE
            );
        EndShaderMode();

        BeginShaderMode(BLUR_SHADER);
            DrawTextureRec(
            world_target.texture,
            (Rectangle){ 0, 0, (float)world_target.texture.width, (float)-world_target.texture.height },
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
    world_target = LoadRenderTexture(screenWidth, screenHeight);
    robot_target = LoadRenderTexture(screenWidth, screenHeight);


    robot_mesh = GenMeshCone(BLOCK_SIZE * 1.25, BLOCK_SIZE / 2, 4);
    robot_model = LoadModelFromMesh(robot_mesh);

    robot_image = GenImageColor(128, 128, RAYWHITE);
    robot_texture = LoadTextureFromImage(robot_image);
    robot_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = robot_texture;

    return 0;
}

static const struct luaL_Reg mylib [] = {
    {"init", init},
    {"render", render},
    {"close", close},
    {"render_world", render_world},
    {"render_robot", render_robot},
    {NULL, NULL}
};

int luaopen_librender(lua_State *L) {
    luaL_newlib(L, mylib);
    return 1;
}
