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

    const ushort VIEWRANGE = 20;

    ushort[Unit][Unit] unitDistances;

    this(string name, Map map) {
        super(name, false, map);
    }

    override void turn() {
        foreach (unit; this.units) {
            debug writeln("Faction ", this.name, " has a unit called ", unit.name);
            checkOptions(unit);
        }
        debug assert(canFind(enemyNames, "player"));
        debug writeln(this.name~" just took turn.");
    }

    void checkOptions(Unit unit) // This will soon return a struct value with options for moves
    {
        import std.range: array;
        
        Unit[] enemiesConsidered;
        short[Tile] tileRiskReward;
        MoveOption[] moveOptions;
        
        {
            uint lookRange = 2 * unit.Mv + unit.attackRange;
            foreach(enemyFaction; enemies) foreach (enemyUnit; enemyFaction.units) {
                unitDistances[unit][enemyUnit] = cast(ushort) measureDistance(unit.getLocation, enemyUnit.getLocation);
                if (unitDistances[unit][enemyUnit] <= enemyUnit.Mv + lookRange) enemiesConsidered ~= enemyUnit;
            }
            enemiesConsidered.sort!((a,b) => unitDistances[unit][a] < unitDistances[unit][b]);
        }

        {
            foreach (enemyUnit; enemiesConsidered) {
                //if (distance > unit.MvRemaining + unit.attackRange) break;

                //foreach (tile; unit.getReachable)

                foreach (tile; overlap(unit.getReachable!Tile, enemyUnit.getAttackable!Tile)) {
                    AttackRisk attackInfo = enemyUnit.getAttackRisk(unit);
                    tileRiskReward[tile] -= attackInfo.damage;
                    if (attackInfo.damage > unit.HP) tileRiskReward[tile] -= unit.HP>>1;
                }
            }
        }

        //considerRunTowards(unit);
        
    }

    /*void considerRunTowards(Unit unit) {
        foreach (enemyUnit) {
        }

    }*/

    struct MoveOption {
        Tile moveTo;
        Unit opponent;
        AttackRisk attackPotential;
        AttackRisk[1] enemyAttackRisk;

        short score;
    }
}