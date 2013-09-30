#!/usr/bin/perl

use warnings;
use strict;


my $a = "32332";
my $c = "23";
my @b = (1,2,3,4,5);
my $d = "New Line";
my $ll = "Some words of text that we shall manipulate";

print "$a"." "."\uteams in the \UNFL\n";
print "$b[2] \n";


my @onetoten = (1 .. 10);
my $toplimit = 25;
for my $i (@onetoten, 15, 20 .. $toplimit) {
	print "$i\n";
	}

exit;