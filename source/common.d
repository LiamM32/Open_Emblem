version(unittest) import std.stdio;
@safe @nogc

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

     Vector2i opBinary(string op:"*")(int coefficient) {
        Vector2i result;
        result.x = this.x * coefficient;
        result.y = this.y * coefficient;
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
    a = Vector2i(0, 0);
    a = a *3;
    assert(a == Vector2i(0,0));
    a.x++;
    assert(a == Vector2i(1,0));

    writeln("Vector2i unittest passed.");
}

struct Direction //One of 8 directions stored in 3 bits
{
    import std.conv;
    import std.traits: isNumeric;
    @safe @nogc
    
    private ubyte value;

    enum Direction N = Direction(0);
    enum Direction NE = Direction(1);
    enum Direction E = Direction(2);
    enum Direction SE = Direction(3);
    enum Direction S = Direction(4);
    enum Direction SW = Direction(5);
    enum Direction W = Direction(6);
    enum Direction NW = Direction(7);

    //alias this = value;

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
        ubyte resultvalue = cast(ubyte)(this.value - amount)%8;
        return Direction(resultvalue);
    }

    T opCast(T)() const if (isNumeric!T) {
        return this.value;
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
        return Direction((this.value+4)%8);
    }

    bool diagonal() {
        return value&1;
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

@safe @nogc Vector2i offsetByDirection(Direction direction, Vector2i location=Vector2i(0,0)) {
    import std.math.algebraic;
    final switch (cast(ubyte)direction) {
        case cast(ubyte)Direction.N: location += Vector2i(0, -1); break;
        case cast(ubyte)Direction.NE: location += Vector2i(1, -1); break;
        case cast(ubyte)Direction.E: location += Vector2i(1, 0); break;
        case cast(ubyte)Direction.SE: location += Vector2i(1, 1); break;
        case cast(ubyte)Direction.S: location += Vector2i(0, 1); break;
        case cast(ubyte)Direction.SW: location += Vector2i(-1, 1); break;
        case cast(ubyte)Direction.W: location += Vector2i(-1, 0); break;
        case cast(ubyte)Direction.NW: location += Vector2i(-1, -1); break;
    }
    return location;
}

@safe @nogc uint measureDistance(Vector2i a, Vector2i b=Vector2i(0,0)) {
    import std.math.algebraic;
    import std.algorithm;
    auto xdiff = abs(a.x - b.x);
    auto ydiff = abs(a.y - b.y);
    return xdiff + ydiff + max(xdiff, ydiff);
}

unittest
{
    debug writeln("Starting Direction unittest.");
    Direction direction = Direction.N;
    assert(!direction.diagonal, "Direction.diagonal function false positive.");
    direction--;
    assert(direction == Direction.NW, "Direction opUnary \"--\" failed.");
    assert(direction.diagonal, "Direction.diagonal function false negative.");
    direction+=3;
    assert(direction == Direction.E, "Direction opOpAssign \"+=\" failed");
    assert(!direction.diagonal, "Direction.diagonal function false positive.");
    direction++;
    assert(direction == Direction.SE, "Direction opUnary \"++\" failed.");
    direction=Direction.S+2;
    assert(direction == Direction.W, "Direction opBinary \"+\" failed.");
    assert(direction.diagonal == false, "Direction.diagonal function false positive.");
    direction=direction-1;
    assert(direction == direction.SW, "Direction opBinary \"-\" failed.");
    direction-=4;
    assert(direction == Direction.NE, "Direction opOpAssign \"-=\" failed");
    assert(direction.diagonal, "Direction.diagonal function false negative.");
    writeln("Direction unittest passed.");
}

unittest
{
    debug writeln("Starting offsetByDirection unittest.");
    Vector2i position = {5, 7};
    assert(offsetByDirection(Direction.N, position) == Vector2i(5, 6));
    assert(offsetByDirection(Direction.SE, position) == Vector2i(6, 8));
    assert(offsetByDirection(Direction.SW, position) == Vector2i(4, 8));
    position.x = 2;
    position.y = 8;
    position = offsetByDirection(Direction.NW+4, position);
    assert(position == Vector2i(3, 9));
    writeln("offsetByDirection unittest passed.");
}

unittest
{
    debug writeln("Starting `measureDistance` unittest.");
    assert(measureDistance(Vector2i(0,0), Vector2i(2,1)) == 5);
    writeln(measureDistance(Vector2i(12,12), Vector2i(6,0)));
    assert(measureDistance(Vector2i(12,12), Vector2i(6,0)) == 30);
    writeln("`measureDistance` unittest passed.");
}