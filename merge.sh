#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# @author jstutte@mozilla.com
#
# TO BE CALLED FROM query.sh ONLY
#

all_bugs=$1
all_history=$2
all_comments=$3
all_attachments=$4
all_mixed=$5
components=$6

needcomma='false'

echo '{"all_bugs":[' > $all_bugs
echo '{"all_histories":[' > $all_history
echo '{"all_comments":[' > $all_comments
echo '{"all_attachments":[' > $all_attachments
echo '{"all_bugs_complete":[' > $all_mixed
for component in $components
do
  if [ $needcomma == 'true' ]; then
    echo ',' >> $all_bugs;
    echo ',' >> $all_history;
    echo ',' >> $all_comments;
    echo ',' >> $all_attachments;
    echo ',' >> $all_mixed;
  fi

  # get rid of %XX in component name
  c=${component//[$'\t\r\n']}
  component_pretty=`echo $c | sed 's/%[0-9]./-/g'`
  component_pretty=`echo $component_pretty | sed 's/--/-/g'`
  echo 'Merging '$component_pretty

  # File names
  json_comp=${component_pretty}.json
  json_history=${component_pretty}_his.json
  json_comments=${component_pretty}_com.json
  json_attachments=${component_pretty}_atm.json
  json_mixed=${component_pretty}_mix.json

  q="[.\"${component_pretty}\"[]]"
  jq $q $json_comp | sed '1s/\[//' | sed '$s/]//' >> $all_bugs

  q="[.\"${component_pretty}_his\"[]]"
  jq $q $json_history | sed '1s/\[//' | sed '$s/]//' >> $all_history

  q="[.\"${component_pretty}_com\"[]]"
  jq $q $json_comments | sed '1s/\[//' | sed '$s/]//' >> $all_comments

  q="[.\"${component_pretty}_atm\"[]]"
  jq $q $json_attachments | sed '1s/\[//' | sed '$s/]//' >> $all_attachments

  q="[.\"${component_pretty}_mix\"[]]"
  jq $q $json_mixed | sed '1s/\[//' | sed '$s/]//' >> $all_mixed

  needcomma='true'
done <components.txt

echo ']}' >> $all_bugs
echo ']}' >> $all_history
echo ']}' >> $all_comments
echo ']}' >> $all_attachments
echo ']}' >> $all_mixed
