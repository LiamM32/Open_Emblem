import std.stdio;
import std.file;
import std.json;
import raylib;
//import fluid;

import mission;

const int screenWidth = 600;
const int screenHeight = 600;

void main()
{
	validateRaylibBinding();
	InitWindow(screenWidth, screenHeight, "Open Emblem");
	SetTargetFPS(60);

    scope(exit) CloseWindow();

    Mission mission = new Mission("../maps/test-map.json");
    writeln("Mission constructor finished.");
    CloseWindow();
}