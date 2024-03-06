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
	SetTargetFPS(60);

    scope(exit) CloseWindow();

    Mission mission = new Mission("../maps/Test_battlefield.json");
    writeln("Mission constructor finished.");
	/*while (!WindowShouldClose())
    {
        //BeginDrawing();
        JSONValue mapData = parseJSON(readText("../maps/Test_battlefield.json"));
        Mission(mapData);
        //EndDrawing();
    }*/
    CloseWindow();
}