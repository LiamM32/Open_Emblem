import std.stdio;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.json;
import std.algorithm.searching;
import raylib;
import map;

void Mission(JSONValue missionData)
{
    Map map = new Map(missionData);
    Texture2D[] tileSprites;
    int scale = 32;
    
    writeln("Got to mission.d 14");
    foreach(i, spriteName; map.getTextureIndex()) {
        string spritePath = ("../sprites/" ~ spriteName).buildNormalizedPath;
        if (!endsWith(spritePath, ".png")) spritePath ~= ".png";
        writeln(spritePath);
        tileSprites ~= LoadTexture(spritePath.toStringz);
    }
    //missionData.destroy;
    writeln(WindowShouldClose());

    while (!WindowShouldClose()) {
        BeginDrawing();
        scope(exit) EndDrawing();

        ClearBackground(Colors.BLACK);
        foreach (int gridx, tileRow; map.getGrid) {
            foreach (int gridy, tile; tileRow) {
                DrawTexture(tileSprites[tile.textureID], gridx*32, gridy*32, Colors.RAYWHITE);
            }
        }
    }
    CloseWindow();
}