import std.stdio;
import std.file;
import std.json;
import raylib;
import fluid;

import mission;

const int screenWidth = 800;
const int screenHeight = 600;

void main()
{
	validateRaylibBinding();
	InitWindow(800, 600, "Open Emblem");
	//SetTargetFPS(60);

    scope(exit) CloseWindow();

    JSONValue mapData = parseJSON(readText("../maps/Test_battlefield.json"));
    Mission(mapData);
	/*while (!WindowShouldClose())
    {
        //BeginDrawing();
        JSONValue mapData = parseJSON(readText("../maps/Test_battlefield.json"));
        Mission(mapData);
        //EndDrawing();
    }*/
    CloseWindow();
}

void mainMenu()
{
    ClearBackground(Colors.BLACK);
    DrawText("Open Emblem", 180, 300, 64, Colors.RAYWHITE);
    
    Rectangle textBox = { screenWidth/4.0f - 100, 320, 225, 50};
    
    DrawRectangleRec(textBox, Colors.GRAY);
    DrawText("Missions", cast(int)textBox.x+5, cast(int)textBox.y+5, 40, Colors.RAYWHITE);

    if (CheckCollisionPointRec(GetMousePosition(), textBox)) {
        DrawRectangleLines(cast(int)textBox.x, cast(int)textBox.y, cast(int)textBox.width, cast(int)textBox.height, Colors.RED);
    }
}