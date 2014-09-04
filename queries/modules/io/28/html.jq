jsoniq version "1.0";
module namespace html = "http://28.io/html";
import module namespace resp = "http://www.28msec.com/modules/http-response";
import schema namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $html:BUCKET := "http://profile-analyzer.s3-website-us-east-1.amazonaws.com";
declare variable $html:SERIALIZATION-PARAMETERS:=
    <output:serialization-parameters>
        <output:encoding value="UTF-8"/>
        <output:indent value="yes"/>
        <output:method value="json-xml-hybrid"/>
        <output:omit-xml-declaration value="yes"/>
        <output:version value="1.0"/>
    </output:serialization-parameters>;
declare variable $html:ITERATOR-THRESHOLD := 15;

declare %an:sequential function html:profile-page($json-profile as object(), $no-full-iterator-tree as xs:boolean) as element()
{
    resp:content-type("text/html");
    <html>
    {
        html:head(),
        html:profile-body($json-profile, $no-full-iterator-tree)
    }
    </html>
};

declare %an:sequential function html:home-page() as element()
{
    resp:content-type("text/html");
    <html>
    {
        html:head(),
        <body>
        {
            <h2>Profile Analyzer (Alpha)</h2>,
            <p>
                This page allows you to analyze a JSON query profile.
            </p>,
            html:form(),
            html:help(),
            html:cache()
        }
        </body>
    }
    </html>
};

declare %an:sequential function html:cache-updated-page($query as string, $token as string) as element()
{
    resp:content-type("text/html");
    <html>
    {
        html:head(),
        <body>
        {
            <h2>Profile Analyzer (Alpha)</h2>,
            <p>
                This page allows you to analyze a JSON query profile.
            </p>,
            html:form($query, $token),
            <div class="info-box"><b>The profiling data for:</b><br/>{$query}<br/><b>has been successfully cached at {current-dateTime()}</b>.</div>,
            html:help()
        }
        </body>
    }
    </html>
};

declare %an:sequential function html:error-page($code as xs:QName, $description as string, $items as item()*, $stack-trace as item()*, $location as string) as element()
{
    resp:content-type("text/html");
    <html>
    {
        html:head(),
        <body>
        {
            <h2>An error occurred</h2>,
            <p>
                <b>Code: </b> {$code}<br/>
                <b>Description: </b> {$description}<br/>
                <b>Location: </b> {$location}<br/>
                {
                    if (exists($items))
                    then
                    {
                        <b>Data: </b>,<br/>,
                        <pre>{serialize($items)}</pre>
                    }
                    else (),
                    if (exists($stack-trace))
                    then
                    {
                        <b>Stack Trace: </b>,<br/>,
                        <pre>{serialize($stack-trace, $html:SERIALIZATION-PARAMETERS)}</pre>
                    }
                    else ()
                }
                
            </p>,
            <a href="/index.jq">Go Back</a>
        }
        </body>
    }
    </html>
};

declare %private function html:help() as element()*
{
    <h3>How to use</h3>,
    <p>
        In the profile field, you need to specify a URL at which the JSON profile data is available.<br/>
        If the same URL has already been displayed preprocessed data will be retrieved from cache and profiling will be almost instantaneous.<br/>
        otherwise, a GET request will be made to that URL to retrieve the data, passing an header X-28msec-Token with the value of the token field.<br/>
    </p>,
    <p>
        Two common use cases are: 
        <ul>
            <li><a href="#" onclick="loadExample('http://secxbrl-federico.xbrl.io/v1/_queries/public/api/facttable-for-report.jq/metadata/profile?_method=POST&amp;report=FundamentalAccountingConcepts&amp;ticker=intc','UElST0M3UjNSbXAvVkdVdkdMbnJqY2RXRHRFPToyMDUwLTAxLTAxVDAwOjAwOjAw');">View the profile a live query using /metadata/profile.</a></li>
            <li><a href="#" onclick="loadExample('https://profile-analyzer.s3.amazonaws.com/profiles/profile-1.json', '');">View a previously collected profile</a></li>
        </ul>
    </p>,
    <script lang="text/javascript">
    function loadExample(url, token) 
    {{
        document.getElementById("profile-url").value = url;
        document.getElementById("project-token").value = token;
        document.getElementById("only-preprocessing").checked = false;
        document.getElementById("force-preprocessing").checked = false;
        document.getElementById("no-full-iterator-tree").checked = true;
        document.getElementById("iterator-threshold").value = 0;
    }}
    </script>
};

declare %private function html:form() as element()*
{
    html:form("", "")
};

declare %private function html:form($profile as xs:string, $token as xs:string) as element()*
{
    <h3>Submit a new profile to be analyzed</h3>,
    <form id="profileForm" action="/v1/_queries/public/index.jq" method="GET">
    <p>
        Profile URL: <input id="profile-url" type="text" name="profile-url" value="{$profile}" size="180"/><br/>
    </p>
    <p>
        <b>Profiling options:</b> (The profile URL must be a /metadata/plan endpoint) <br/>
        Token: <input id="project-token" type="text" name="project-token" value="{$token}" size="180"/><br/>
        Do not include in the profile iterators taking less than (useful with long queries, but will make the iterator exclusive time less precise): <input type="number" id="iterator-threshold" name="iterator-threshold" min="0" max="5" value="0"/> ms<br/>
    </p>
    <p>
        <b>Caching options:</b><br/>
        Only cache pre-processed data (useful with long queries): <input type="checkbox" id="only-preprocessing" name="only-preprocessing" value="true"/><br/>
        Force pre-processing (removing any cached pre-processed data for this URL): <input type="checkbox" id="force-preprocessing" name="force-preprocessing" value="true"/>
    </p>
    <p> 
        <b>Display options:</b><br/>
        Do not display full iterator tree (might be useful with long queries): <input type="checkbox" id="no-full-iterator-tree" name="no-full-iterator-tree" value="true"/>
    </p>
    <input type="hidden" name="_method" value="POST"/>
    </form>,
    <button class="ladda-button" data-color="green" data-style="expand-left" onclick="submitForm()">Submit</button>,
    <script lang="text/javascript">
    function submitForm() 
    {{
        var l = Ladda.create( document.querySelector( 'button' ) );
		l.start();
		l.stop();
		l.toggle();
		l.isLoading();
		document.getElementById("profileForm").submit();
    }}
    </script>
};

declare %private function html:head() as element()
{
  <head>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"/>
    <script src="{$html:BUCKET}/libs/treetable/jquery.treetable.js"/>
    <script src="{$html:BUCKET}/libs/tablesorter/jquery.tablesorter.js"/>
    <script src="{$html:BUCKET}/libs/ladda/dist/spin.min.js"/>
    <script src="{$html:BUCKET}/libs/ladda/dist/ladda.min.js"/>
    <link rel="stylesheet" href="{$html:BUCKET}/libs/ladda/dist/ladda.min.css"/>
    <link rel="stylesheet" type="text/css" href="{$html:BUCKET}/styles/style.css"/>
  </head>
};

declare %private function html:profile-body($json-profile as object(), $no-full-iterator-tree as xs:boolean) as element()
{
    <body>
    {
        <h1>Profiling results</h1>,
        <b>Query: </b>, {$json-profile("_id")}, <br/>,
        <b>Using profile generated at {$json-profile("date")}</b>, <br/>,
        <b><a download="profile.json" href="/v1/_queries/public/download.jq?_method=POST&amp;profile-url={encode-for-uri($json-profile("_id"))}">Download profile</a></b>,
        html:profile-tree($json-profile, true()),
        if (not($no-full-iterator-tree))
        then html:profile-tree($json-profile, false())
        else (),
        html:function-statistics($json-profile),
        html:function-calls-statistics($json-profile),
        html:mongo-statistics($json-profile),
        html:eval-statistics($json-profile)
    }   
    </body>   
};

declare %private function html:profile-tree($json-profile as object(), $only-functions as xs:boolean) as element()*
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
                    <th>CPU (ms) (no desc)</th>
                    <th>Wall (ms) (no desc)</th>
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
                                    switch ($iterator("kind"))
                                    case "UDFunctionBody" return "udfunction"
                                    case "ExtFunctionBody" return "extfunction"
                                    default return "iterator"
                                    }">
                                        {
                                            if ($iterator("kind") = ("UDFunctionCallIterator", "ExtFunctionCallIterator"))
                                            then "Call to " || $iterator("prof-name") || "(...)"
                                            else $iterator("prof-name")
                                        }
                                </span>
                            </td>
                            <td>{$iterator("prof-cpu")}</td>
                            <td>{$iterator("prof-wall")}</td>
                            <td>{$iterator("prof-exclusive-cpu")}</td>
                            <td>{$iterator("prof-exclusive-wall")}</td>
                            <td>{$iterator("prof-calls")}</td>
                            <td>{$iterator("prof-next-calls")}</td>
                            <td>{if ($iterator("cached")) then ($iterator("prof-cache-hits"), "??")[1] else "N/A"}</td>
                            <td>{if ($iterator("cached")) then ($iterator("prof-cache-misses"), "??")[1] else "N/A"}</td>
                            <td>{if ($iterator("location")) then html:location-text($iterator("location")) else "N/A"}</td>
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

declare %private function html:function-statistics($json-profile as object()) as element()*
{
    <h3>Most expensive functions</h3>,
    <table cellspacing="1" id="functions" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU (ms)</th>
                <th>Wall (ms)</th>
                <th>CPU (ms) (no desc)</th>
                <th>Wall (ms) (no desc)</th>
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
            where $function("kind") = ("UDFunctionBody", "ExtFunctionBody")
            group by $function("prof-name")
            return
                <tr>
                    <td>
                        <span class="{
                                    switch ($function("kind")[1])
                                    case "UDFunctionBody" return "udfunction"
                                    case "ExtFunctionBody" return "extfunction"
                                    default return "iterator"
                                    }">
                                    {
                                            $function("prof-name")[1]
                                    }
                        </span>
                    </td>
                    <td>{sum($function("prof-cpu"))}</td>
                    <td>{sum($function("prof-wall"))}</td>
                    <td>{sum($function("prof-exclusive-cpu"))}</td>
                    <td>{sum($function("prof-exclusive-wall"))}</td>
                    <td>{sum($function("prof-calls"))}</td>
                    <td>{sum($function("prof-next-calls"))}</td>
                    <td>{if ($function("cached")[1]) then (sum($function("prof-cache-hits")), "??")[1] else "N/A"}</td>
                    <td>{if ($function("cached")[1]) then (sum($function("prof-cache-misses")), "??")[1] else "N/A"}</td>
                    <td>{if ($function("kind")[1] eq "UDFunctionBody") then $function("location")[1] else "N/A"}</td>
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

declare %private function html:function-calls-statistics($json-profile as object()) as element()*
{
    <h3>Most expensive functions calls</h3>,
    <table cellspacing="1" id="function-calls" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU (ms)</th>
                <th>Wall (ms)</th>
                <th>CPU (ms) (no desc)</th>
                <th>Wall (ms) (no desc)</th>
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
                            <td>{$iterator("prof-exclusive-cpu")}</td>
                            <td>{$iterator("prof-exclusive-wall")}</td>
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

declare %private function html:mongo-statistics($json-profile as object()) as element()*
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
                                else if (members($iterator("prof-commands")))
                                then
                                    <table>
                                        <tr>
                                            <th>Command</th>
                                            <th>CPU (ms)</th>
                                            <th>Wall (ms)</th>
                                        </tr>
                                        {
                                            for $command in members($iterator("prof-commands"))
                                            return
                                            {
                                                <tr>
                                                    <td>{serialize($command("prof-command"))}</td>
                                                    <td>{$command("prof-cpu")}</td>
                                                    <td>{$command("prof-wall")}</td>
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

declare %private function html:eval-statistics($json-profile as object()) as element()*
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


declare %private function html:serialize-incell($objects as object()*, $field-name as string) as item()*
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

declare %private function html:visit-with-ancestors($json-profile as object(), $visitor as function(*)) as item()*
{
    html:do-visit-with-ancestors($json-profile("iterator-tree"), (), $visitor)
};


declare %private function html:do-visit-with-ancestors($iterator as object(), $ancestors as object()*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    let $ancestors := ($ancestors, $iterator)
    return members($iterator("iterators")) ! html:do-visit-with-ancestors($$, $ancestors, $visitor)
};

declare %private function html:visit-with-ancestor-ids($json-profile as object(), $only-functions as xs:boolean, $visitor as function(*)) as item()*
{
    if ($only-functions)
    then html:do-visit-functions-with-ancestor-ids($json-profile("iterator-tree"), "1", $visitor)
    else html:do-visit-with-ancestor-ids($json-profile("iterator-tree"), "1", $visitor)
};

declare %private function html:do-visit-with-ancestor-ids($iterator as object(), $ancestors as xs:string*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    for $child at $i in members($iterator("iterators"))
    where $child("prof-wall") gt $html:ITERATOR-THRESHOLD
    order by $child("prof-wall") descending
    let $ancestors := ($ancestors, string($i))
    return html:do-visit-with-ancestor-ids($child, $ancestors, $visitor)
};


declare %private function html:do-visit-functions-with-ancestor-ids($iterator as object(), $ancestors as xs:string*, $visitor as function(*)) as item()*
{
    $visitor($iterator, $ancestors),
    
    for $child at $i in html:top-function-child(members($iterator("iterators")))
    where $child("prof-wall") gt $html:ITERATOR-THRESHOLD
    order by $child("prof-wall") descending
    let $ancestors := ($ancestors, string($i))
    return html:do-visit-functions-with-ancestor-ids($child, $ancestors, $visitor)
};

declare %private function html:top-function-child($iterators as object()*) as object()*
{
    for $iterator in $iterators
    return
    {
        if ($iterator("kind") = ("UDFunctionBody", "ExtFunctionBody"))
        then $iterator
        else html:top-function-child(members($iterator("iterators")))
    }
};


declare %private function html:location-text($raw-location as xs:string?) as xs:string?
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
                  else if (starts-with($raw-location, "<zorba>"))
                       then replace($raw-location, "<zorba>/(.*)\\.module(:.*)", "<Z>/$1$2") 
                       else "<?>" || $raw-location
    else ()
};

declare %private function html:location($raw-location as xs:string) as element()
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

declare %private function html:stack-trace($ancestors as object()*, $location as xs:string?) as element()
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

declare %private function html:cache() as element()*
{
    <h3>Cache contents</h3>,
    if (count(collection("cache")) eq 0)
    then <b>Cache is empty.</b>
    else
        <ul>
        {
            for $cached-item in collection("cache")
            let $profile-url := $cached-item."_id"
            let $profile-date := $cached-item."date"
            return
            (
                <li><a href="#" onclick="loadExample('{$profile-url}', '');">{$profile-url}</a>, cached at {$profile-date}, <a href="/v1/_queries/public/delete.jq?_method=POST&amp;profile-url={encode-for-uri($profile-url)}">Delete</a></li>
            )
        }
        </ul>
};