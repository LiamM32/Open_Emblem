
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
}

struct Direction //One of 8 directions stored in 3 bits
{
    import std.conv;
    import std.traits: isNumeric;
    
    bool[3] b;

    static Direction N = Direction(b:[false,false,false]);
    static Direction NE = Direction(b:[true,false,false]);
    static Direction E = Direction(b:[false,true,false]);
    static Direction SE = Direction(b:[true,true,false]);
    static Direction S = Direction(b:[false,false,true]);
    static Direction SW = Direction(b:[true,false,true]);
    static Direction W = Direction(b:[false,true,true]);
    static Direction NW = Direction(b:[true,true,true]);

    ref Direction opUnary(string op)() if (op == "++" || op == "--") {
        static if (op == "++") const bool up = true;
        else const bool up = false;
        
        if (b[0]) {
            if (b[1]) b[2] = !b[2];
            b[1] = !b[1];
        }
        b[0] = !b[0];
        return this;
    }

    void opOpAssign(string op)(int amount) if (op == "+" || op == "-") {
        amount = amount%8;
        if (amount > 0) for (uint i = 0; i < amount; i++) {
            static if (op=="+") this++;
            else this--;
        } else for (uint i=0; i > amount; i--) {
            static if (op=="+") this--;
            else this++;
        }
    }

    /*ref Direction opUnary(string op)(int amount) if (op=="+"||op=="-") {
        if (amount > 0) for (uint i = 0; i < amount; i++) {
            static if (op=="+") this++;
            else this--;
        } else for (uint i=0; i > amount; i--) {
            static if (op=="+") this--;
            else this++;
        }
        return this;
    }*/

    T to(T)() const if(isNumeric!T) {
        return cast(T)(b[0] + 2*b[1] + 4*b[2]);
    }

    T opCast(T)() if (isNumeric!T) {
        return cast(T)(b[0] + 2*b[1] + 4*b[2]);
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

    bool[3] opCast() const {
        return this.b;
    }

    Direction opposite() const {
        return Direction([b[0], b[1], !b[2]]);
    }

    bool diagonal() {
        return b[0];
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
    Direction direction = Direction.N;
    direction++;
    assert(direction == Direction.NE);
    direction+=3;
    assert(direction == Direction.S);
    direction--;
    assert(direction == Direction.SE);
    direction-=4;
    assert(direction == Direction.NW);
}