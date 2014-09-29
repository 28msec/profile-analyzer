import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";


declare %an:sequential function local:timed-children($iterator as object) as object*
{
    for $child-iterator in members($iterator("iterators"))
    return 
    {
        if (exists($child-iterator("prof-wall")))
        then $child-iterator
        else ()
    }
};

variable $root-iterator := parse-json(http:get("https://profile-analyzer.s3.amazonaws.com/profiles/profile-3.8.0.json")("body")("content"))("iterator-tree");
variable $udh := descendant-objects($root-iterator)[$$.kind eq "UDFunctionCallIterator" and $$.id eq "0x1c9f610"];

{
    "root-iterator": $udh("prof-wall"),
    "child-iterator": local:timed-children($udh)("prof-wall"),
    "child-iterator-sum": sum(local:timed-children($udh)("prof-wall"))
}

