jsoniq version "1.0";
module namespace m = "http://28.io/profiles";

declare %an:sequential function m:clean-profile($json-profile as object) as ()
{
m:filter($json-profile("iterator-tree"), function ($iterator as object, $parent as object) as object? 
                                             { 
                                                if (empty($iterator("prof-wall")) or $iterator("prof-wall") gt 1)
                                                then $iterator
                                                else ()
                                             });
                                             
while (m:filter($json-profile("iterator-tree"), function ($iterator as object, $parent as object) as object? 
                                                    { 
                                                        if (not(empty($iterator("prof-wall")) and empty($iterator("iterators"))))
                                                        then $iterator
                                                        else ()
                                                    })) {};

while (m:filter($json-profile("iterator-tree"), function ($iterator as object, $parent as object) as object*
                                                    { 
                                                        if (empty($iterator("prof-wall")))
                                                        then members($iterator("iterators"))
                                                        else $iterator
                                                    })) {};
                                                  
while (m:filter($json-profile("iterator-tree"), function ($iterator as object, $parent as object) as object* 
                                                    { 
                                                        (:if ($iterator("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator")):)
                                                        if ($parent("prof-wall") div 20 < $iterator("prof-wall"))
                                                        then $iterator
                                                        else members($iterator("iterators"))
                                                    })) {};
};



declare %an:sequential function m:render-profile($json-profile as object) as string
{
    m:render-profile($json-profile("iterator-tree"), "")
};

declare %an:sequential function m:render-profile($iterator as object, $indentation as string) as string
{
    variable $output := $indentation || $iterator("prof-name") || ": " || $iterator("prof-wall") || " ms, " || $iterator("prof-calls") || " calls\n";
    
    if ($iterator("iterators"))
    then
    {
        for $sub-iterator in members($iterator("iterators"))    
        order by $sub-iterator("prof-wall") descending
        return $output := $output || m:render-profile($sub-iterator, $indentation || "-");
    }
    else ();
    
    $output
};

declare function m:render-json-profile($json-profile as object) as object
{
    m:do-render-json-profile($json-profile("iterator-tree"))
};

declare function m:do-render-json-profile($iterator as object) as object
{
    {
        $iterator("prof-name") || ": " || $iterator("prof-wall") || " ms, " || $iterator("prof-calls") || " calls":
        [
            for $sub-iterator in members($iterator("iterators"))
            order by $sub-iterator("prof-wall") descending
            return m:do-render-json-profile($sub-iterator)
        ]
    }
};

declare %private %an:sequential function m:filter($iterator as object, $filter as function(*)) as boolean
{
  variable $keep := 
  [
    for $member in members($iterator("iterators"))
    return $filter($member, $iterator)
  ];
  
  variable $changed := false;
  
  if (deep-equal(members($keep), members($iterator("iterators"))))
  then ();
  else 
  {
      $changed := true;
      if (count(members($keep)) eq 0)
      then delete json $iterator("iterators");
      else replace value of json $iterator("iterators") with $keep;
  }
  
  for $member in members($iterator("iterators"))
  return 
  {
      if (m:filter($member, $filter))
      then $changed := true;
      else ();
  }
  
  $changed
};

