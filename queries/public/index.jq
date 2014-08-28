import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";
import module namespace resp = "http://www.28msec.com/modules/http-response";

declare variable $project-token as xs:string? external := ();
declare variable $query as xs:string? external := ();
declare variable $force-profile as xs:boolean external := false;

if (count(($query, $project-token)) ne 2)
then html:form-page()
else
{
  if ($force-profile) 
  then 
  {
    db:delete(collection("cache")[$$."_id" eq $query]);
  }
  else ();
  
  let $profile := collection("cache")[$$."_id" eq $query]
  return 
        if ($profile)
        then html:page($profile, $query)
        else
        {
            let $request :=
                {
                    "method": "POST",
                    "href": $query,
                    "headers" :
                    {
                        "X-28msec-Token": $project-token
                    }
                }
            let $response := http:send-request($request)
            return
            {
                if ($response.status eq 200)
                then
                {
                    variable $profile := parse-json($response.body.content);
                    profiles:clean-profile($profile);
                    insert("cache", {| {"_id": $query, "date": current-dateTime()},  $profile |});
                    html:page($profile, $query)
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
        }
}