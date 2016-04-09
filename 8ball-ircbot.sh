#!/bin/bash
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

# when terminate, clean up
trap 'pkill -P $$; rm $infile $outfile; exit' SIGINT SIGHUP SIGTERM

if [ ! -f "./config.sh" ]; then
	echo "config file not found"
	exit
fi
. config.sh
touch $infile
touch $outfile

# need sic
if [ "$(which sic)" == "" ]; then
	echo "sic (simple irc client) required"
    exit
fi

# need shuf 
# NOT ON OS X last I used it
if [ "$(which shuf)" == "" ]; then
	echo "your coreutils are limited -_-"
	exit
fi

# connect to server
tail -f $infile | sic -h "$server" -n "$nickname" >> $outfile &

# wait for connect
sleep 10s
for channel in ${channels[@]}; do
	echo ":j $channel" >> $infile
	# joining next chan too fast doesn't work
	sleep 2s
done

tail -f -n 0 $outfile | \
	while read -r chan char date time nick cmd; do
		case $cmd in
			!bots|.bots)
				echo ":m $chan 8ball-bot [bash]" >> $infile
			;;
			*${nickname}*)
				shuf $t8ball |\
					head -n1 |\
					sed 's|^|:m '$chan' '$nick' |' >> $infile
			;;
		esac
	done
