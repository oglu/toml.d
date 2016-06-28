toml.d. A TOML Parser for D
============================

Usage:

```D
import toml.d;

auto config = parse(`
    title = "TOML Example"

    [owner]
    name = "Tom Preston-Werner"
    organization = "GitHub"
    bio = "GitHub Cofounder & CEO\nLikes tater tots and beer."
    dob = 1979-05-27T07:32:00Z # First class dates? Why not?

    [database]
    server = "192.168.1.1"
    ports = [ 8001, 8001, 8002 ]
    connection_max = 5000
    enabled = true
    `);

auto title = config["title"].str;
auto db = config["database"]["server"].str;
```

or

```D
auto config = parseFile("/path/to/toml.conf");
```

TODO
--------------

1) Tables in tables


