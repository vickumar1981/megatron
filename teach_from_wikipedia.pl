#!/usr/bin/perl

use strict;
use warnings;
use AI::MegaHAL; 
use WWW::Wikipedia;

my $megahal = AI::MegaHAL->new('Path' => 'ai', 'Banner' => 0, 'Prompt' => 0, 'Wrap' => 0, 'AutoSave' => 1);
my $dummyVar = $megahal->initial_greeting();
my $wiki = WWW::Wikipedia->new();

my $totalLinesToLearn = 100;
my $linesLearned = 0;
my $numFailures = 0;

if ($#ARGV == 0) {
	$totalLinesToLearn = $ARGV[0];	
}

while (($linesLearned <= $totalLinesToLearn) && ($numFailures <= 3)){
	my $result = $wiki->random();
	if (defined ($result) == 1) {
		if ($result->text()) { 
			my $wikiResult = $result->text();
			if ($wikiResult =~ /\}\}/) {
				my @wikiArray = split (/\}\}/, $wikiResult);
				$wikiResult = $wikiArray[1];
			}
			$wikiResult =~ s/\<ref\>.*\<\/ref\>//gi;
			my @wikiList = split (/\./, $wikiResult);
			for (my $i = 0; $i < $#wikiList;  $i++) {
				my $wikiLine = $wikiList[$i];
				$wikiLine =~ s/\]//g;
				$wikiLine =~ s/^\s+//;
				$wikiLine =~ s/\s+$//;		
				if (($wikiLine !~ /\</) && ($wikiLine !~ /\|/)) {
					$megahal->learn($wikiLine.".");
					$linesLearned++;
					print "Learned...($linesLearned of $totalLinesToLearn)\n";
					$numFailures = 0;
				}
			}			
		}
	}
	else {
		$numFailures++;
	}
}




