jsoniq version "1.0";
module namespace m = "http://28.io/profiles";

declare %an:sequential function m:preprocess-profile($json-profile as object, $compute-exclusive-times as boolean) as object
{
    m:do-preprocess-profile($json-profile("iterator-tree"), $compute-exclusive-times);
    replace value of json $json-profile("iterator-tree")("prof-name") with "<main-query>";
    $json-profile
};

(:
  the choice to drop an iterator is made on its ancestors
  if the function is called on an iterator, it will be present in the final plan
:)
declare %private %an:sequential function m:do-preprocess-profile($iterator as object, $compute-exclusive-times as boolean) as ()
{ 
    if ($compute-exclusive-times and exists($iterator("prof-wall")))
    then
    {
        variable $timed-children :=  m:timed-children($iterator);
        insert json 
        {  
            "prof-exclusive-wall": $iterator("prof-wall") - sum($timed-children("prof-wall")),
            "prof-exclusive-cpu": $iterator("prof-cpu") - sum($timed-children("prof-cpu"))
        } into $iterator;
    }
    else ();
    
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
                    (exists($child-iterator("prof-wall")) and $child-iterator("prof-wall") le 5)
                    or
                    (not(exists($child-iterator("prof-wall"))) and count(members($child-iterator("iterators"))) eq 0)
                    or
                    (
                        exists($iterator("prof-wall")) and 
                        exists($child-iterator("prof-wall")) and
                        $iterator("prof-wall") div 15 > $child-iterator("prof-wall") and 
                        $iterator("prof-cpu") div 15 > $child-iterator("prof-cpu") and
                        $child-iterator("prof-wall") le 5
                    )
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
                    ($child-iterator("kind") = ("TryCatchIterator", "TreatIterator", "FunctionTraceIterator", "IfThenElseIterator"))
                    or
                    (not(exists($child-iterator("prof-wall"))))
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
        return m:do-preprocess-profile($child-iterator, $compute-exclusive-times);
    }
};

declare %an:sequential function m:timed-children($iterator as object) as object*
{
    for $child-iterator in members($iterator("iterators"))
    return 
    {
        if (exists($child-iterator("prof-wall")))
        then $child-iterator
        else m:timed-children($child-iterator)
    }
};