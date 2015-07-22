import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";

declare variable $profile-url as xs:string external := "";
declare variable $project-token as xs:string external := "";

declare variable $only-preprocessing as xs:boolean external := false;
declare variable $force-preprocessing as xs:boolean external := false;

declare variable $iterator-threshold as xs:integer external := 0;
declare variable $all-exclusive-times as xs:boolean external := false;

declare variable $display-full-iterator-tree as xs:boolean external := true;
declare variable $display-iterator-threshold as xs:integer external := 25;


declare %an:sequential function local:get-profile($profile as string, $token as string?) as object()
{
    variable $json-profile := collection("cache")[$$."_id" eq $profile];
    if (exists($json-profile))
    then $json-profile
    else
    {
        variable $request :=
        {
            "method": "GET",
            "href": $profile,
            "options": 
            {
                "override-media-type": "application/json"
            },
            "headers" :
            {
                "X-28msec-Token": $token,
                "X-28msec-Iterator-Threshold": string($iterator-threshold)
            }
        };
        variable $response := http:send-request($request);
        
        if ($response.status eq 200)
        then
        {
            variable $json-profile := parse-json($response.body.content);
            variable $clean-profile := profiles:preprocess-profile($json-profile, $all-exclusive-times, $iterator-threshold);
            insert json
            {
                "_id": $profile, 
                "date": current-dateTime()
            }
            into $clean-profile;
            insert("cache", $clean-profile);
            $clean-profile
        }
        else
        {
            error(xs:QName("local:GET-PROFILE"), "Cannot retrieve the profile data",
                {
                    "request": $request,
                    "response": $response
                })
        }
    }
};

try
{
    if ($profile-url = "")
    then html:home-page()
    else
    {
        if ($force-preprocessing) 
        then db:delete(collection("cache")[$$."_id" eq $profile-url]);
        else ();
  
        variable $json-profile := local:get-profile($profile-url, $project-token);
        
        if ($only-preprocessing)
        then html:cache-updated-page($profile-url, $project-token)
        else html:profile-page($json-profile, $display-full-iterator-tree, $display-iterator-threshold)
    }
}
catch *
{
    html:error-page($err:code, $err:description, $err:value, $zerr:stack-trace, $err:module || ":" || $err:line-number || ":" || $err:column-number)
}
