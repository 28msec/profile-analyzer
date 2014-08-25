import module namespace http = "http://zorba.io/modules/http-client";
import module namespace m = "http://28.io/profiles";

variable $json-profile := parse-json(http:get("http://profile-data.xbrl.io/facttable-for-report-2.jq")("body")("content"));
m:clean-profile($json-profile);
m:render-json-profile($json-profile)
