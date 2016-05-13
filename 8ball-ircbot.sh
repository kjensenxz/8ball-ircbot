#!/usr/bin/env bash
# Copyright 2016 prussian <generalunrest@airmail.cc>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 8ball bot using sic and a shell script
# RUNNING:
# 	./8ball-ircbot.sh & disown

if [ ! -f "./config.sh" ]; then
	echo "config file not found"
	exit
fi
. config.sh
mkfifo $infile
mkfifo $outfile

function quit_prg {
	pkill -P $$
	rm $infile $outfile
	exit
}

# for msg processing
# decide either this or that
regexp="${nickname}.? (.*) or (.*)\?"
# standard 8ball output
regexp2="${nickname}.? (.*)\?"
# $1 is chan
# $2 is the user's nick
# $3 is the msg
function process_msg {

	if [[ "$2" == "<$nickname>" ]]; then
		return
	fi

	if [[ "$3" =~ $regexp ]]; then
		resp=${BASH_REMATCH[($RANDOM % 2)+1]}
		echo ":m $1 $2 $resp" > $infile
	elif [[ "$3" =~ $regexp2 ]]; then
		shuf $t8ball |\
			head -n1 |\
			sed 's|^|:m '$1' '$2' |' > $infile
	fi
}

# when terminate, clean up
trap 'quit_prg' SIGINT SIGHUP SIGTERM

# need sic
if [ -z "$(which sic)" ]; then
	echo "sic (simple irc client) required"
	quit_prg
fi

# need shuf 
# NOT ON OS X last I used it
if [ -z "$(which shuf)" ]; then
	echo "your coreutils are limited -_-"
	quit_prg
fi

# connect to server
# tail -f can be slow
# may be a boon to prevent flooding
tail -f $infile | sic -h "$server" -n "$nickname" -p "$port" >> $outfile &

# wait for connect
sleep 10s
for channel in ${channels[@]}; do
	echo ":j $channel" > $infile
	# joining next chan too fast doesn't work
	sleep 2s
done

while read -r chan char date time nick cmd; do
	case $cmd in
		!bots|.bots)
			echo ":m $chan 8ball-bot [bash], .help for usage, .source for source code" > $infile
		;;
		!source|.source)
			echo ":m $chan https://github.com/GeneralUnRest/8ball-ircbot" > $infile
		;;
		!help|.help)
			echo ":m $chan Highlight me and ask a yes or no question or give me two prepositions separated by an or; all queries must end with a question mark." > $infile
		;;
		*${nickname}*)
			process_msg "$chan" "$nick" "$cmd"
		;;
	esac
	if [ -n "$logfile" ]; then
		echo "$chan $char $date $time $nick $cmd" >> $logfile
	fi
done < $outfile
