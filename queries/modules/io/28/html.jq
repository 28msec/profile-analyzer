jsoniq version "1.0";
module namespace html = "http://28.io/html";

declare variable $html:BUCKET := "http://profile-analyzer.s3-website-us-east-1.amazonaws.com";

declare function html:page($json-profile as object()) as element()
{
    <html>
    {
        html:head(),
        html:body($json-profile)
    }
    </html>
};

declare function html:head() as element()
{
  <head>
    <link rel="stylesheet" type="text/css" href="{$html:BUCKET}/libs/treetable/css/jquery.treetable.css"/>
    <link rel="stylesheet" type="text/css" href="{$html:BUCKET}/libs/tablesorter/themes/blue/style.css"/>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"/>
    <script src="{$html:BUCKET}/libs/treetable/jquery.treetable.js"/>
    <script src="{$html:BUCKET}/libs/tablesorter/jquery.tablesorter.js"/>
    <link rel="stylesheet" type="text/css" href="{$html:BUCKET}/styles/treetable.theme.css"/>
    <style type="text/css">
    <!--
      th { white-space: nowrap; padding-right: 20px !important}
      td.query {background-color: #85E085 !important}
      td.library {background-color: #FFB870 !important}
      td.zorba {background-color: #FFB8B8 !important}
    -->
</style>
  </head>
};

declare function html:body($json-profile as object()) as element()
{
    <body>
    {
        html:function-statistics($json-profile),
        html:function-calls-statistics($json-profile),
        html:mongo-statistics($json-profile)
    }   
    </body>   
};

declare function html:function-statistics($json-profile as object()) as element()*
{
    <h3>Most expensive functions</h3>,
    <table cellspacing="1" id="functions" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU (ms)</th>
                <th>Wall (ms)</th>
                <th>Calls</th>
                <th>Nexts</th>
                <th>C. Hits</th>
                <th>C. Misses</th>
            </tr> 
        </thead>
        <tbody>
        {
            for $function in descendant-objects($json-profile)
            where $function("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator")
            group by $function("prof-name")
            return
                <tr>
                    <td>{$function("prof-name")[1]}</td>
                    <td>{sum($function("prof-cpu"))}</td>
                    <td>{sum($function("prof-wall"))}</td>
                    <td>{sum($function("prof-calls"))}</td>
                    <td>{sum($function("prof-next-calls"))}</td>
                    <td>{if ($function("cached")[1]) then (sum($function("prof-cache-hits")), "??")[1] else "N/A"}</td>
                    <td>{if ($function("cached")[1]) then (sum($function("prof-cache-misses")), "??")[1] else "N/A"}</td>
                </tr>
        }
        </tbody>
    </table>,
    <script lang="text/javascript">
        $(document).ready(function() 
        {{ 
            $("#functions").tablesorter({{ sortList: [[2,1]] }}); 
        }}); 
    </script>
};

declare function html:function-calls-statistics($json-profile as object()) as element()*
{
    <h3>Most expensive functions calls</h3>,
    <table cellspacing="1" id="function-calls" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU (ms)</th>
                <th>Wall (ms)</th>
                <th>Calls</th>
                <th>Nexts</th>
                <th>C. Hits</th>
                <th>C. Misses</th>
                <th>Location</th>
            </tr> 
        </thead>
        <tbody>
        {
            for $function in descendant-objects($json-profile)
            where $function("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator")
            return
                <tr>
                    <td>{$function("prof-name")}</td>
                    <td>{$function("prof-cpu")}</td>
                    <td>{$function("prof-wall")}</td>
                    <td>{$function("prof-calls")}</td>
                    <td>{$function("prof-next-calls")}</td>
                    <td>{if ($function("cached")) then ($function("prof-cache-hits"), "??")[1] else "N/A"}</td>
                    <td>{if ($function("cached")) then ($function("prof-cache-misses"), "??")[1] else "N/A"}</td>
                    {html:location($function("location"))}
                </tr>
        }
        </tbody>
    </table>,
    <script lang="text/javascript">
        $(document).ready(function() 
        {{ 
            $("#function-calls").tablesorter({{ sortList: [[2,1]] }}); 
        }}); 
    </script>
};

declare function html:mongo-statistics($json-profile as object()) as element()*
{
    <h3>MongoDB operations</h3>,
    <table cellspacing="1" id="mongodb" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU (ms)</th>
                <th>Wall (ms)</th>
                <th>Calls</th>
                <th>Nexts</th>
                <th>Stack</th>
                <th>Operation</th>
            </tr> 
        </thead>
        <tbody>
        {
            (:
            for $function in descendant-objects($json-profile)
            where ($function("kind") eq "ExtFunctionCallIterator")
                  and
                  starts-with($function("prof-name"), "{http://www.28msec.com/modules/mongodb}")
            return
                <tr>
                    <td>{ substring-after($function("prof-name"), "{http://www.28msec.com/modules/mongodb}") }</td>
                    <td>{$function("prof-cpu")}</td>
                    <td>{$function("prof-wall")}</td>
                    <td>{$function("prof-calls")}</td>
                    <td>{$function("prof-next-calls")}</td>
                    {html:location($function("location"))}
                    <td>{html:serialize-incell(members($function("prof-queries")), "prof-collection")}</td>
                    <td>{html:serialize-incell(members($function("prof-queries")), "prof-query")}</td>
                    <td>{html:serialize-incell(members($function("prof-queries")), "prof-plan")}</td>
                </tr>
            :)
            html:visit-with-ancestors($json-profile, 
                function ($iterator as object, $ancestors as object()*) as element()? 
                { 
                    if (($iterator("kind") eq "ExtFunctionCallIterator") and
                        starts-with($iterator("prof-name"), "{http://www.28msec.com/modules/mongodb}"))
                    then
                        <tr>
                            <td nowrap="true">{ substring-after($iterator("prof-name"), "{http://www.28msec.com/modules/mongodb}") }</td>
                            <td>{$iterator("prof-cpu")}</td>
                            <td>{$iterator("prof-wall")}</td>
                            <td>{$iterator("prof-calls")}</td>
                            <td>{$iterator("prof-next-calls")}</td>
                            {html:stack-trace($ancestors, false())}
                            <td>
                            {
                                if (members($iterator("prof-queries")))
                                then
                                    <table>
                                        <tr>
                                            <th>Collection</th>
                                            <th>Query</th>
                                            <th>Plan</th>
                                        </tr>
                                        {
                                            for $query in members($iterator("prof-queries"))
                                            return
                                            {
                                                <tr>
                                                    <td width="150px">{$query("prof-collection")}</td>
                                                    <td width="300px">{serialize($query("prof-query"))}</td>
                                                    <td>{serialize($query("prof-plan"))}</td>
                                                </tr>
                                            }
                                        }
                                    </table>
                                else ()
                            }
                            </td>
                        </tr>
                    else ()
                })
        }
        </tbody>
    </table>,
    <script lang="text/javascript">
        $(document).ready(function() 
        {{ 
            $("#mongodb").tablesorter({{ sortList: [[2,1]] }}); 
        }}); 
    </script>
};

declare function html:serialize-incell($objects as object()*, $field-name as string) as item()*
{
  let $count := count($objects($field-name))
  for $field-value at $i in $objects($field-name)
  return 
      (
        serialize($field-value),
        if ($i ne $count)
        then <hr/>
        else ()
      )
};

(:
while (m:filter($json-profile("iterator-tree"), function ($iterator as object, $parent as object) as object*
                                                    { 
                                                        if (empty($iterator("prof-wall")))
                                                        then members($iterator("iterators"))
                                                        else $iterator
                                                    })) {};
:)

declare function html:visit-with-ancestors($json-profile as object(), $visitor as function(*)) as item()*
{
    html:visit-with-ancestors($json-profile("iterator-tree"), (), $visitor)
};

declare function html:visit-with-ancestors($iterator as object(), $ancestors as object()*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    let $ancestors := ($ancestors, $iterator)
    return members($iterator("iterators")) ! html:visit-with-ancestors($$, $ancestors, $visitor)
};

declare function html:location($raw-location as xs:string) as element()
{
    if (matches($raw-location, "file:///opt/sausalito/\\d.\\d.\\d/opt/Sausalito-App-Server-Mongo-\\d.\\d.\\d/share/zorba/uris.*/modules.*\\.module:.*"))
    then 
        <td class='zorba' nowrap="true">{replace($raw-location, "file:///opt/sausalito/\\d.\\d.\\d/opt/Sausalito-App-Server-Mongo-\\d.\\d.\\d/share/zorba/uris.*/modules(.*)\\.module(:.*)", "<Z>$1$2")}</td>
    else if (matches($raw-location, "/lib.*\\.module:.*")) 
         then <td class='library' nowrap="true">{replace($raw-location, "/lib(.*)\\.module(:.*)", "<L>$1$2")}</td> 
         else if (matches($raw-location, "/(public|private).*\\.(xq|jq)(:.*)")) 
              then <td class='query' nowrap="true">{replace($raw-location, "/(public|private)(.*\\.)(xq|jq)(:.*)", "<Q>/$1$2$3$4")}</td> 
              else <td nowrap="true">{"<?>" || $raw-location}</td>
};

declare function html:stack-trace($ancestors as object()*, $only-user-code as xs:boolean) as element()
{
    <td nowrap="true">
    {
        for $ancestor in reverse($ancestors)
        let $location := html:location($ancestor("location"))
        where $ancestor("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator")
        return ($ancestor("prof-name")|| "()", <br/>)
    }
    </td>
};