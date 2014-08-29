import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";

declare variable $profile-url as xs:string external := "";
declare variable $project-token as xs:string external := "";
declare variable $only-preprocessing as xs:boolean external := false;
declare variable $force-preprocessing as xs:boolean external := false;
declare variable $no-full-iterator-tree as xs:boolean external := false;
declare variable $iterator-threshold as xs:integer external := 0;

declare %an:sequential function local:get-profile($profile as string, $token as string?) as object()
{
    let $json-profile := collection("cache")[$$."_id" eq $profile]
    return
    {
        if (exists($json-profile))
        then $json-profile
        else
        {
            let $request :=
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
                    "X-28msec-Iterator-Threshold": $iterator-threshold
                }
            }
            let $response := http:send-request($request)
            return
            {
                if ($response.status eq 200)
                then
                {
                    let $json-profile := parse-json($response.body.content)
                    let $clean-profile := profiles:clean-profile($json-profile)
                    let $cached-profile := 
                    {| 
                        {
                            "_id": $profile, 
                            "date": current-dateTime()
                        },  
                        $clean-profile
                    |}
                    return
                    {
                        insert("cache", $cached-profile);
                        $cached-profile
                    }
                }
                else
                {
                    let $error :=
                    {
                        "request": $request,
                        "response": $response
                    }
                    return error(xs:QName("local:GET-PROFILE"), "Cannot retrieve the profile data",  $error)
                }
            }
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
        else html:profile-page($json-profile, $no-full-iterator-tree)
    }
}
catch *
{
    html:error-page($err:code, $err:description, $err:value)
}
