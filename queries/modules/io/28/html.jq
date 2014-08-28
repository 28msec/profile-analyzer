jsoniq version "1.0";
module namespace html = "http://28.io/html";
import module namespace resp = "http://www.28msec.com/modules/http-response";

declare variable $html:BUCKET := "http://profile-analyzer.s3-website-us-east-1.amazonaws.com";

declare %an:sequential function html:page($json-profile as object(), $query as xs:string) as element()
{
    resp:content-type("text/html");
    <html>
    {
        html:head(),
        html:body($json-profile, $query)
    }
    </html>
};

declare %an:sequential function html:form-page() as element()
{
    resp:content-type("text/html");
    <html>
    {
        html:head(),
        <body>
        {
            html:form()
        }
        </body>
    }
    </html>
};

declare function html:form() as element()
{
    html:form("http://secxbrl-federico.xbrl.io/v1/_queries/public/api/facttable-for-report.jq/metadata/profile?report=FundamentalAccountingConcepts&ticker=intc",
              "UElST0M3UjNSbXAvVkdVdkdMbnJqY2RXRHRFPToyMDUwLTAxLTAxVDAwOjAwOjAw")
};

declare function html:form($query as xs:string, $token as xs:string) as element()
{
    <form action="/v1/_queries/public/index.jq" method="POST">
        Query: <input type="text" name="query" value="{$query}" size="180"/><br/>
        Token: <input type="text" name="project-token" value="{$token}" size="180"/><br/>
        Force reprofiling (and remove any cached profile for this query): <input type="checkbox" name="force-profile" value="true"/><br/>
        <input type="submit" value="Submit"/>
    </form>
};

declare function html:head() as element()
{
  <head>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"/>
    <script src="{$html:BUCKET}/libs/treetable/jquery.treetable.js"/>
    <script src="{$html:BUCKET}/libs/tablesorter/jquery.tablesorter.js"/>
    <link rel="stylesheet" type="text/css" href="{$html:BUCKET}/styles/style.css"/>
  </head>
};

declare function html:body($json-profile as object(), $query as xs:string) as element()
{
    <body>
    {
        <h1>Profiling results</h1>,
        <b>Query: </b>, {$query}, <br/>,
        if (exists($json-profile("date")))
        then <b>Using cached profile from {$json-profile("date")}</b>
        else (),
        html:profile-tree($json-profile, true()),
        html:profile-tree($json-profile, false()),
        html:function-statistics($json-profile),
        html:function-calls-statistics($json-profile),
        html:mongo-statistics($json-profile),
        html:eval-statistics($json-profile)
    }   
    </body>   
};

declare function html:profile-tree($json-profile as object(), $only-functions as xs:boolean) as element()*
{
    let $id := "profile-tree" || (if ($only-functions) then "-functions" else ())
    return
    (
        <h3>Query Profile{ if ($only-functions) then " (Only Functions)" else () }</h3>,
        <table cellspacing="1" id="{$id}" class="treetable">
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
                html:visit-with-ancestor-ids($json-profile, $only-functions,
                    function ($iterator as object, $ancestors as xs:string*) as element()? 
                    { 
                        <tr>
                        {
                            attribute data-tt-id {string-join($ancestors,"-")},
                            if (count($ancestors) gt 1)
                            then attribute data-tt-parent-id {string-join($ancestors[position() < last()], "-")}
                            else ()
                        }
                            <td>
                                <span class="{
                                    if ($iterator("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator"))
                                    then "function"
                                    else "iterator"}">
                                        {$iterator("prof-name")}
                                </span>
                            </td>
                            <td>{$iterator("prof-cpu")}</td>
                            <td>{$iterator("prof-wall")}</td>
                            <td>{$iterator("prof-calls")}</td>
                            <td>{$iterator("prof-next-calls")}</td>
                            <td>{if ($iterator("cached")) then ($iterator("prof-cache-hits"), "??")[1] else "N/A"}</td>
                            <td>{if ($iterator("cached")) then ($iterator("prof-cache-misses"), "??")[1] else "N/A"}</td>
                            <td>{html:location-text($iterator("location"))}</td>
                        </tr>
                    })
            }
            </tbody>
        </table>,
        <a href="#" onclick="jQuery('#{$id}').treetable('expandAll'); return false;">Expand all</a>,
        <a href="#" onclick="jQuery('#{$id}').treetable('collapseAll'); return false;">Collapse all</a>,
        <script lang="text/javascript">
            $("#{$id}").treetable({{ expandable: true }});
            $("#{$id} tbody").on("mousedown", "tr", function() 
            {{
                $(".selected").not(this).removeClass("selected");
                $(this).toggleClass("selected");
            }});
        </script>
    )
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
        $("#functions tbody").on("mousedown", "tr", function() 
        {{
            $(".selected").not(this).removeClass("selected");
            $(this).toggleClass("selected");
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
                <th>Stack Trace</th>
            </tr> 
        </thead>
        <tbody>
        {
            html:visit-with-ancestors($json-profile,
                function ($iterator as object, $ancestors as object()*) as element()? 
                { 
                    if ($iterator("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator"))
                    then
                        <tr>
                            <td>{$iterator("prof-name")}</td>
                            <td>{$iterator("prof-cpu")}</td>
                            <td>{$iterator("prof-wall")}</td>
                            <td>{$iterator("prof-calls")}</td>
                            <td>{$iterator("prof-next-calls")}</td>
                            <td>{if ($iterator("cached")) then ($iterator("prof-cache-hits"), "??")[1] else "N/A"}</td>
                            <td>{if ($iterator("cached")) then ($iterator("prof-cache-misses"), "??")[1] else "N/A"}</td>
                            {html:stack-trace($ancestors, html:location-text($iterator("location")))}
                        </tr>
                    else ()
                })
        }
        </tbody>
    </table>,
    <script lang="text/javascript">
        $(document).ready(function() 
        {{ 
            $("#function-calls").tablesorter({{ sortList: [[2,1]] }}); 
        }});
        $("#function-calls tbody").on("mousedown", "tr", function() 
        {{
            $(".selected").not(this).removeClass("selected");
            $(this).toggleClass("selected");
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
                <th>Stack Trace</th>
                <th>Operations</th>
            </tr> 
        </thead>
        <tbody>
        {
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
                            {html:stack-trace($ancestors, ())}
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
        $("#mongodb tbody").on("mousedown", "tr", function() 
        {{
            $(".selected").not(this).removeClass("selected");
            $(this).toggleClass("selected");
        }});
    </script>
};

declare function html:eval-statistics($json-profile as object()) as element()*
{
    <h3>Eval operations</h3>,
    <table cellspacing="1" id="eval" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU (ms)</th>
                <th>Wall (ms)</th>
                <th>C. CPU (ms)</th>
                <th>C. Wall (ms)</th>
                <th>Calls</th>
                <th>Nexts</th>
                <th>Stack Trace</th>
                <th>Operations</th>
            </tr> 
        </thead>
        <tbody>
        {
            html:visit-with-ancestors($json-profile, 
                function ($iterator as object, $ancestors as object()*) as element()? 
                { 
                    if ($iterator("kind") eq "EvalIterator")
                    then
                        <tr>
                            <td nowrap="true">{$iterator("prof-name")}</td>
                            <td>{$iterator("prof-cpu")}</td>
                            <td>{$iterator("prof-wall")}</td>
                            <td>{$iterator("prof-compilation-cpu")}</td>
                            <td>{$iterator("prof-compilation-wall")}</td>
                            <td>{$iterator("prof-calls")}</td>
                            <td>{$iterator("prof-next-calls")}</td>
                            {html:stack-trace($ancestors, ())}
                            <td>
                            {
                                if (members($iterator("iterators"))[$$.kind eq "EvalQueryIterator"])
                                then
                                    <table>
                                        <tr>
                                            <th>Query</th>
                                            <th>CPU (ms)</th>
                                            <th>Wall (ms)</th>
                                            <th>C. CPU (ms)</th>
                                            <th>C. Wall (ms)</th>
                                        </tr>
                                        {
                                            for $query in members($iterator("iterators"))[$$.kind eq "EvalQueryIterator"]
                                            return
                                            {
                                                <tr>
                                                    <td>{serialize($query("prof-body"))}</td>
                                                    <td>{$query("prof-cpu")}</td>
                                                    <td>{$query("prof-wall")}</td>
                                                    <td>{$query("prof-compilation-cpu")}</td>
                                                    <td>{$query("prof-compilation-wall")}</td>
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
        $("#mongodb tbody").on("mousedown", "tr", function() 
        {{
            $(".selected").not(this).removeClass("selected");
            $(this).toggleClass("selected");
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

declare function html:visit-with-ancestors($json-profile as object(), $visitor as function(*)) as item()*
{
    html:do-visit-with-ancestors($json-profile("iterator-tree"), (), $visitor)
};


declare function html:do-visit-with-ancestors($iterator as object(), $ancestors as object()*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    let $ancestors := ($ancestors, $iterator)
    return members($iterator("iterators")) ! html:do-visit-with-ancestors($$, $ancestors, $visitor)
};

declare function html:visit-with-ancestor-ids($json-profile as object(), $only-functions as xs:boolean, $visitor as function(*)) as item()*
{
    if ($only-functions)
    then html:do-visit-functions-with-ancestor-ids($json-profile("iterator-tree"), "1", $visitor)
    else html:do-visit-with-ancestor-ids($json-profile("iterator-tree"), "1", $visitor)
};

declare function html:do-visit-with-ancestor-ids($iterator as object(), $ancestors as xs:string*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    for $child at $i in members($iterator("iterators"))
    let $ancestors := ($ancestors, string($i))
    return html:do-visit-with-ancestor-ids($child, $ancestors, $visitor)
};


declare function html:do-visit-functions-with-ancestor-ids($iterator as object(), $ancestors as xs:string*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    
    for $child at $i in html:top-function-child(members($iterator("iterators")))
    let $ancestors := ($ancestors, string($i))
    return html:do-visit-functions-with-ancestor-ids($child, $ancestors, $visitor)
};

declare function html:top-function-child($iterators as object()*) as object()*
{
    for $iterator in $iterators
    return
    {
        if ($iterator("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator"))
        then $iterator
        else html:top-function-child(members($iterator("iterators")))
    }
};


declare function html:location-text($raw-location as xs:string?) as xs:string?
{
    if ($raw-location)
    then
        if (matches($raw-location, "file:///opt/sausalito/\\d.\\d.\\d/opt/Sausalito-App-Server-Mongo-\\d.\\d.\\d/share/zorba/uris.*/.*\\.module:.*"))
        then 
            replace($raw-location, "file:///opt/sausalito/\\d.\\d.\\d/opt/Sausalito-App-Server-Mongo-\\d.\\d.\\d/share/zorba/uris.*/(.*)\\.module(:.*)", "<Z>/$1$2")
        else if (matches($raw-location, "/lib.*\\.module:.*")) 
             then replace($raw-location, "/lib(.*)\\.module(:.*)", "<L>$1$2")
             else if (matches($raw-location, "/(public|private).*\\.(xq|jq)(:.*)")) 
                  then replace($raw-location, "/(public|private)(.*\\.)(xq|jq)(:.*)", "<Q>/$1$2$3$4")
                  else "<?>" || $raw-location
    else ()
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

declare function html:stack-trace($ancestors as object()*, $location as xs:string?) as element()
{
    <td nowrap="true">
    {
        if ($location) then ($location, <br/>) else (),
        for $ancestor in reverse($ancestors)
        where $ancestor("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator")
        return ($ancestor("prof-name")|| "()", <br/>),
        "<main-query>"
    }
    </td>
};

