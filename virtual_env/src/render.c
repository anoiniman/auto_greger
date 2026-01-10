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

#define RENDER_FPS 60

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
        UnloadImage(knownColorImages[i]);
        UnloadTexture(knownColorTextures[i]);
        // UnloadModel(knownColorModels[i]);
    }

    UnloadImage(robot_image);
    UnloadTexture(robot_texture);
    // UnloadModel(robot_model);

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

// #define BLOCK_SIZE 0.8
#define BLOCK_SIZE 3.4
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

    Color color = (Color){r, g, b, a};
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

#define ROBOT_MAX_RENDER_QUEUE 30
struct {
    struct {
        int x;
        int z;
        int y;
    } icoordinates[ROBOT_MAX_RENDER_QUEUE];
    // 1-60 animation frames for a second long animation, 1-10 for a 1/6 of second long animation
    int frame;
    int frame_target;
    int rest_frames; // lets do 4 for now

    int coordinate_index;
} robot_render_state;

// icoordinates[0] == current location; icoordinates[1] == target_location
static int init_robot(lua_State *L) {
    int ix = lua_tointeger(L, 1);
    int iz = lua_tointeger(L, 2);
    int iy = lua_tointeger(L, 3);

    robot_render_state.icoordinates[0].x = ix;
    robot_render_state.icoordinates[0].z = iz;
    robot_render_state.icoordinates[0].y = iy;

    robot_render_state.frame = -1;
    robot_render_state.rest_frames = 4;
    robot_render_state.frame_target = 12;

    robot_render_state.coordinate_index = 0;

    return 0;
}

static int set_robot_frame_info(lua_State *L) {
    int frame_target = lua_tointeger(L, 1);
    int rest_frames = lua_tointeger(L, 2);

    robot_render_state.frame_target = frame_target;
    robot_render_state.rest_frames = rest_frames;
    return 0;
}

double lerp(double v0, double v1, double t) {
    return (1 - t) * v0 + t * v1;
}

static int render_robot(lua_State *L) {
    int return_code = 0;
    // lua_printi(L, -1);
    // getchar();

    // (in-engine) robot coordinates
    int ix = lua_tointeger(L, 1);
    int iz = lua_tointeger(L, 2);
    int iy = lua_tointeger(L, 3);
    int do_check = lua_tointeger(L, 4);

    double x, z, y;
    x = ix; z = iz; y = iy;

    // lua_printi(L, 0);
    int cindex = robot_render_state.coordinate_index;
    if ( // detectes a change in latest robot coordinates
        cindex < ROBOT_MAX_RENDER_QUEUE &&
        (robot_render_state.icoordinates[cindex].x != ix ||
        robot_render_state.icoordinates[cindex].z != iz ||
        robot_render_state.icoordinates[cindex].y != iy)
    ) {
        // lua_printi(L, 10);
        cindex += 1;
        robot_render_state.coordinate_index += 1;
        
        robot_render_state.icoordinates[cindex].x = ix;
        robot_render_state.icoordinates[cindex].z = iz;
        robot_render_state.icoordinates[cindex].y = iy;
        robot_render_state.frame = 0;

        if (cindex + 1 >= ROBOT_MAX_RENDER_QUEUE) {
            // Communicate to lua that we cannot accept more render targets
            // and to wait until we've got more space
            return_code = 1;
        }
    }


    // lua_printi(L, 20);
    // If we are not currently animating then we can just draw right away,
    // otherwise we have to do some calculations
    int frame = robot_render_state.frame;

    // Advance movement target if possible
    if (frame > robot_render_state.frame_target + robot_render_state.rest_frames) {
        int cindex = robot_render_state.coordinate_index;
        // Now we push the coordinates to the left, getting a new "target coordinate"
        if (cindex > 0) {
            for (int i = 1; i <= cindex; i++) {
                robot_render_state.icoordinates[i - 1] = robot_render_state.icoordinates[i];
            }
            
            robot_render_state.coordinate_index -= 1;
            robot_render_state.frame = 0;
        }
        
        // Else set state for stand-still if the queue has run out and animation is over
        robot_render_state.frame = -1;
    }
    else if (frame > robot_render_state.frame_target) {
        x = robot_render_state.icoordinates[1].x;
        z = robot_render_state.icoordinates[1].z;
        y = robot_render_state.icoordinates[1].y;
    }
    else if (frame > 0) {
        double t = frame / robot_render_state.frame_target;

        x = lerp(robot_render_state.icoordinates[0].x, robot_render_state.icoordinates[1].x, t);
        z = lerp(robot_render_state.icoordinates[0].z, robot_render_state.icoordinates[1].z, t);
        y = lerp(robot_render_state.icoordinates[0].y, robot_render_state.icoordinates[1].y, t);
        robot_render_state.frame += 1;
    }
    else if (frame < 0 ) {/* Nothing to be done */ }

    double height_shift = 0.06 * BLOCK_SIZE;
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

    if (do_check) {
        if (cindex + 1 == ROBOT_MAX_RENDER_QUEUE) {
            return_code = 1;
        } else {
            return_code = 0;
        }
    }
    lua_pushinteger(L, return_code);
    return 1;
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
        // ClearBackground(BLACK);
        ClearBackground((Color){0,0,0,0});
        BeginMode3D(camera);
            lua_pcall(L, 1, 0, 0);
            lua_pcall(L, 1, 0, 0);
        EndMode3D();
    EndTextureMode();

    /* BeginTextureMode(world_target);
        ClearBackground((Color){0,0,0,0});
        BeginMode3D(camera);
            lua_pcall(L, 1, 0, 0);
        EndMode3D();
    EndTextureMode();*/

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

        /* BeginBlendMode(BLEND_ALPHA);
        // If you want a shader on robot, wrap DrawTextureRec with BeginShaderMode/EndShaderMode
        // robot_mesh = GenMeshCone(BLOCK_SIZE * 0.64, BLOCK_SIZE / 2, 4);
        DrawTextureRec(
            robot_target.texture,
            (Rectangle){ 0, 0, (float)robot_target.texture.width, (float)-robot_target.texture.height },
            (Vector2){ 0, 0 },
            WHITE
        );
        EndBlendMode();*/

        /* BeginShaderMode(BLUR_SHADER);
            DrawTextureRec(
            world_target.texture,
            (Rectangle){ 0, 0, (float)world_target.texture.width, (float)-world_target.texture.height },
            (Vector2){ 0, 0 },
            WHITE
            );
        EndShaderMode(); */
    EndDrawing();

    if (WindowShouldClose()) {
        close(L);
        lua_pushinteger(L, 1);
        return 1;
    }
    lua_pushinteger(L, 2);
    return 1;
}

// Remember to create a custom camera movement behaviour soon
static int init(lua_State *L) {
    SetConfigFlags(FLAG_VSYNC_HINT);
    int screenWidth = 1280;
    int screenHeight = 720;
    InitWindow(screenWidth, screenHeight, "VirtuCraft Renderer");
    SetTargetFPS(RENDER_FPS);

    camera = (Camera){ 0 };
    camera.position =   (Vector3) { 0, 10, 10};
    camera.target   =   (Vector3) {0, 0, 0};
    camera.up       =   (Vector3) {0, 1, 0};
    // camera.fovy = 95;
    camera.fovy = 65;
    // camera.projection = CAMERA_ORTHOGRAPHIC;

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


    robot_mesh = GenMeshCone(BLOCK_SIZE * 0.64, BLOCK_SIZE / 2, 4);
    robot_model = LoadModelFromMesh(robot_mesh);

    robot_image = GenImageColor(128, 128, RAYWHITE);
    robot_texture = LoadTextureFromImage(robot_image);
    robot_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = robot_texture;

    return 0;
}

static const struct luaL_Reg mylib [] = {
    {"init", init},
    {"init_robot", init_robot},
    {"render", render},
    {"close", close},
    {"render_world", render_world},
    {"render_robot", render_robot},
    {"set_robot_frame_info", set_robot_frame_info},
    {NULL, NULL}
};

int luaopen_librender(lua_State *L) {
    luaL_newlib(L, mylib);
    return 1;
}
