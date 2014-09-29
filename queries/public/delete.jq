import module namespace resp = "http://www.28msec.com/modules/http-response";

declare variable $profile-url as xs:string external;

delete(collection("cache")[$$."_id" eq $profile-url]);
resp:status-code(301);
resp:header("Location", "/index.jq");