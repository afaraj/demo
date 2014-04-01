#!/usr/bin/perl -w
use strict;
use DB_File;
use DBI;
use DBD::CSV;
use IO::Socket;
use Getopt::Long;


#Ignore all dead children
$SIG{CHLD}= 'IGNORE';

#Set up options
# 	Create default values if necessary
my $portt;
GetOptions(
	"p|port=i" => \$portt,
);
my $portnumber = $portt || 8999;

# Create the handle for the server
#		
my $handle = IO::Socket::INET->new(
	Type => SOCK_STREAM,
	Proto => 'tcp',
	LocalPort => $portnumber,
	Reuse => 1,
	Listen => 20,
	) or die "Can't create connection on $portnumber : $!\n";
print "<$$>: Server Created.\n";
print "<$$>: Now Listening at port $portnumber\n"; 
# Main loop for the server
# Going to listen for requests and fork off each game
#

while(my $client = $handle->accept() ){
	die "Can't fork $!\n" unless (defined (my $child_pid = fork() ));
# Parent Process
# Do nothing and go back to the start of the while loop
	if ($child_pid){
		print "<$$>: Successfully Forked\n";
		next;
	} else {
################# BEGIN CHILD PROCESS ###############
# Child process:	
#	1) Let client know if connection was successful
#	2) Loop through game until the game is over or
#	3)  
		my $count = 0;
		my $times = 8;
		my $clientname = ReadFromClient(\$client);
# Setup the Board
		my %choice_hash;
		foreach (1..9) { $choice_hash{$_} = $_; }
# Tell client we created the game successfully
		print $client "new:success\n";

#Loop game 
#
my $choice;

		while($choice = ReadFromClient(\$client) ) {
			$count++;
			#Client choses to quit
			if($choice =~ /^[q|x|Q|X]$/){
				last;
			} elsif ( $choice =~ /^[1-9]$/){
			#Client makes a move
				if ( my $response = UpdateBoard(\%choice_hash, $choice, $count) ){
						if ($response eq 'T') {
							#$times = UpdateDB($clientname);
							print $client "game:tie\n";
							last;
						} elsif ($response eq 'X') {
		#Client Won Check how many wins this is for them			
							my $times = UpdateDB($clientname);
							print $client "game:win$times\n";
							last;
						} elsif ($response =~ /^O\d$/){
		#Server Won Check how many 
							$times =  chop $response;
							print $client "game:lose$times\n";
							last;
						} elsif ($response >= 1 && $response <=9){
							print $client "counter:$response\n";

						}

					} else { #Captures the invalid input from the user as
							#UpdateBoard returns 0 if bad data crept in
						print $client "invalid:invalid\n";
					}

			} elsif ($choice == -1){
			# Function returned -1 && client was already notified
			next;

			} else {
			# Capture any other instance where the response is not supported
			# and send a message to the client telling them so.
				print $client "invalid:invalid\n";
			}

		}
		exit;
	}

}


sub ReadFromClient{
# Read Client Response
	my $cli = shift;
	my $client = $$cli;
	my ($option, $answer);
	chomp(my $response = <$client>);
	$response =~ s/\r|\n//gi;
# Check if response has the general valid format return -1 if not
# and let the client know by sending "invalid:invalid\n"
	if( $response =~ /^(new|choice):\w+$/){
		($option, $answer) = split(/:/, $response);
	} else {
		print $client "invalid:invalid\n";
		return -1;
	}
# return the client's answer
	if($option eq "new" ){
		return $answer;
	}elsif ($option eq "choice" && $answer =~ /^\w$/gi){
		return $answer;
	}else{
		print $client "invalid:invalid\n";
		return -1;
		}

}

sub UpdateBoard {
my ($choice_hash, $option, $count) = @_;

# Return true if it's a valid input
if ($choice_hash->{$option} =~ /^\d$/){
	$choice_hash->{$option} = 'X';
	if (my $winner = thereIsWinner($choice_hash) ){
		return $winner;
	}
} else {
# Return false if not
	return 0;
}

#Opening Move
if($option == 5 && $count < 2){
	$choice_hash->{1} = 'O';
	return 1;
} elsif ($count <2) {
	$choice_hash->{5} = 'O';
	return 5;
} else{
# Other Moves
	my $response = Catenaccio($choice_hash);
	$choice_hash->{$response} = 'O';
	if(my $returning = thereIsWinner($choice_hash) ){
		if ($returning eq 'O'){
			return $returning.$response;
		}else{
			return $returning;
		}
	}else {
		return $response;		
	}
}

}


#Copying the contents of the hash into the subroutine so we can mess around with it
sub Catenaccio {
	my ($choice_hash) = @_;
	my %choice_hash = %$choice_hash;
	my $number = 1;
	my %winning;
	while ($number <= 9){
		$number = int(rand(9))+1;
		if ($choice_hash{$number} ne 'X' && $choice_hash{$number} ne 'O' ){
			return $number;
		}  

	}
}

#Check if there is a winner
sub thereIsWinner{
	my $choice_hash = shift;
# All the permutations of a winning game
my @permutes = ([1,2,3],[1,4,7],[1,5,9],[2,5,8],[3,6,9],[4,5,6],[7,8,9],[3,5,7]);
my $count=0;
foreach my $aryref (@permutes){	
	(my $one, my $two, my $three) = @$aryref;
#If there are three in a row with the same value then return the winning name
	if( $choice_hash->{$one} eq $choice_hash->{$two} && $choice_hash->{$two} eq $choice_hash->{$three} ) {
		return $choice_hash->{$one};
	}
}
$count = 0;
foreach my $temp (sort keys %$choice_hash){
	$count++ if ($choice_hash->{$temp} eq 'O' || $choice_hash->{$temp} eq 'X');
}
return 'T' if ($count > 8);
return 0;
}

#Should have created another subroutine to write and read to file
sub UpdateDB {
my $clientname = shift;
my $filedb = "final.db";
my %dbhash;
tie(%dbhash, "DB_File", $filedb) or die "Can't open $filedb as DB_File: $! !\n";

my $dsn = 'dbi:CSV:';
my $dbh = DBI->connect($dsn) or die "DB error $DBI::errstr \n";

#Create table
my $tablename = 'tic_tac_toe.csv';
unlink $tablename if -e $tablename;
my $create_str = "CREATE TABLE $tablename";
$create_str .= "(username char(255), wins char(10) )";
my $sth = $dbh->prepare($create_str);
unless($sth->execute ) { 
	print "Couldn't create: $sth->errstr \n";
}
if (defined $dbhash{$clientname} ){
	$dbhash{$clientname}++;
} else {
	$dbhash{$clientname} = 1;
}
my $statement = "INSERT INTO $tablename(username, wins)  VALUES( '$clientname', '$dbhash{$clientname}' ) ";
$sth = $dbh->prepare($statement);
unless($sth->execute){
	print "Error: $sth->errstr \n";
}
my $returnvalue = $dbhash{$clientname};
untie(%dbhash);
return $returnvalue;
}
