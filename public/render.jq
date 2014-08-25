import module namespace http = "http://zorba.io/modules/http-client";
import module namespace profiles = "http://28.io/profiles";
import module namespace html = "http://28.io/html";
import module namespace resp = "http://www.28msec.com/modules/http-response";

(:
declare variable $project as xs:string external;
declare variable $project-token as xs:string external;
declare variable $query as xs:string external;

variable $url := "http://" || $project || 
  (
    if (starts-with($query,"/"))
    then ""
    else "/"
  ) || 
  $query || "/metadata/profile?token=" || $project-token;
:)
variable $url := "http://secxbrl-federico.xbrl.io/v1/_queries/public/api/report-elements.jq/metadata/profile?_method=POST&ticker=intc&_token=a2FZRFpCQzljMCtyUVFTM3ZaTkdmVlM5d2ZJPToyMDE0LTA4LTI2VDA0OjEzOjU4LjQ0MTkxOVo=";

variable $json-profile := parse-json(http:get($url)("body")("content"));

profiles:clean-profile($json-profile);
(:profiles:render-json-profile($json-profile):)
resp:content-type("text/html");
html:page($json-profile)
