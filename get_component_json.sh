#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# @author jstutte@mozilla.com
#
# TO BE CALLED FROM query.sh ONLY
#
# Call parameters:
component=$1
apikey=$2
phabkey=$3
bug_fields=$4
his_fields=$5
com_fields=$6
atm_fields=$7
months_back=$8

# get rid of %XX in component name
component_pretty=`echo $component | sed 's/%[0-9]./-/g'`
component_pretty=`echo $component_pretty | sed 's/--/-/g'`

json_ids=${component_pretty}_ids.json
file_ids=${component_pretty}_ids.txt
json_comp=${component_pretty}.json
json_history=${component_pretty}_his.json
json_comments=${component_pretty}_com.json
json_attachments=${component_pretty}_atm.json
json_mixed=${component_pretty}_mix.json
json_tmp=${component_pretty}_tmp.json

# fetch the ids of the bugs we want to read
# first all open ones
curl -s -o $json_ids 'https://bugzilla.mozilla.org/rest/bug?component='$component'&bug_status=UNCONFIRMED&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&include_fields=id&api_key='$apikey
sed 's/,/\n/g' < $json_ids | sed 's/{"id"://g' | sed 's/}//g' | sed 's/]//g' | sed 's/{"bugs":\[//g' > $file_ids
# last line misses newline
echo '' >> $file_ids
num_open=`wc -l < $file_ids`

# the closed ones with recent activity ($months_back)
curl -s -o $json_ids 'https://bugzilla.mozilla.org/rest/bug?component='$component'&bug_status=RESOLVED&chfield=anything&chfieldfrom='$months_back'&include_fields=id&api_key='$apikey
sed 's/,/\n/g' < $json_ids | sed 's/{"id"://g' | sed 's/}//g' | sed 's/]//g' | sed 's/{"bugs":\[//g' >> $file_ids

num_all=`wc -l < $file_ids`
if [[ $num_open -lt $num_all ]]; then
  # last line misses newline
  echo '' >> $file_ids
fi

# loop over the ids and start to write the output json
echo '{"'$component_pretty'":[' > $json_comp
echo '{"'$component_pretty'_his":[' > $json_history
echo '{"'$component_pretty'_com":[' > $json_comments
echo '{"'$component_pretty'_atm":[' > $json_attachments
echo '{"'$component_pretty'_mix":[' > $json_mixed
needcomma='false'
while read raw_id; do
  id=${raw_id//[$'\t\r\n']}

  echo $id' - '$component_pretty
  if [ $needcomma == 'true' ]; then
    echo ',' >> $json_comp;
    echo ',' >> $json_history;
    echo ',' >> $json_comments;
    echo ',' >> $json_attachments;
    echo ',' >> $json_mixed;
  fi

  # fetch the bug's details and strip the clutter around it
  echo '{"id":'$id',"bug":[' >> $json_comp
  echo '{"id":'$id',"bug":[' >> $json_mixed
  curl -s -o $json_tmp 'https://bugzilla.mozilla.org/rest/bug/'${id}'?api_key='$apikey'&include_fields='$bug_fields
  jq '.bugs[0]' $json_tmp >> $json_comp
  echo ']}' >> $json_comp
  jq '.bugs[0]' $json_tmp >> $json_mixed
  echo '],' >> $json_mixed

  # fetch the bug's comments and strip the clutter around it
  echo '{"id":'$id',"history":' >> $json_history
  echo '"history":' >> $json_mixed
  curl -s -o $json_tmp 'https://bugzilla.mozilla.org/rest/bug/'${id}'/history?api_key='$apikey'&include_fields='$his_fields
  jq '.bugs[].history' $json_tmp >> $json_history
  echo "}" >> $json_history
  jq '.bugs[].history' $json_tmp >> $json_mixed
  echo "," >> $json_mixed

  # fetch the bug's history and strip the clutter around it
  echo '{"id":'$id',"comments":' >> $json_comments
  echo '"comments":' >> $json_mixed
  curl -s -o $json_tmp 'https://bugzilla.mozilla.org/rest/bug/'${id}'/comment?api_key='$apikey'&include_fields='$com_fields
  jq '.bugs[].comments' $json_tmp >> $json_comments
  echo "}" >> $json_comments
  jq '.bugs[].comments' $json_tmp >> $json_mixed
  echo "," >> $json_mixed

  # fetch the bug's attachments and strip the clutter around it
  echo '{"id":'$id',"attachments":' >> $json_attachments
  echo '"attachments":' >> $json_mixed
  curl -s -o $json_tmp 'https://bugzilla.mozilla.org/rest/bug/'${id}'/attachment?api_key='$apikey'&include_fields='$atm_fields
  jq '.bugs[]' $json_tmp >> $json_attachments
  echo "}" >> $json_attachments
  jq '.bugs[]' $json_tmp >> $json_mixed
  echo "," >> $json_mixed

  # extract phabricator IDs from the attachment response and get patch information
  phabids=$(jq -r '.[] | .[] | .[] | select(.content_type=="text/x-phabricator-request") | .file_name | scan("D[0-9]+") | scan("[0-9]+")' $json_tmp)
  echo '"patches":[' >> $json_mixed
  patch_needcomma='false'
  for patch in $phabids
  do
    curl -s -o $json_tmp https://phabricator.services.mozilla.com/api/differential.revision.search -d api.token=$phabkey -d constraints[ids][0]=$patch
#   We might not have the right to read this patch even if we see it in bugzilla!
    patch_test=$(jq '.result.data[] | length' $json_tmp)
    if [ -n "$patch_test" ]; then
      if [ $patch_needcomma == 'true' ]; then
        echo ',' >> $json_mixed;
      fi

      patch_info=$(jq '.result.data[]' $json_tmp)
      echo $patch_info >> $json_mixed

      patch_needcomma='true'
    fi

    patch_needcomma='true'
  done
  echo "]}" >> $json_mixed

  needcomma='true'
done < $file_ids
echo "]}" >> $json_comp
echo "]}" >> $json_history
echo "]}" >> $json_comments
echo "]}" >> $json_attachments
echo "]}" >> $json_mixed

# cleanup
rm $json_tmp
rm $json_ids
