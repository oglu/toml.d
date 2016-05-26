module toml.parser;

import toml.grammar;
import pegged.grammar;
import std.array: split;
import std.conv: to;
import std.exception;
import std.file : readText;

enum TOMLType {
    String,
    Integer,
    Float,
    Boolean,
    Datetime,
    Array,
    Group
};

class TOMLException: Exception {
    this(string msg, string file="parser", size_t line=111) {
        super(msg, file, line);
    }
}

alias enforceTOML = enforceEx!(TOMLException);

struct TOMLValue {

    union Store {
        string stringv;
        long intv;
        float floatv;
        bool boolv;
        TOMLValue[] arrayv;
        TOMLValue[string] keygroups;
    }

    private {
        Store _store;
        TOMLType _type;
    }

    private void assign(T)(T val) {
        static if( is(T: string) ) {
            _store.stringv = val;
            _type = TOMLType.String;
        } 
        else static if ( is(T: long) ) {
            _store.intv = val;
            _type = TOMLType.Integer;
        }
        else static if ( is(T: bool) ) {
            _store.boolv = val;
            _type = TOMLType.Boolean;
        }
        else static if ( is(T: float) ) {
            _store.floatv = val;
            _type = TOMLType.Float;
        }
        else 
            static assert(0, "Unknown type");
        
    }

    private void assign(T)(T val, string key) {
        static if ( is(T: TOMLValue) ) 
            _store.keygroups[key] = val;
        else
            _store.keygroups[key] = TOMLValue(val);
    }

    //
    // Constructors
    // -----------------------------------------

    this(T)(T v) {
        static if ( is(T: TOMLType) ) 
            _type = v;
        else
            assign(v);
    }

    this(T)(ref T v) {
        static if ( is(T: TOMLValue[]) ) {
            _store.arrayv = v;
            _type = TOMLType.Array;
        }
        else static if ( is(T: TOMLValue[string]) ) {
            _store.keygroups = v;
            _type = TOMLType.Group;
        }
    }
 
    // 
    // Operators
    // ---------------------------------------

    // Index assign
    void opIndexAssign(T)(T v, string key) {
        enforceTOML(_type==TOMLType.Group);
        assign(v, key);
    }

    TOMLValue opIndexAssign(TOMLValue  v, string key) {
        enforceTOML(_type==TOMLType.Group);
        _store.keygroups[key] = v;
        return v;
    }

    ref inout(TOMLValue) opIndex(string v) inout {
        enforceTOML(_type==TOMLType.Group);
        return _store.keygroups[v];
    }

    auto opBinaryRight(string op : "in")(string k) const
    {
        enforceTOML(_type==TOMLType.Group);
        return k in _store.keygroups;
    }


    //
    // Value accessors
    // ---------------------------------------
    string str(){
        enforceTOML(_type==TOMLType.String);
        return _store.stringv;
    }

    long integer() {
        enforceTOML(_type==TOMLType.Integer);
        return _store.intv;
    }

    TOMLValue[] array() {
        enforceTOML(_type==TOMLType.Array);
        return _store.arrayv;
    }

    TOMLValue[string] group() {
        enforceTOML(_type==TOMLType.Group);
        return _store.keygroups;
    }

    auto keys() { 
        enforceTOML(_type==TOMLType.Group);
        return _store.keygroups.keys;
    }

}

void _toTOMLDictionary(ParseTree p, ref TOMLValue root, string current_header=null) {

    TOMLValue __valueLine(ParseTree valueNode){ 
        auto v = valueNode.matches[0];
        switch (valueNode.name) {
            case "TOML.IntegerValue": 
                return TOMLValue(v.to!int);
            case "TOML.StringValue": 
                return TOMLValue(v.to!string);
            case "TOML.FloatValue": 
                return TOMLValue(v.to!float);
            case "TOML.BooleanValue":
                return TOMLValue(v.to!bool);
            case "TOML.Array":
                TOMLValue[] vals;
                //first children is the typed array match
                foreach (pc; valueNode.children[0].children) {
                    vals ~= __valueLine(pc);
                }
                return TOMLValue(vals);
            default:
                break;
        }
        assert(0);
    }

    switch (p.name) {
        case "TOML.ValueLine": 
            auto name = p.children[0].matches[0];   //Name node
            auto value = p.children[1].children[0]; //Value node
            if (current_header==null)
                root[name] = __valueLine(value);
            else {
                auto k = current_header.split('.');
                if (!(k[0] in root)) root[k[0]] = TOMLValue(TOMLType.Group);
                TOMLValue * v = &root[k[0]];
                
                foreach (t; k[1..$]) {
                    if (!(t in v._store.keygroups))
                        v.assign(TOMLValue(TOMLType.Group), t);
                    v = &(v._store.keygroups[t]);
                }
                v._store.keygroups[name] = __valueLine(value);
                
            }
            break;
        case "TOML.KeyGroup":
            auto header = p.children[0].children[0].matches[0]; //HeaderName node
            auto vals = p.children[1..$];
            foreach (v; vals) {
                _toTOMLDictionary(v, root, header);
            }
            break;
        default:
            break;
    }
}

TOMLValue parse(string data) {
    auto parseTree = TOML(data);
    TOMLValue dict = TOMLValue(TOMLType.Group);
    foreach(p; parseTree.children[0].children) {
        _toTOMLDictionary(p, dict);
    }
    return dict;
}

TOMLValue parseFile(string filename) {
    return parse(readText(filename));
}

unittest {
    import std.stdio;

    enum TEST1 = `
        key_string = "string_value"
        key_array = ["string_1", "string_2"]

        [servers]
        a = 12

        [servers.test]
        a = 12
        ports = [1,2,3]
        `;

    auto d = parse(TEST1);

    assert(d["key_string"].str == "string_value");
    writefln("Servers: %s", d["servers"].keys);
    writefln("All: %s", d.keys);
    assert(d["servers"]["a"].integer == 12);
    assert(d["servers"]["test"]["a"].integer == 12);
    assert(d["servers"]["test"]["ports"].array[2].integer == 3);

}
