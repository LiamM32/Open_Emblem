debug import std.stdio;
import std.signals;
import std.algorithm.searching;

import map;
import unit;
import common;

class Faction
{
    Map map;
    string name;
    Unit[] units;
    string[] allyNames;
    Faction[] allies;
    string[] enemyNames;
    Faction[] enemies;
    bool isPlayer;

    mixin UnitArrayManagement!units;

    version (signals) {
        Signal!() move;
        Signal!() startTurn;
    }

    this(string name, bool isPlayer=false) {
        this.name = name;
        this.isPlayer = isPlayer;
    }

    this(string name, bool isPlayer=false, Map map) {
        this.name = name;
        this.isPlayer = isPlayer;
        this.map = map;
    }

    void setAlliesEnemies(ref Faction[string] factionsByName) {
        import std.conv;
        foreach (name; allyNames) {
            if (name in factionsByName && !canFind(allies, factionsByName[name])) allies ~= factionsByName[name];
        }
        foreach (name; enemyNames) {
            writeln(name~" is an enemy of "~this.name);
            if (name in factionsByName && !canFind(enemies, factionsByName[name])) enemies ~= factionsByName[name];
        }
    }

    void turnReset() {
        debug if (this.units.length == 0) throw new Exception("Faction "~this.name~" has no units");
        version (signals) startTurn.emit;
        else foreach (unit; this.units) {
            if (unit is null) throw new Exception("Faction "~this.name~" has a null Unit reference.");
            else writeln(unit.name~" is being reset.");
            unit.turnReset();
        }
    }

    void turn() {
        map.endTurn;
    }
}

class NonPlayerFaction : Faction
{
    import tile;
    import std.algorithm.sorting;
    import std.array;

    const ushort VIEWRANGE = 20;

    ushort[Unit][Unit] unitDistances;

    this(string name, Map map) {
        super(name, false, map);
    }

    override void turn() {
        MoveOption[][Unit] moveOptions;

        this.turnReset;

        foreach (unit; this.units) {
            debug assert (unit !is null);
            debug writeln("Faction ", this.name, " has a unit called ", unit.name);
            moveOptions[unit] ~= checkOptions(unit);

            // Do movement. Will later be replaced by a weighted random selection.
            {
                MoveOption move = moveOptions[unit][0];
                unit.move(move.dest.x, move.dest.y);
                if (move.toAttack !is null) unit.attack(move.toAttack.getLocation.x, move.toAttack.getLocation.y);
            }
        }
        debug assert(canFind(enemyNames, "player"));
        debug writeln(this.name~" just finished turn.");

        map.endTurn;
    }

    MoveOption[] checkOptions(Unit unit)
    {
        import std.range: array;
        
        Unit[] enemiesConsidered;
        //short[Unit] enemyRisk;
        short[Tile] tileRiskReward;
        MoveOption[] moveOptions;
        
        {
            uint lookRange = 3 * unit.Mv + unit.attackRange;
            foreach(enemyFaction; enemies) foreach (enemyUnit; enemyFaction.units) {
                unitDistances[unit][enemyUnit] = cast(ushort) measureDistance(unit.getLocation, enemyUnit.getLocation);
                if (unitDistances[unit][enemyUnit] <= enemyUnit.Mv + lookRange) enemiesConsidered ~= enemyUnit;
            }
            enemiesConsidered.sort!((a,b) => unitDistances[unit][a] < unitDistances[unit][b]);
        }

        debug writeln("Length of enemiesConsidered for "~unit.name~" is ", enemiesConsidered.length);

        foreach (tile; unit.getReachable!Tile) {
            short score;
            MoveOption[] tileMoveOptions;
            AttackPotential[Unit] enemyAttackPotentials;
            foreach (enemyUnit; enemiesConsidered) {
                debug assert (enemyUnit !is null && enemyUnit.alive && enemyUnit.map == this.map && enemyUnit.currentTile.occupant == enemyUnit, "Enemy has been deleted.");
                ushort distance = cast(ushort)measureDistance(tile.location, enemyUnit.getLocation);
                if (canFind(enemyUnit.getAttackable!Tile, tile)) {
                    enemyAttackPotentials[enemyUnit] = enemyUnit.getAttackPotential(unit, distance);
                    score -= enemyAttackPotentials[enemyUnit].damage;
                }
                if (distance <= unit.attackRange && map.checkObstruction(unit.getLocation, enemyUnit.getLocation)) {
                    tileMoveOptions ~= MoveOption(dest:tile, toAttack:enemyUnit, attackPotential:unit.getAttackPotential(enemyUnit, distance));
                    tileMoveOptions[$-1].score += tileMoveOptions[$-1].attackPotential.damage;
                    debug writeln(unit.name~" is in range to attack enemy "~enemyUnit.name);
                }
                // More to add or subtract score based on change in distance from enemy.
            }
            
            if (tileMoveOptions.length == 0) tileMoveOptions ~= MoveOption(dest: tile);
            foreach (moveOpt; tileMoveOptions) {
                moveOpt.enemyAttackPotential = enemyAttackPotentials;
                moveOpt.score += score;
                moveOptions ~= moveOpt;
            }
        }

        moveOptions.sort!((a,b) => a.score > b.score);
        
        debug writeln(unit.name~" has ", moveOptions.length, " move options.");
        debug foreach (ushort i, option; moveOptions) {
            writeln("Option ",i," is to go to tile ",option.dest.location," and attack "~((option.toAttack is null) ? "no one" : option.toAttack.name));
        }
        
        return moveOptions;
    }

    struct MoveOption {
        Tile dest;
        Unit toAttack;
        AttackPotential attackPotential;
        AttackPotential[Unit] enemyAttackPotential;

        short score;
    }
}