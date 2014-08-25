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
    -->
</style>
  </head>
};

declare function html:body($json-profile as object()) as element()
{
    <body>
    {
        html:function-statistics($json-profile),
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
                <th>CPU Time (ms)</th>
                <th>Wall Time (ms)</th>
                <th>Invocations</th>
                <th>Next Calls</th>
                <th>Cache Hits</th>
                <th>Cache Misses</th>
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
                    <td>{replace($function("location"), "file:///opt/sausalito/3.7.0/opt/Sausalito-App-Server-Mongo-3.7.0/share/zorba/uris", "<zorba>")}</td>
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

declare function html:mongo-statistics($json-profile as object()) as element()*
{
    <h3>MongoDB operations</h3>,
    <table cellspacing="1" id="mongodb" class="tablesorter">             
        <thead>
            <tr> 
                <th>Name</th> 
                <th>CPU Time (ms)</th>
                <th>Wall Time (ms)</th>
                <th>Invocations</th>
                <th>Next Calls</th>
                <th>Location</th>
                <th>Collection</th>
                <th>Query</th>
                <th>Plan</th>
            </tr> 
        </thead>
        <tbody>
        {
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
                    <td>{replace($function("location"), "file:///opt/sausalito/3.7.0/opt/Sausalito-App-Server-Mongo-3.7.0/share/zorba/uris", "<zorba>")}</td>
                    <td>{html:serialize-incell(members($function("prof-queries")), "prof-collection")}</td>
                    <td>{html:serialize-incell(members($function("prof-queries")), "prof-query")}</td>
                    <td>{html:serialize-incell(members($function("prof-queries")), "prof-plan")}</td>
                </tr>
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
