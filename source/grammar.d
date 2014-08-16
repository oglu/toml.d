import pegged.grammar;

enum PEG = `
TOML:

  Document          <- (ValueLine)* KeyGroup*

  KeyGroup          <- Header ValueLine* 

  Header            <- ignore "[" HeaderName "]" line_end
  HeaderName        <- qualifiedIdentifier

  ValueLine         <- :ignore Name :ws :"=" :ws Value line_end
  Name              <- identifier 
  Value             <- DatetimeValue / StringValue / FloatValue / IntegerValue / BooleanValue / Array


  #
  # Strings
  # -----------------------------------------------------------------

  StringValue       <~ :doublequote (!doublequote Char)* :doublequote 
  Char              <~ backslash ( doublequote  # '\' Escapes
                        / quote
                        / backslash
                        / [bfnrt]
                        / [0-2][0-7][0-7]
                        / [0-7][0-7]?
                        / 'x' Hex Hex
                        / 'u' Hex Hex Hex Hex
                        / 'U' Hex Hex Hex Hex Hex Hex Hex Hex
                        )
                        / . # Or any char, really
  Hex               <- [0-9a-fA-F]             

  #
  # Numbers
  # -------------------------------------------

  Digit             <- [0-9]
  IntegerValue      <~ "-"? [1-9] digit* 
  FloatValue        <~ IntegerValue "." digit+ 

  #
  # DateTime
  # -------------------------------------------

  DatetimeValue     <~ ([1-9] digit digit digit) "-" (digit digit) "-" (digit digit) "T" (digit digit) ":" (digit digit) ":" (digit digit) "Z"

  #
  # Boolean
  # -------------------------------------------

  BooleanValue      <- ("true" / "false")

  #
  # Arrays
  # -------------------------------------------

  Array             <- EmptyArray / DatetimeArray / StringArray / IntegerArray / FloatArray / ArrayOfArray
  EmptyArray        <- :"[" ws :"]"
  StringArray       <- :"[" ws StringValue      (ws :"," ws StringValue)*   ws :"]"
  IntegerArray      <- :"[" ws IntegerValue     (ws :"," ws IntegerValue)*  ws :"]"
  FloatArray        <- :"[" ws FloatValue       (ws :"," ws FloatValue)*    ws :"]"
  DatetimeArray     <- :"[" ws DatetimeValue    (ws :"," ws DatetimeValue)* ws :"]"
  ArrayOfArray      <- :"[" ws Array            (ws :"," ws Array)*         ws :"]"


  #
  # Helpers
  # -----------------------------------------

  line_end        <- ws comment? !(!eol .)
  ignore          <- :(comment / space / eol)*
  comment         <- "#" (!eol .)*
  ws              <- :space*


`;

//pragma(msg, grammar(PEG));

mixin(grammar(PEG));

unittest {
    import std.stdio;
    import pegged.tester.grammartester;
    
    auto grtest = new GrammarTester!(TOML, "Document");

    grtest.assertSimilar(`key = 1`, `
            Document -> {
                ValueLine -> {
                    Name
                    Value -> {
                        IntegerValue
                        }
                }
            }
            `);

    grtest.assertSimilar(`key = "hello world"`, `
            Document -> {
                ValueLine -> {
                    Name
                    Value -> {
                        StringValue
                        }
                }
            }
            `);

    auto header_checker = new GrammarTester!(TOML, "Header");
    header_checker.assertSimilar("[test]", `
            Header ->
                HeaderName
            `);

    auto intArray = new GrammarTester!(TOML, "IntegerArray");
    intArray.assertSimilar(`[1,2]`,`
            IntegerArray -> {
                IntegerValue
                IntegerValue
                }
            `);

    auto emptyarray = new GrammarTester!(TOML, "EmptyArray");
    emptyarray.assertSimilar(`[         ]`,`
            EmptyArray
            `);


    auto arrayOfArray = new GrammarTester!(TOML, "ArrayOfArray");
    arrayOfArray.assertSimilar(`[[1,2] ]`,`
            ArrayOfArray -> {
                Array -> {
                    IntegerArray -> {
                        IntegerValue
                        IntegerValue
                    }
                }
            }
            `);

   auto keygroup_checker = new GrammarTester!(TOML, "KeyGroup");
    keygroup_checker.assertSimilar(`
            [test]
            key = 1
            `, `
            KeyGroup -> {
                Header -> {
                    HeaderName
                }
                ValueLine -> {
                    Name
                    Value -> {
                        IntegerValue
                        }
                }
            }
            `);

    auto date_checker = new GrammarTester!(TOML, "DatetimeValue");
    date_checker.assertSimilar("1979-05-27T07:32:00Z",  `
            DatetimeValue
            `);


    enum TEST1 = `
        key_string = "hello"
        key_integer = 10
        key_bool = true
    `;

    auto test1 = TOML(TEST1);
    writeln(test1);

    enum TEST2 = `
        key_1 = "test"
        [keygroup]
        key_string = "hello"
        key_integer = 10
        key_bool = true
        key_string_array = ["abc","cde"]
        arrayOfArrays = [[1,2], ["a","b"], [1.2, 1.2]]
        date = 1979-05-27T07:32:00Z
        multistring = "
            hello \tworld
            this is a big 
            multiline
            string
            "

        [servers]

        [servers.alpha]
        z = 1
    `;

    auto test2 = TOML(TEST2);
    writeln(test2);
}
