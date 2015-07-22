import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";
import module namespace request = "http://www.28msec.com/modules/http-request";

declare variable $profile-url as xs:string external := "";
declare variable $project-token as xs:string external := "";
declare variable $force-preprocessing as xs:boolean := true;
declare variable $iterator-threshold as xs:integer external := 0;
declare variable $all-exclusive-times as xs:boolean external := false;

declare %an:sequential function local:preprocess($profile as string, $token as string?) as empty-sequence()
{
    if (exists(collection("cache")[$$."_id" eq $profile]))
    then trace("Profile already exists", "status");
    else
    {
        trace("Retrieving profile from " || $profile-url,  "status");
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
            trace("Parsing profile", "status");
            variable $json-profile := parse-json($response.body.content);
            trace("Preprocessing profile", "status");
            variable $clean-profile := profiles:preprocess-profile($json-profile, $all-exclusive-times, $iterator-threshold);
            trace("Adding profile metadata", "status");
            insert json
            {
                "_id": $profile, 
                "date": current-dateTime()
            }
            into $clean-profile;
            trace("Storing preprocessed profile", "status");
            insert("cache", $clean-profile);
            trace("Preprocessed profile stored", "status");
        }
        else
        {
            let $error :=
            {
                "request": $request,
                "response": $response
            }
            return error(xs:QName("local:GET-PROFILE"), "Cannot retrieve the profile data",  $error);
        }
    }
};

$profile-url := request:param-values("profile-url");
$project-token := request:param-values("project-token");

trace("Preprocessing of " || $profile-url || " started...", "status");

try
{
    if ($force-preprocessing) 
    then
    {
        trace("Dropping existing profile, if any...", "status");
        db:delete(collection("cache")[$$."_id" eq $profile-url]);
    }
    else ();
  
    local:preprocess($profile-url, $project-token);
}
catch *
{
    trace("error", $err:code); 
}
(:html:error-page($err:code, $err:description, $err:value, $zerr:stack-trace, $err:module || ":" || $err:line-number || ":" || $err:column-number);:)