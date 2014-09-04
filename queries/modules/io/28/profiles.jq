jsoniq version "1.0";
module namespace m = "http://28.io/profiles";

declare variable $m:ITERATOR-THRESHOLD := 10;

declare %an:sequential function m:preprocess-profile($json-profile as object) as object
{
    m:do-preprocess-functions($json-profile("iterator-tree"));
    m:do-preprocess-profile($json-profile("iterator-tree"));
    replace value of json $json-profile("iterator-tree")("prof-name") with "<main-query>";
    $json-profile
};

(:
  the choice to drop an iterator is made on its ancestors
  if the function is called on an iterator, it will be present in the final plan
:)
declare %private %an:sequential function m:do-preprocess-profile($iterator as object) as ()
{ 
    m:do-compute-exclusive-times($iterator);
    
    if (empty(members($iterator("iterators"))))
    then ()
    else
    { 
        variable $i as xs:integer := jn:size($iterator("iterators"));
        while ($i > 0)
        {
            variable $child-iterator := $iterator("iterators")()[$i];
            if 
            (
                (
                    (exists($child-iterator("prof-wall")) and $child-iterator("prof-wall") le $m:ITERATOR-THRESHOLD)
                    or
                    (not(exists($child-iterator("prof-wall"))) and count(members($child-iterator("iterators"))) eq 0)
                    (:
                    or
                    (
                        exists($iterator("prof-wall")) and 
                        exists($child-iterator("prof-wall")) and
                        $iterator("prof-wall") div $m:ITERATOR-RATIO-THRESHOLD > $child-iterator("prof-wall") and 
                        $iterator("prof-cpu") div $m:ITERATOR-RATIO-THRESHOLD > $child-iterator("prof-cpu") and
                        $child-iterator("prof-wall") le $m:ITERATOR-THRESHOLD
                    )
                    :)
                )
                and not($child-iterator("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator", "EvalQueryIterator"))
            )
            then
            {
                delete json $iterator("iterators")($i);
                $i := $i - 1;
            }
            else 
            {
                (:
                Replace iterators that
                    1) are (e.g.:TryCatchIterator, TreatIterator,  FunctionTraceIterator)
                    2) have no wall time
                :)
                if 
                (
                    $child-iterator("kind") = ("TryCatchIterator", "TreatIterator", "FunctionTraceIterator", "IfThenElseIterator")
                    or
                    not(exists($child-iterator("prof-wall")))
                )
                then 
                {
                    variable $new-iterators :=  count(members($child-iterator("iterators")));
                    
                    for $inherited-iterator at $j in members($child-iterator("iterators"))
                    return insert json $inherited-iterator into $iterator("iterators") at position $i + $j;
                    
                    delete json $iterator("iterators")($i);
                    
                    $i := $i + $new-iterators - 1;
                }
                else
                {
                    $i := $i - 1;
                }
            }
        }
        
        for $child-iterator in members($iterator("iterators"))
        return m:do-preprocess-profile($child-iterator);
    }
};

declare %private %an:sequential function m:do-compute-exclusive-times($iterator as object) as ()
{
    if (empty($iterator("prof-wall")))
    then ();
    else
    {
        switch ($iterator("kind"))
            case "UDFunctionBody" return 
            {
                variable $timed-function-children :=  m:get-timed-function-children($iterator);
                insert json 
                {  
                    "prof-exclusive-wall": max(($iterator("prof-wall") - sum($timed-function-children("prof-wall")), 0)),
                    "prof-exclusive-cpu": max(($iterator("prof-cpu") - sum($timed-function-children("prof-cpu")), 0))
                    (:),
                    "prof-function-children-iterators": string-join(for $x in $timed-function-children("prof-cpu") return string($x), " "):)
                } into $iterator;
            }
            case "ExtFunctionArgs" return ();
            case "ExtFunctionBody" return ();
            default return ();
            (:
            {
                variable $timed-children :=  m:get-timed-children($iterator);
                insert json 
                {  
                    "prof-exclusive-wall": $iterator("prof-wall") - sum($timed-children("prof-wall")),
                    "prof-exclusive-cpu": $iterator("prof-cpu") - sum($timed-children("prof-cpu"))
                } into $iterator;
            }
            :)
    }
};

declare %private %an:sequential function m:do-preprocess-functions($iterator as object) as ()
{ 
    switch($iterator("kind"))
        case "ExtFunctionCallIterator" return m:preprocess-external-function($iterator);
        case "UDFunctionCallIterator" return m:preprocess-udf-function($iterator);
    default return ();
    
    for $child-iterator in members($iterator("iterators"))
    return m:do-preprocess-functions($child-iterator);
};

declare %private %an:sequential function m:preprocess-udf-function($function-call-iterator as object) as ()
{
    variable $function-args-iterator := members($function-call-iterator("iterators"))[$$.kind eq "UDFunctionArgs"];
    variable $function-body-iterator := members($function-call-iterator("iterators"))[$$.kind eq "UDFunctionBody"];
    
    if (exists($function-args-iterator) and exists($function-args-iterator("iterators")))
    then 
    {
        variable $timed-args-children :=  m:get-timed-children($function-args-iterator);
        insert json 
        {
            "prof-cpu" : sum($timed-args-children("prof-cpu")),
            "prof-wall" : sum($timed-args-children("prof-wall")),
            "prof-name" : "ArgumentIterator",
            "prof-calls" : max($timed-args-children("prof-calls")),
            "prof-next-calls" : sum($timed-args-children("prof-next-calls")),
            "location": $function-call-iterator("location")
        }
        into $function-args-iterator;
    }
    else ();
    
    if (exists($function-body-iterator) and exists($function-body-iterator("iterators")))
    then 
    {
        variable $timed-body-children :=  m:get-timed-children($function-body-iterator);
        insert json 
        {|
            {
                "prof-cpu" : sum($timed-body-children("prof-cpu")),
                "prof-wall" : sum($timed-body-children("prof-wall")),
                "prof-name" : $function-call-iterator("prof-name"),
                "prof-calls" : $function-call-iterator("prof-calls"),
                "prof-next-calls" : $function-call-iterator("prof-next-calls"),
                "location": $timed-body-children[1]("location")
            },
            if ($function-call-iterator("cached"))
            then
            {
                "cached": true,
                "prof-cache-hits" : $function-call-iterator("prof-cache-hits"),
                "prof-cache-misses" : $function-call-iterator("prof-cache-misses")
            }
            else ()
        |} into $function-body-iterator;
    }
    else ();
};

declare %private %an:sequential function m:preprocess-external-function($function-call-iterator as object) as ()
{
    if (exists($function-call-iterator("iterators")))
    then
    {
        variable $timed-children :=  m:get-timed-children($function-call-iterator);
        replace value of json $function-call-iterator("iterators") with
        [
            {
                "kind": "ExtFunctionArgs",
                "prof-cpu" : sum($timed-children("prof-cpu")),
                "prof-wall" : sum($timed-children("prof-wall")),
                "prof-name": "ArgumentIterator",
                "prof-exclusive-wall" : sum($timed-children("prof-wall")),
                "prof-excusive-cpu" : sum($timed-children("prof-cpu")),
                "prof-calls" : max($timed-children("prof-calls")),
                "prof-next-calls" : sum($timed-children("prof-next-calls")),
                "location": $function-call-iterator("location"),
                "iterators": $function-call-iterator("iterators")
            },
            {|
                {
                    "kind": "ExtFunctionBody",
                    "prof-cpu" : $function-call-iterator("prof-cpu") - sum($timed-children("prof-cpu")),
                    "prof-wall" : $function-call-iterator("prof-wall") - sum($timed-children("prof-wall")),
                    "prof-name": $function-call-iterator("prof-name"),
                    "prof-exclusive-wall" : $function-call-iterator("prof-wall") - sum($timed-children("prof-wall")),
                    "prof-exclusive-cpu" : $function-call-iterator("prof-cpu") - sum($timed-children("prof-cpu")),
                    "prof-calls" : $function-call-iterator("prof-calls"),
                    "prof-next-calls" : $function-call-iterator("prof-next-calls"),
                    "iterators": []
                },
                if ($function-call-iterator("cached"))
                then
                {
                    "cached": true,
                    "prof-cache-hits" : $function-call-iterator("prof-cache-hits"), 
                    "prof-cache-misses" : $function-call-iterator("prof-cache-misses")
                }
                else ()
            |}
        ];
    }
    else
    {
        insert json 
        {
            "iterators": 
            [
                {|
                    {
                        "kind": "ExtFunctionBody",
                        "prof-cpu" : $function-call-iterator("prof-cpu"),
                        "prof-wall" : $function-call-iterator("prof-wall"),
                        "prof-name": $function-call-iterator("prof-name"),
                        "prof-exclusive-wall" : $function-call-iterator("prof-wall"),
                        "prof-esclusive-cpu" : $function-call-iterator("prof-cpu"),
                        "prof-calls" : $function-call-iterator("prof-calls"),
                        "prof-next-calls" : $function-call-iterator("prof-next-calls"),
                        "iterators": []
                    },
                    if ($function-call-iterator("cached"))
                    then
                    {
                        "cached": true,
                        "prof-cache-hits" : $function-call-iterator("prof-cache-hits"), 
                        "prof-cache-misses" : $function-call-iterator("prof-cache-misses")
                    }
                    else ()
                |}
            ]
        }
        into $function-call-iterator;
    }
};

declare %private function m:get-timed-children($iterator as object) as object*
{
    for $child-iterator in members($iterator("iterators"))
    return 
    {
        if (exists($child-iterator("prof-wall")))
        then $child-iterator
        else m:get-timed-children($child-iterator)
    }
};

declare %private function m:get-timed-function-children($iterator as object) as object*
{
    for $child-iterator in members($iterator("iterators"))
    return 
    {
        if ($child-iterator("kind") = ("UDFunctionBody", "ExtFunctionBody"))
        then $child-iterator
        else m:get-timed-function-children($child-iterator)
    }
};
