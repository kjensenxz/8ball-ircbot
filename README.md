8ball irc bot

8ball bot using sic and a shell script
# RUNNING:
	
	./8ball-ircbot.sh & disown

# SETTINGS:

Edit the script

	# SETTINGS
	
	# IRC
	server="irc.rizon.net"
	nickname="the8ball"
	# space sep list of chans
	channels=('#chan1' '#chan2')

	# 8ball responses file
	t8ball="8ball-resp.txt"

	# input/output files
	infile="/tmp/in-8ballbot"
	outfile="/tmp/out-8ballbot"
