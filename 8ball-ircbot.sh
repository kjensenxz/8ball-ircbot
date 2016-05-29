#!/usr/bin/env bash
# Copyright 2016 prussian <generalunrest@airmail.cc>, Kenneth B. Jensen <kenneth@jensen.cf>
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
	echo "error: config file not found; exiting"
	exit
fi

. ./config.sh

mkfifo "$infile" "$outfile"
exec 3<> "$infile"
exec 4<> "$outfile"

function exit_prg {
	pkill -P $$
	rm "$infile" "$outfile"
	exec 3>&-
	exec 4>&-
	exit
}

function queue_msg {
	echo "$*"
	echo -e "$*\r\n" >&3
}

function join_chan {
	queue_msg "JOIN $1"
}

function send_msg {
	queue_msg "PRIVMSG $1 :$2"
}

function get_8ball {
	shuf "$ballmsgs" | head -n 1
}

function parse_msg {
	echo "1: $1"
	echo "2: $2"
	user=''
	dest=''
	sourcemsg=''
	if [[ $2 =~ "PRIVMSG" ]]; then
		user=`echo ${1} | sed 's/[:!]/ /g' | awk '{print $1}'`
		if [[ $2 =~ "#" ]]; then
			dest=`echo ${2} | awk '{print $2}'`
		else
			dest=${user}
		fi
		sourcemsg=`echo ${2} | sed 's/[^:]*://'`
		echo "$user $dest $sourcemsg"
	elif [ "$1" == "PING" ]; then
		reply=`echo $2 | sed 's/://g'`
		echo "reply: $reply"
		queue_msg "PONG $reply"
		return
	fi
	# stolen regexes
	# credit goes to @GeneralUnRest
	regexp="${nickname}.? (.*) or (.*)\?"
	regexp2="${nickname}.? (.*)\?"
	regexp3="(.*) or (.*)\?"
	regexp4="(.*)\?"
	invite_regexp="invite (.*)"
	[[ $user == ${nickname} ]] && return
	private=$([[ (! -z $user ) &&  ($user == $dest) ]] && echo "yes")
	if [[ ($sourcemsg =~ $regexp) || ($private && $sourcemsg =~ $regexp3) ]]; then
		send_msg "$dest" "${BASH_REMATCH[($RANDOM % 2)+1]}"
	elif [[ $sourcemsg =~ $regexp2 || ($private && $sourcemsg =~ $regexp4) ]]; then
		send_msg "$dest" "$(get_8ball)"
	elif [[ $sourcemsg =~ ".source" || ($private && $sourcemsg =~ "source") ]]; then
		send_msg "$dest" "https://github.com/kjensenxz/irc8ball"
	elif [[ $private && ($sourcemsg =~ $invite_regexp) ]]; then
		send_msg "$dest" "Attempting to join ${BASH_REMATCH[1]}";
		join_chan "${BASH_REMATCH[1]}"
	elif [[ $private ]]; then
		send_msg "$dest" "These are the command/s supported:"
		send_msg "$dest" "invite #channel - join channel"
		send_msg "$dest" "8ball [y/n question] - standard 8ball response"
		send_msg "$dest" "x or y? - choose x or y"
		send_msg "$dest" "source - get source info"
		send_msg "$dest" "help - this message"
	fi
}

trap 'exit_prg' SIGINT SIGHUP SIGTERM

commands="${network} ${port}"
if [[ $ssl == 'yes' ]]; then 
	commands="--ssl ${commands}"
fi
ncat $commands <&3 >&4 &
unset commands

(sleep 3s && echo "connect" >&4) &
join="yes"
while read -r usr msg; do
	echo "$usr $msg"
	if [[ "$usr" == "connect" || "$msg" =~ "^004" ]]; then
		for i in $channels; do
			queue_msg "JOIN ${i}"
		done
		break
	elif [[ "$msg" =~ "NOTICE" && $join == "yes" ]]; then
		queue_msg "NICK ${nickname}"
		queue_msg "USER ${nickname} 8 * :${nickname}"
		join='no'
	elif [ "$usr" == "PING" ]; then
		echo "PING RECIEVED"
		reply=$(echo "$msg" | sed 's/://g')
		queue_msg "PONG :$reply"
		echo "connect" >&4
	fi
done <&4
unset join

while read -r usr msg; do
	parse_msg "$usr" "$msg"
done <&4
