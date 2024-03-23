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
        version (signals) startTurn.emit;
        else foreach (unit; this.units) {
            unit.turnReset();
        }
    }

    void turn() {
        map.nextTurn;
    }
}

class NonPlayerFaction : Faction
{
    import tile;
    import std.algorithm.sorting;
    import std.array;
    import item:canShoot;

    const ushort VIEWRANGE = 20;

    ushort[Unit][Unit] unitDistances;
    MoveOption[][Tile] moveOptions;

    this(string name, Map map) {
        super(name, false, map);
    }

    override void turn() {
        MoveOption[][Unit] moveOptions;

        this.turnReset;

        foreach (unit; this.units) {
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

        foreach (tile; unit.getReachable!Tile) {
            short score;
            MoveOption[] tileMoveOptions;
            AttackRisk[Unit] enemyAttackRisks;
            foreach (enemyUnit; enemiesConsidered) {
                ushort distance = cast(ushort)measureDistance(tile.location, enemyUnit.getLocation);
                if (canFind(enemyUnit.getAttackable!Tile, tile)) {
                    enemyAttackRisks[enemyUnit] = enemyUnit.getAttackRisk(unit, distance);
                    score -= enemyAttackRisks[enemyUnit].damage;
                }
                if (distance <= unit.attackRange && canShoot(unit.getLocation, enemyUnit.getLocation, map)) {
                    tileMoveOptions ~= MoveOption(dest:tile, attackPotential:unit.getAttackRisk(enemyUnit, distance));
                    tileMoveOptions[$-1].score += tileMoveOptions[$-1].attackPotential.damage;
                    debug writeln(unit.name~" is in range of enemy "~enemyUnit.name);
                }
                // More to add or subtract score based on change in distance from enemy.
            }
            
            if (tileMoveOptions.length == 0) tileMoveOptions ~= MoveOption(dest: tile);
            foreach (moveOpt; tileMoveOptions) {
                moveOpt.enemyAttackRisk = enemyAttackRisks;
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
        AttackRisk attackPotential;
        AttackRisk[Unit] enemyAttackRisk;

        short score;
    }
}