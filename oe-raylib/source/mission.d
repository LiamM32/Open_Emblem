import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.conv;
import std.json;
import std.algorithm;
import std.datetime.stopwatch;
version (Fluid) {
    import fluid;
} else import raylib;
version (raygui) import raygui;

import common;
import map;
import faction;
import tile;
import vtile;
import unit;
import vunit;
import vector_math;
import constants;
import ui;
import spriteLoader;

const bool updateOnClick = false;

class Mission : Map
{
    Faction playerFaction;
    
    static SpriteLoader spriteLoader;
    version (customgui) UIStyle style;
    Texture2D[] sprites;
    Texture2D gridMarker;
    
    
    Camera2D camera;
    private Vector2 mousePosition;
    private Vector2i mouseGridPosition;
    Rectangle mapArea = {x:0, y:0};          // Rectangle representing the map area in world space.
    Rectangle mapView;          // Rectanlge representing the visible part of the map in screen space.
    StopWatch missionTimer;
    VisibleTile[] startingTiles;
    
    Unit selectedUnit;


    this() {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText(missionPath));
        this(missionData);
    }

    this(JSONValue mapData) {
        camera.offset = Vector2(0.0f, 0.0f);
        import std.algorithm;
        import std.conv;
        import std.uni: toLower;

        version (customgui) this.style = UIStyle.getDefault;

        spriteLoader = SpriteLoader.current;

        super(mapData["map_name"].get!string);
        super.loadFactionsFromJSON(mapData);

        this.grid.length = mapData.object["tiles"].array.length;
        writeln("Starting to unload tile data");
        foreach (uint x, tileRow; mapData.object["tiles"].array) {
            foreach (uint y, tileData; tileRow.arrayNoRef) {
                VisibleTile tile =  new VisibleTile(x, y, tileData);
                this.grid[x] ~= tile;
                if ("Unit" in tileData) {
                    JSONValue unitData = tileData["Unit"];
                    Faction faction;
                    if ("faction" in tileData["Unit"]) faction = factionsByName[unitData["faction"].get!string.toLower];
                    else if ("enemy" in factionsByName) faction = factionsByName["enemy"];
                    else faction = this.factions[1];
                    VisibleUnit occupyingUnit = new VisibleUnit(this, tileData["Unit"]);
                    writeln("New unit "~occupyingUnit.name~" is part of the "~faction.name~" faction.");
                    this.allUnits ~= cast(Unit) occupyingUnit;
                    faction.units ~= cast(Unit) occupyingUnit;
                    occupyingUnit.setLocation(x, y);
                } else if ("Player Unit" in tileData) {
                    this.grid[x][y].startLocation = true;
                    startingTiles ~= tile;
                }
            }
        }
        this.gridWidth = cast(ushort)this.grid.length;
        this.gridLength = cast(ushort)this.grid[0].length;
        this.mapArea.width = cast(int)this.gridLength * TILEWIDTH;
        this.mapArea.height = cast(int)this.gridWidth * TILEHEIGHT;
        writeln(mapArea.height);
        mapArea = Rectangle(x:0, y:0, width:grid.length*TILEWIDTH, height:grid[0].length*TILEHEIGHT);
        debug writeln("Finished loading map " ~ this.name);
        this.playerFaction = factionsByName["player"];
        this.gridMarker = spriteLoader.getSprite("grid marker");
        this.fullyLoaded = true;

        this.turnReset;
    }

    void run() {
        startPreparation();
        this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight);
        writeln("There are ", factions.length, " factions.");
        while(!WindowShouldClose) {
            playerTurn();
            enemyTurn(factions[1]);
        }
    }

    void startPreparation() {   
        this.phase = GamePhase.Preparation;

        Rectangle menuBox = {x:0, y:GetScreenHeight()-96, width:GetScreenWidth(), height:96};
        Unit[] availableUnits;
        UnitInfoCard[Unit] unitCards;
        
        JSONValue playerUnitsData = parseJSON(readText("Units.json"));
        debug writeln("Opened Units.json");
        foreach (uint k, unitData; playerUnitsData.array) {
            VisibleUnit unit = new VisibleUnit(this, unitData, factionsByName["player"]);//loadUnitFromJSON(unitData, spriteIndex, false);
            availableUnits ~= unit;
            unitCards[unit] = new UnitInfoCard(unit, Vector2(x:k*258.0f, y:GetScreenHeight()-88.0f));
        }
        debug writeln("There are "~to!string(unitCards.length)~" units available.");

        foreach (i, unit; this.allUnits) {
            if (unit !is null) writeln("mission.allUnits has a unit named "~unit.name);
            else writeln("mission.allUnits["~to!string(i)~"] is null");
        }

        version (Fluid) {
            Label startButton = button("Start Mission", delegate {
                this.endTurn();
            });
        } else version (raygui) {
            Rectangle startButton = {x:GetScreenWidth()-160, y:menuBox.y-16, width:160, height:32};
        } else version (customgui) {
            TextButton startButton;
            {
                Rectangle buttonOutline = {x:GetScreenWidth()-160, y:menuBox.y-16, width:160, height:32};
                startButton = new TextButton(buttonOutline, UIStyle.getDefault, "Start Mission", 18, &endTurn);
            }
        }

        mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight-96);
        camera.zoom = 1.0f;
        camera.rotation = 0.0f;
        camera.offset = Vector2(mapView.width/2.0f, mapView.height/2.0f);
        camera.target.x = mapArea.width/2.0f;
        camera.target.y = mapArea.height-mapView.height/2.0f;
        foreach (startTile; startingTiles) camera.target.y = max(startTile.y+TILEHEIGHT*2, mapArea.height) - mapView.height/2.0f;
        
        missionTimer = StopWatch(AutoStart.yes);
        bool startButtonAvailable = false;
        bool leftClick;
        const Vector2 dragOffset = {x: -TILEWIDTH/2, y: -TILEHEIGHT*0.75 };
        ushort unitsDeployed = 0;

        while(!WindowShouldClose() && phase==GamePhase.Preparation) {
            unitsDeployed = 0;
            mousePosition = GetMousePosition();
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);

            BeginDrawing();
            this.offsetCamera(mapView);
            BeginMode2D(camera);

            drawGround();
            foreach(startTile; startingTiles) { //This loop handles the starting locations, where the player may place their units.
                Rectangle startTileRect = startTile.getRect();
                DrawRectangleRec(startTileRect, Color(250, 250, 60, 60));
                DrawRectangleLinesEx(startTileRect, 1.5f, Color(240, 240, 40, 120));
                if (startTile.occupant !is null) {
                    unitsDeployed++;
                    Vector2 destination = startTile.origin + Vector2(0, -24);
                    Color tint;
                    if (startTile.occupant == this.selectedUnit) tint = Color(250, 250, 250, 190);
                    else tint = Color(255, 255, 255, 255);
                    DrawTextureV((cast(VisibleUnit)startTile.occupant).sprite, destination, tint);
                }
                if (mouseGridPosition == Vector2i(startTile.x, startTile.y)) {
                    DrawRectangleRec(startTileRect, Color(250, 30, 30, 30));
                    if (leftClick) {
                        Unit previousOccupant = startTile.occupant;
                        if (selectedUnit !is null) {
                            if (selectedUnit.currentTile !is null) selectedUnit.currentTile.occupant = null;
                            selectedUnit.currentTile = startTile;
                            debug writeln("Unit "~selectedUnit.name~" is being deployed.");
                        }
                        startTile.occupant = selectedUnit;
                        
                        if (previousOccupant !is null) previousOccupant.currentTile = null;
                        selectedUnit = previousOccupant;
                    }
                }
            }
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();
            EndMode2D();

            DrawRectangleRec(menuBox, Colours.Paper);
            foreach (card; unitCards) if (card.unit.currentTile is null) {
                card.draw();
                if (leftClick && card.available && CheckCollisionPointRec(mousePosition, card.outline)) this.selectedUnit = card.unit;
            }

            if (this.selectedUnit !is null) {
                DrawTextureV((cast(VisibleUnit)this.selectedUnit).sprite, mousePosition+dragOffset, Colors.WHITE);
            }
            if (unitsDeployed > 0 && missionTimer.peek() >= msecs(WAITTIME*startingTiles.length/unitsDeployed)) {
                version (customgui) {
                    startButton.draw();
                    if (CheckCollisionPointRec(mousePosition, startButton.outline) && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                        EndDrawing();
                        break;
                    }
                } else version (raygui) {
                    if (GuiButton(startButton, "Start Mission".toStringz)) {
                        EndDrawing();
                        break;
                    }
                }
            }

            debug if (IsKeyDown(KeyboardKey.KEY_SPACE)) {
                DrawRectangleRec(mapView, Color(250, 20, 20, 50));
            }

            version (drawFPS) DrawFPS(20, 20);
            EndDrawing();
        }

        foreach (card; unitCards) {
            destroy(card);
        }
        destroy(menuBox);
        
        foreach (startTile; this.startingTiles) if (startTile.occupant !is null) {
            writeln("Looking at starting tile "~to!string(startTile.x())~", "~to!string(startTile.y()));
            this.allUnits ~= startTile.occupant;
            this.factionsByName["player"].units ~= startTile.occupant;
            startTile.occupant.setLocation(startTile.x(), startTile.y());
        }
        this.startingTiles.length = 0;

        debug verifyEverything;

        this.endTurn;
    }

    void playerTurn() {
        import item;

        this.factionsByName["player"].turnReset();
        
        Vector2 mousePosition = GetMousePosition();
        bool onButton = false;
        bool leftClick = false;
        VisibleTile cursorTile;
        Action playerAction = Action.Nothing;

        MenuList!Item itemsList;

        version (customgui) {
            TextButton moveButton;
            TextButton attackButton;
            TextButton itemsButton;
            TextButton waitButton;
            TextButton backButton;
            TextButton finishButton;
            {
                Rectangle buttonOutline = {x:GetScreenWidth-96, y:GetScreenHeight-32, 80, 32};
                backButton = new TextButton(buttonOutline, UIStyle.getDefault, "Back", 20, delegate {
                    if (playerAction != Action.Nothing) {
                        playerAction = Action.Nothing;
                        if (playerAction == Action.Items) {
                            destroy(itemsList);
                            itemsList = null;
                        }
                    } else selectedUnit = null;
                });
                buttonOutline.y -= 32;
                waitButton = new TextButton(buttonOutline, UIStyle.getDefault, "Wait", 20, delegate {
                    selectedUnit.hasActed = true;
                    selectedUnit.finishedTurn = true;
                    playerAction = Action.Nothing;
                    selectedUnit = null;
                });
                buttonOutline.y -= 32;
                itemsButton = new TextButton(buttonOutline, UIStyle.getDefault, "Items", 20, delegate {
                    playerAction = Action.Items;
                    itemsList = new MenuList!Item(GetScreenWidth-128, GetScreenHeight()/2, selectedUnit.inventory);
                });
                buttonOutline.y -= 32;
                attackButton = new TextButton(buttonOutline, UIStyle.getDefault, "Attack", 20, delegate {playerAction = Action.Attack;});
                buttonOutline.y -= 32;
                moveButton = new TextButton(buttonOutline, UIStyle.getDefault, "Move", 20, delegate {playerAction = Action.Move;});
                buttonOutline = Rectangle(x:GetScreenWidth-128, y:GetScreenHeight-32, 128, 32);
                finishButton = new TextButton(buttonOutline, UIStyle.getDefault, "Finish turn", 20, delegate {playerAction = Action.EndTurn;});
            }
        } else version (raygui) {
            Rectangle moveButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*5), 96, 32};
            Rectangle attackButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*4), 96, 32};
            Rectangle itemsButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*3), 96, 32};
            Rectangle waitButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*2), 96, 32};
            Rectangle backButton = {x:GetScreenWidth-96, y:GetScreenHeight-(32*1), 96, 32};
            Rectangle finishButton = {x:GetScreenWidth-128, y:GetScreenHeight-32, 128, 32};
        }

        VisibleUnit movingUnit = null;
        debug Texture arrow = LoadTexture("../sprites/arrow.png");

        debug verifyEverything();

        while(!WindowShouldClose())
        {
            mousePosition = GetMousePosition();
            mouseGridPosition.x = cast(int)GetScreenToWorld2D(GetMousePosition, camera).x / TILEWIDTH;
            mouseGridPosition.y = cast(int)GetScreenToWorld2D(GetMousePosition, camera).y / TILEHEIGHT;
            cursorTile = cast(VisibleTile)getTile(mouseGridPosition, true);
            leftClick = IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT);

            offsetCamera(mapView);
            assert (playerFaction !is null, "playerFaction is null");
            assert (playerFaction.units.length > 0);
            foreach (unit; playerFaction.units) {
                assert (unit !is null);
                (cast(VisibleUnit)unit).act;//stepTowards(unit.currentTile);
            }

            BeginDrawing();
            ClearBackground(Color(20, 60, 90, 255));
            BeginMode2D(camera);
            drawGround();

            if (selectedUnit !is null) switch(playerAction) {
                case Action.Move:
                    foreach (tile; selectedUnit.getReachable!Tile) {
                        DrawRectangleRec((cast(VisibleTile)tile).rect, Color(60, 240, 120, 30));
                        //debug DrawTextureEx(arrow, Vector2(cast(float)(tile.x*TILEWIDTH+32), cast(float)(tile.y*TILEWIDTH+32)), tileAccess.directionTo.getAngle, 1.0f, Color(120, 240, 120, 60));
                        if (leftClick && tile.location == mouseGridPosition) {
                            selectedUnit.move(cursorTile.x, cursorTile.y);
                            playerAction = Action.Nothing;
                        }
                    }
                    break;
                case Action.Attack:
                    debug assert (selectedUnit.getAttackable!Tile.length > 0, "Attackable tiles not cached for unit "~selectedUnit.name);
                    foreach (tile; selectedUnit.getAttackable!Tile) {
                        if (tile.occupant is null) DrawRectangleRec((cast(VisibleTile)tile).rect, Color(200,60,60,30));
                        else if (canFind(playerFaction.enemies, tile.occupant.faction)) DrawRectangleRec((cast(VisibleTile)tile).rect, Color(240,60,60,40));
                        if (leftClick && tile.location == mouseGridPosition) {
                            selectedUnit.attack(cursorTile.x, cursorTile.y);
                            playerAction = Action.Nothing;
                        }
                    }
                    break;
                default: break;
            }
            if (playerAction == Action.Nothing && leftClick && cursorTile !is null) {
                if (cursorTile.occupant !is null /*&& cursorTile.occupant.faction == playerFaction*/) {
                    selectedUnit = cursorTile.occupant;
                    version (updateOnClick) selectedUnit.updateReach();
                }
            }
            
            if (cursorTile !is null) DrawRectangleRec(cursorTile.rect, Colours.Highlight); // Highlights the tile where the cursor is.

            //if (selectedUnit !is null) DrawRectangleRec((cast(VisibleTile)selectedUnit.currentTile).rect, Colours.Highlight);
            drawGridMarkers(missionTimer.peek.total!"msecs");
            drawUnits();
            EndMode2D();
            
            /*switch (playerAction) {
                case Action.Nothing:
                    if (cursorTile.occupant !is null && cursorTile)
            }*/
            
            if (selectedUnit !is null) {
                if (playerAction == Action.Nothing) {
                    version (customgui) {
                        if (selectedUnit.canMove) moveButton.draw;
                        if (!selectedUnit.hasActed) attackButton.draw;
                        itemsButton.draw;
                        waitButton.draw;
                        backButton.draw;
                    } version (raygui) {
                        if (selectedUnit.MvRemaining > 1) if (GuiButton(moveButton, "#150#Move".toStringz)) playerAction = Action.Move;
                        if (!selectedUnit.hasActed) if (GuiButton(attackButton, "#155#Attack".toStringz)) playerAction = Action.Attack;
                        if (GuiButton(itemsButton, "Items".toStringz)) playerAction = Action.Items;
                        if (GuiButton(waitButton, "#149#Wait ".toStringz)) {
                            selectedUnit.hasActed = true;
                            selectedUnit.finishedTurn = true;
                            playerAction = Action.Nothing;
                            selectedUnit = null;
                        }
                        if (GuiButton(backButton, "Back".toStringz)) selectedUnit = null;
                    }
                } else {
                    version (customgui) {
                        backButton.draw;
                    } version (raygui) {
                        if (GuiButton(backButton, "Back".toStringz)) playerAction = Action.Nothing;
                    }
                    ubyte selectedItem;
                    if (playerAction == Action.Items && itemsList !is null && itemsList.draw(selectedItem)) { //The `itemsList !is null` check can be removed if it won't result in a segfault.
                        // Do something with item.
                        playerAction = Action.Nothing;
                        destroy(itemsList);
                    }
                }
            } else {
                ushort remaining = cast(short)(factionsByName["player"].units.length * 2);
                foreach (unit; factionsByName["player"].units) {
                    remaining -= unit.hasActed;
                    remaining -= unit.finishedTurn;
                }
                if (remaining < 3 && playerAction != Action.EndTurn) {
                    version (customgui) {
                        finishButton.draw;
                    } version (raygui) {
                        if (GuiButton(finishButton, "Finish turn".toStringz)) playerAction = Action.EndTurn;
                    }
                }
            }
            version (drawFPS) DrawFPS(20, 20);
            EndDrawing();
            if (playerAction == Action.EndTurn) {
                bool allFinished = true;
                foreach (unit; cast(VisibleUnit[]) playerFaction.units) {
                    if (unit.acting) allFinished = false;
                }
                if (allFinished) break;
            }
        }

        selectedUnit = null;
        endTurn();
    }

    void enemyTurn(Faction faction) {
        faction.turn;

        while (!WindowShouldClose) {
            BeginDrawing();
            ClearBackground(Color(20, 60, 90, 255));
            BeginMode2D(camera);
            drawGround();
            drawUnits();
            EndMode2D();
            EndDrawing();

            bool allFinished = true;
            foreach (unit; cast(VisibleUnit[]) faction.units) {
                (cast(VisibleUnit)unit).act;
                if (unit.acting) allFinished = false;
                else debug writeln(unit.name~" has no actions left.");
            }
            if (allFinished) break;
        }
    }

    void drawGround() {
        foreach (uint x, row; cast(VisibleTile[][]) grid) {
            foreach (uint y, tile; row) {
                DrawTextureV(tile.sprites[0], tile.origin, Colors.WHITE);
            }
        }
    }

    void drawGridMarkers(long time) {
        import std.math.trigonometry:sin;
        import std.math;
        
        float sinwave = 80*(sin(cast(float)time/300.0f)+1.0);
        int opacity = sinwave.to!int + 20;
        foreach (uint x, row; cast(VisibleTile[][]) grid) {
            foreach (uint y, tile; row) {
                DrawTextureV(this.gridMarker, tile.origin, Color(10,10,10, cast(ubyte)sinwave));
            }
        }
    }

    void drawUnits() {
        Color shade;
        foreach (VisibleUnit unit; cast(VisibleUnit[]) allUnits) {
            shade = Colors.WHITE;
            if (phase==GamePhase.PlayerTurn && unit.faction == playerFaction) {
                if (unit.hasActed) shade = Color(235,235,235,255);
                else DrawEllipse(cast(int)unit.position.x+TILEWIDTH/2, cast(int)unit.position.y+TILEHEIGHT/2, cast(float)(TILEWIDTH*0.4375), cast(float)(TILEHEIGHT*0.4375), Colours.Highlight);
            }
            DrawTextureV(unit.sprite, unit.position+Vector2(0.0f,-30.0f), shade);
        }
    }

    void offsetCamera(Rectangle mapView) { 
        mousePosition = GetMousePosition();
        {
            Vector2 mouseWorldPosition = GetScreenToWorld2D(mousePosition, camera);
            mouseGridPosition.x = cast(int)mouseWorldPosition.x / TILEWIDTH;
            mouseGridPosition.y = cast(int)mouseWorldPosition.y / TILEHEIGHT;
        }
        
        Vector2 targetOffset;
        
        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_RIGHT)) {
            targetOffset = GetMouseDelta();
        } else {
            float framelength = GetFrameTime();
            if (IsKeyDown(KeyboardKey.KEY_A)) {
                targetOffset.x = -framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_D)) {
                targetOffset.x = framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_W)) {
                targetOffset.y = -framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_S)) {
                targetOffset.y = framelength * 24.0;
            }
        }
        camera.target -= targetOffset;

        Vector2 margins = {0, 0}; // This step can later be reworked to happen less frequently.
        if (mapArea.width < mapView.width) margins.x = (mapView.width-mapArea.width)/2;
        if (mapArea.height < mapView.height) margins.y = (mapView.height-mapArea.height)/2;

        Vector2 topLeftPosition = GetScreenToWorld2D(Vector2(mapView.x, mapView.y), camera);
        Vector2 bottomRightPosition = GetScreenToWorld2D(Vector2(mapView.x+mapView.width, mapView.y+mapView.height), camera);
        if (topLeftPosition.x < (mapArea.x - margins.x)) camera.target.x -= topLeftPosition.x - margins.x;
        else if (bottomRightPosition.x > mapArea.width + margins.x) camera.target.x -= bottomRightPosition.x + margins.x - mapArea.width;
        if (topLeftPosition.y < (mapArea.y - margins.y)) camera.target.y -= topLeftPosition.y + margins.y;
        else if (bottomRightPosition.y > (mapArea.y + mapArea.height)) camera.target.y -= bottomRightPosition.y - (mapArea.y + mapArea.height + margins.y);
    }
}


unittest
{
    debug writeln("Starting Mission unittest");
    validateRaylibBinding();
    InitWindow(400, 400, "Mission unittest");
    Mission mission = new Mission("../maps/test-map.json");
    foreach (unit; mission.allUnits) {
        assert(unit.map == mission, "Unit does not have it's `map` set to current Mission.");
    }
    writeln("Mission unittest passed");
}