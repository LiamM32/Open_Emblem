version(unittest) import std.stdio;

struct Vector2i //If being used with Godot-Dlang, may interfere with the struct of the same name.
{
    int x;
    int y;

    void opOpAssign(string op:"+")(Vector2i other) {
        this.x += other.x;
        this.y += other.y;
    }
    void opOpAssign(string op:"-")(Vector2i other) {
        this.x -= other.x;
        this.y -= other.y;
    }

    Vector2i opBinary(string op:"+")(Vector2i other) {
        Vector2i result;
        result.x = this.x + other.x;
        result.y = this.y + other.y;
        return result;
    }
    Vector2i opBinary(string op:"-")(Vector2i other) {
        Vector2i result;
        result.x = this.x - other.x;
        result.y = this.y - other.y;
        return result;
     }
}

unittest
{
    writeln("Starting Vector2i unittest.");
    Vector2i a = {1, 0};
    a -= Vector2i(1, 1);
    assert(a == Vector2i(0, -1));
    
    assert(Vector2i(2, 5)+Vector2i(3, -8) == Vector2i(5,-3));
    assert(Vector2i(3, 6)-Vector2i(1, 2) == Vector2i(2, 4));

    writeln("Vector2i unittest passed.");
}

struct Direction //One of 8 directions stored in 3 bits
{
    import std.conv;
    import std.traits: isNumeric;
    
    private ubyte value;

    static Direction N = Direction(0);
    static Direction NE = Direction(1);
    static Direction E = Direction(2);
    static Direction SE = Direction(3);
    static Direction S = Direction(4);
    static Direction SW = Direction(5);
    static Direction W = Direction(6);
    static Direction NW = Direction(7);

    ref Direction opUnary(string op:"++")() {
        value++;
        value &= 7;
        return this;
    }
    ref Direction opUnary(string op:"--")() {
        value--;
        value &= 7;
        return this;
    }

    void opOpAssign(string op:"+")(int amount) {
        value += amount;
        value &= 7;
    }
    void opOpAssign(string op:"-")(int amount) {
        value -= amount;
        value %= 8;
    }

    Direction opBinary(string op:"+")(int amount) {
        ubyte resultvalue = cast(ubyte)(this.value + amount)%8;
        return Direction(resultvalue);
    }
    Direction opBinary(string op:"-")(int amount) {
        ubyte resultvalue = (this.value - amount)%8;
        return Direction(resultvalue);
    }

    T to(T)() const if(isNumeric!T) {
        return cast(T)this.value;
    }

    T to(T)() const if(is(T==string)) {
        if (this==Direction.N) return "north";
        else if (this==Direction.NE) return "northeast";
        else if (this==Direction.E) return "east";
        else if (this==Direction.SE) return "southeast";
        else if (this==Direction.S) return "south";
        else if (this==Direction.SW) return "southwest";
        else if (this==Direction.W) return "west";
        else if (this==Direction.NW) return "northwest";
        else throw new Exception("Direction.to!: direction has a value that should be impossible.");
        //else return ""; //This should never happen.
    }

    Direction opposite() const {
        return Direction((this.value+8)%8);
    }

    int getAngle() {
        if (this==Direction.N) return 0;
        else if (this==Direction.NE) return 45;
        else if (this==Direction.E) return 90;
        else if (this==Direction.SE) return 135;
        else if (this==Direction.S) return 180;
        else if (this==Direction.SW) return 225;
        else if (this==Direction.W) return 270;
        else if (this==Direction.NW) return 315;
        else throw new Exception("Direction.getAngle: direction has a value that should be impossible.");
    }
}

Vector2i directionOffset(Direction direction, Vector2i destination=Vector2i(0,0)) {
    import std.math.algebraic;
    if (direction==Direction.N) destination += Vector2i(0, -1);
    else if (direction==Direction.NE) destination += Vector2i(1, -1);
    else if (direction==Direction.E) destination += Vector2i(1, 0);
    else if (direction==Direction.SE) destination += Vector2i(1, 1);
    else if (direction==Direction.S) destination += Vector2i(0, 1);
    else if (direction==Direction.SW) destination += Vector2i(-1, 1);
    else if (direction==Direction.W) destination += Vector2i(-1, 0);
    else if (direction==Direction.NW) destination += Vector2i(1, 1);
    else throw new Exception("common.directionOffset: direction has a value that should be impossible.");
    return destination;
}

unittest
{
    import std.stdio;
    debug writeln("Starting Direction unittest.");
    Direction direction = Direction.N;
    direction--;
    assert(direction == Direction.NW, "Direction opUnary \"--\" failed.");
    direction+=3;
    assert(direction == Direction.E, "Direction opOpAssign \"+=\" failed");
    direction++;
    assert(direction == Direction.SE, "Direction opUnary \"++\" failed.");
    direction=Direction.S+2;
    assert(direction == Direction.W);
    direction--;
    assert(direction == direction.SW);
    direction-=4;
    assert(direction == Direction.NE);
    writeln("Direction unittest passed.");
}