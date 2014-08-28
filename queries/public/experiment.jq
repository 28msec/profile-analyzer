import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";
import module namespace resp = "http://www.28msec.com/modules/http-response";

declare variable $project-token as xs:string? external := ();
declare variable $query as xs:string? external := ();
declare variable $force-profile as xs:boolean external := false;

            let $request :=
            {
                "method": "GET",
                "href": "https://profile-analyzer.s3.amazonaws.com/source.profile"
            }
            let $response := http:send-request($request)
            return
            {
                if ($response.status eq 200)
                then
                {
                    variable $profile := parse-json($response.body.content);
                    profiles:clean-profile($profile);
                    $profile
                }
                else 
                {
                    resp:content-type("application/json");
                    {
                        "request": $request,
                        "response": $response
                    }
                }
            }
 