#!/bin/bash
#
# Prerequisite:
# curl, jq
# review_parameters.json file containing:
#
# {
# "reviews":{
#     "api_key": "<Your bugzilla API key here>",
#     "phab_key": "<Your phabricator API key here>",
#     "reviewers": [
#         "PHID-PROJ-g23aqzxcq3aponki64vs"
#         ],
#     "bug_fields": [
#         "id",
#         "priority",
#         "resolution",
#         "component",
#         "status",
#         "alias"
#         ]
#     }
# }
#
# Note: The "PHID-PROJ-g23aqzxcq3aponki64vs" refers to our dom-workers-and-storage-reviewers group. It can be obtained by:
# curl https://phabricator.services.mozilla.com/api/project.search -d api.token=phab_key -d constraints[ids][0]=115
# (115 is the URL parameter visible in phabricator as project)
#
# TODO: Find an easy way to query people's PHIDs. If you know you are the author of a specific patch that is under review, you
# can find it in pending_reviews.json under author ;-)
#

# retreive the bugzilla & phabricator API keys
apikey=$(jq -r '.reviews | .api_key' review_parameters.json)
apikey=${apikey//[$'\t\r\n']}
phabkey=$(jq -r '.reviews | .phab_key' review_parameters.json)
phabkey=${phabkey//[$'\t\r\n']}
reviews_file='pending_reviews.json'
bug_fields=$(jq -r '.reviews.bug_fields[]' review_parameters.json |  paste -sd, -)

# read reviewers
reviewers=$(jq -r '.reviews.reviewers[]' review_parameters.json)
reviewers_constraints=""
x=0
for r in $reviewers
do
    reviewers_constraints+="-d constraints[reviewerPHIDs][$x]=$r "
    x=$(( x++ ));
done

# get pending reviews
curl -s -o $reviews_file https://phabricator.services.mozilla.com/api/differential.revision.search \
    -d api.token=$phabkey \
    $reviewers_constraints \
    -d constraints[statuses][0]=needs-review

# extract bug ids from reviews and walk them
bug_ids=$(jq -r '.result.data[].fields["bugzilla.bug-id"]' $reviews_file | sort -u)
for b in $bug_ids
do
    # get bug and read priority, component
    curl -s -o $b.json 'https://bugzilla.mozilla.org/rest/bug/'${b}'?api_key='$apikey'&include_fields='$bug_fields
    priority=$(jq -r '.bugs[].priority' $b.json)
    component=$(jq -r '.bugs[].component' $b.json)

    # fetch bug relative reviews from existing json and print them out with additional info
    bug_review_ids=$(jq -r '.result.data[] | select(.fields | .["bugzilla.bug-id"]=="'${b}'") | .id' $reviews_file)
    for rid in $bug_review_ids
    do
        echo 'https://phabricator.services.mozilla.com/D'$rid', bug priority: '$priority', '$component': bug https://bugzilla.mozilla.org/show_bug.cgi?id='$b
    done

    # cleanup
    rm $b.json
done

