#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# @author jstutte@mozilla.com
#
# Read all open bugs and recently closed bugs for a set of components from bugzilla.
# Merge the result to several JSON files.
#
# Prerequisites:
# get_component.sh - create the JSONs for a single component
# merge.sh - merge all component's JSONs together
# query_parameters.json - Parameters for the bugzilla queries and output files
#
# ATTENTION: Spawns immediately as many processes as there are components to be queried.
# The JSON files will be valid only after all processes completed correctly.
#
# Example of a query_parameters.json:
# {"query":{
#     "api_key": "<Your bugzilla API key>",
#     "phab_key": "<Your phabricator API key>",
#     "all_file": "bugs_complete.json",
#     "all_bugs_file": "bugs.json",
#     "all_comments_file": "comments.json",
#     "all_history_file": "history.json",
#     "all_attachments_file": "attachments.json",
#     "months_back": "-6m",
#     "components": [
#         "DOM%3A%20File",
#         "DOM%3A%20postMessage",
#         "DOM%3A%20Push%20Notifications",
#         "DOM%3A%20Service%20Workers",
#         "DOM%3A%20Web%20Payments",
#         "DOM%3A%20Workers",
#         "Storage%3A%20Cache%20API",
#         "Storage%3A%20IndexedDB",
#         "Storage%3A%20localStorage%20%26%20sessionStorage",
#         "Storage%3A%20Quota%20Manager",
#         "Storage%3A%20StorageManager"
#         ],
#     "bug_fields": ["cf_last_resolved","summary","keywords","depends_on","regressed_by","product","comment_count","creator","is_confirmed","assigned_to",
#         "regressions","groups","votes","whiteboard","severity","is_open","dupe_of","type","duplicates","cf_fission_milestone","cf_crash_signature",
#         "version","blocks","id","priority","resolution","flags","op_sys","creation_time","classification","platform","url","cf_webcompat_priority",
#         "component","status","last_change_time","alias"],
#     "history_fields": ["when","who","changes"],
#     "comment_fields": ["text","creator","author","attachment_id","creation_time"],
#     "attachment_fields": ["content_type","flags","last_change_time","attacher","summary","file_name","id","is_obsolete","creation_time"]
# }}
#
# Please note that any missing parameter will result in errors difficult to understand!
# Currently it is not supported to not query parts of the bugs (like attachments), so please make sure at least one field per part is specified.
#



# retreive the bugzilla & phabricator API keys
apikey=$(jq -r '.query | .api_key' query_parameters.json)
apikey=${apikey//[$'\t\r\n']}
phabkey=$(jq -r '.query | .phab_key' query_parameters.json)
phabkey=${phabkey//[$'\t\r\n']}

# retreive output file names
all_file=$(jq -r '.query | .all_file' query_parameters.json)
all_file=${all_file//[$'\t\r\n']}
all_bugs_file=$(jq -r '.query | .all_bugs_file' query_parameters.json)
all_bugs_file=${all_bugs_file//[$'\t\r\n']}
all_comments_file=$(jq -r '.query | .all_comments_file' query_parameters.json)
all_comments_file=${all_comments_file//[$'\t\r\n']}
all_history_file=$(jq -r '.query | .all_history_file' query_parameters.json)
all_history_file=${all_history_file//[$'\t\r\n']}
all_attachments_file=$(jq -r '.query | .all_attachments_file' query_parameters.json)
all_attachments_file=${all_attachments_file//[$'\t\r\n']}

# retreive the time parameter for closed bugs
months_back=$(jq -r '.query | .months_back' query_parameters.json)
months_back=${months_back//[$'\t\r\n']}

# retreive the components list
components=$(jq -r '.query.components[]' query_parameters.json)

# retreive the field names lists
bug_fields=$(jq -r '.query.bug_fields[]' query_parameters.json |  paste -sd, -)
his_fields=$(jq -r '.query.history_fields[]' query_parameters.json |  paste -sd, -)
com_fields=$(jq -r '.query.comment_fields[]' query_parameters.json |  paste -sd, -)
atm_fields=$(jq -r '.query.attachment_fields[]' query_parameters.json |  paste -sd, -)

# We spawn processes that we want to interrupt if we get interrupted, too
pids=""
trap ctrl_c INT

function ctrl_c() {
  kill $pids
  wait $pids
  echo "The so-far written .json files are most likely corrupt."
  exit 0
}

# Now let's do the real work
for component in $components
do
  c=${component//[$'\t\r\n']}
  echo $c
  ./get_component_json.sh $c $apikey $phabkey $bug_fields $his_fields $com_fields $atm_fields $months_back &
  pids="$pids $!"
done

wait $pids

./merge.sh $all_bugs_file $all_comments_file $all_history_file $all_attachments_file $all_file "$components"