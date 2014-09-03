import module namespace resp = "http://www.28msec.com/modules/http-response";

declare variable $profile-url as xs:string external;

let $json-profile := collection("cache")[$$."_id" eq $profile-url]
return
{
    if (exists($json-profile))
    then 
    {
        resp:content-type("application/json");
        $json-profile
    }
    else
    {
        resp:status(404);
        ()
    }
}