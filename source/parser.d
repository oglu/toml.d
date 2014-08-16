import grammar;
import pegged.grammar;
import std.variant;
import std.stdio;

enum TOMLType {
    String,
    Integer,
    Float,
    Boolean,
    Datetime,
    Array,
    Group
};

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

    this(T)(T v) {
        static if( is(T: string) ) {
            _store.stringv = v;
            _type = TOMLType.String;
        } 
        else static if ( is(T: long) ) {
            _store.intv = v;
            _type = TOMLType.Integer;
        }
        else static if ( is(T: bool) ) {
            _store.boolv = v;
            _type = TOMLType.Boolean;
        }
        else static if ( is(T: float) ) {
            _store.floatv = v;
            _type = TOMLType.Float;
        }
        else static if ( is(T: TOMLValue[]) ) {
            _store.arrayv = v;
            _type = TOMLType.Array;
        }
        else static if ( is(T: TOMLValue[string]) ) {
            _store.keygroups = v;
            _type = TOMLType.Group;
        }
    }

    string str(){
        return _store.stringv;
    }

    long integer() {
        return _store.intv;
    }
}

struct TOMLDictionary {
    private {
        TOMLDictionary[string] _groups;
        TOMLValue[string] _values;
    }

    int opIndexAssign(int v, string key) {
        _values[key] = TOMLValue(v);
        return v;
    }

    string opIndexAssign(string v, string key) {
        _values[key] = TOMLValue(v);
        return v;
    }

    float opIndexAssign(float v, string key) {
        _values[key] = TOMLValue(v);
        return v;
    }

    float opIndexAssign(bool v, string key) {
        _values[key] = TOMLValue(v);
        return v;
    }

    TOMLValue opIndexAssign(TOMLValue  v, string key) {
        _values[key] = v;
        return v;
    }

    TOMLValue opIndex(string v) {
        return _values[v];
    }
}

void _toTOMLDictionary(ParseTree p, ref TOMLDictionary dict, string pfx = null) {
    writeln("Handling ", p.name);

    TOMLValue __valueLine(ParseTree valueNode){ 
        auto v = valueNode.matches[0];
        writeln(valueNode.name);
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
            writeln("Adding node %d", name);
            if (pfx) {
                dict[pfx ~"."~ name] = __valueLine(value);
            } else{
                dict[name] = __valueLine(value);
            }
            break;
        case "TOML.KeyGroup":
            auto header = p.children[0].children[0].matches[0]; //HeaderName node
            writeln("Adding header %s", header);
            auto vals = p.children[1..$];
            foreach (v; vals) {
                _toTOMLDictionary(v, dict, pfx=header);
            }
            break;
        default:
            break;
    }
}

TOMLDictionary parse(string data) {
    auto parseTree = TOML(data);
    TOMLDictionary dict;
    foreach(p; parseTree.children[0].children) {
        _toTOMLDictionary(p, dict);
    }
    return dict;
}

unittest {

    enum TEST1 = `
        key_string = "string_value"
        key_array = ["string_1", "string_2"]

        [servers]
        a = 12
        `;

    auto d = parse(TEST1);

    assert(d["key_string"].str == "string_value");
    assert(d["servers.a"].integer == 12);

}
