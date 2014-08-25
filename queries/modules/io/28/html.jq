jsoniq version "1.0";
module namespace html = "http://28.io/html";
import module namespace jn = "http://jsoniq.org/function-library";

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
  </head>
};

declare function html:body($json-profile as object()) as element()
{
    <body>
    {
        html:function-statistics($json-profile)
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
            for $function in jn:descendant-objects($json-profile)
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
                    <td>{$function("location")}</td>
                </tr>
        }
        </tbody>
    </table>,
    <script lang="text/javascript">
        $(document).ready(function() 
        {{ 
            $("#functions").tablesorter({{ sortList: [[3,0]] }}); 
        }}); 
    </script>
};


