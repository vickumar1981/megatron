#!/usr/bin/perl

require LWP::UserAgent;
use strict;
use warnings;
use threads;

use Thread::Queue;
use Chatbot::Eliza;
use LWP::Simple;
use AI::MegaHAL;
use WWW::WolframAlpha;

use X11::GUITest qw/
    SendKeys
  /;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my $computerName = "megatron";
my $soundDevice = "alsa";
my $soundInput = "default";
my $halAutoSave = 1;
my $audioConfidence = 0.75;
my $speakCmd = "espeak -s 140";
my $url = "https://www.google.com/speech-api/v1/recognize?xjerr=1&client=chromium&lang=en-US";
my $chachaurl = "http://www.chacha.com/question/";
my $wolframId = "";

my $listen : shared = 1;
my $listening : shared = 0;
my $command : shared = 0;
my $dictation : shared = 0;

my %applicationList;
my @questionPhrases = qw(what when where why how does is do);
my @greetingPhrases = ('Ahoy.', 'Good day.', 'Greetings.', 'Hello.', 'Hello there.', 'Hey.', 'Hi.', 'Hi there.', 'How are you?', 'How are you doing?', 'How is it going?');
my @goodbyePhrases = ('Goodbye.', 'Bye', 'Catch you later.', 'Later.', 'Peace.', 'Peace out', 'All the best.', 'Cheers', 'Okay then.', 'See you around.', 'I will see you later, then.');
my @confirmPhrases = ('Affirmative.', 'Yes.', 'All right.', 'Certainly.', 'Sure thing.', 'Yea.', 'Yep.', 'Very well.', 'Okay.');
my @typePhrases = ('type', 'tight', 'height');

my $configFile = `cat megatron.conf`;
my @configLines = split (/\;/, $configFile);
my $configLine = "";
foreach $configLine (@configLines) {	
	my @configKeyValPair = split(/\=/, $configLine);
	my $key = $configKeyValPair[0];
	my $val = $configKeyValPair[1];
	chomp($key);
	chomp($val);
	$key =~ s/\n//g;
	$key =~ s/\r//g;
	$val =~ s/\n//g;
	$val =~ s/\r//g;

	if ($key eq "name") {
		$computerName = $val;
	}
	elsif ($key eq "device") {
		$soundDevice = $val;
	}
	elsif ($key eq "input") {
		$soundInput = $val;
	}
	elsif ($key eq "autosave") {
		$halAutoSave = $val;
	}
	elsif ($key eq "confidence") {
		$audioConfidence = $val;
	}
	elsif ($key eq "speak") {
		$speakCmd = $val;
	}
	elsif ($key eq "wolframId") {
		$wolframId = $val;
	}
	else {
		if ($key =~ /^app_/) {
			$key = substr($key, 4);
			$applicationList{$key} = $val;
		}
	}
}

my $mybot = new Chatbot::Eliza;
my $megahal = AI::MegaHAL->new('Path' => 'ai', 'Banner' => 0, 'Prompt' => 0, 'Wrap' => 0, 'AutoSave' => $halAutoSave);
my $wolframAlpha = WWW::WolframAlpha->new (appid => $wolframId);
my $dummyVar = $megahal->initial_greeting();
my $fileList = Thread::Queue->new;
my $randomInt = 0;

print "Listening ...\n\n";
$randomInt = int(rand($#greetingPhrases)) - 1;
my $greeting = $greetingPhrases[$randomInt];
`$speakCmd \"$greeting\" 2>.errorLog`;
`rm .errorLog &`;	

my $recordThread = new threads(\&record_audio);
my $answerThread = new threads(\&process_audio);

$recordThread->join();
$answerThread->join();

$randomInt = int(rand($#goodbyePhrases)) - 1;
my $goodbye = $goodbyePhrases[$randomInt];
`$speakCmd \"$goodbye\" 2>.errorLog`;
`rm .errorLog &`;
`rm *.flac &`;

exit (1);


sub record_audio {
	while ($listen == 1) {
		my $fileName = int(rand(10000));
		`sox -q -t $soundDevice $soundInput $fileName.wav rate 16k silence 1 0.1 5% 1 1.5 5% 2>$fileName.errorOutput`;
		`sox $fileName.wav $fileName.flac gain -n -5 silence 1 5 2%`;		
		`rm $fileName.errorOutput &`;
		`rm $fileName.wav &`;
		$fileList->enqueue($fileName);
	}
}

sub process_audio {
	my $aFile = "";
	while (($aFile = $fileList->dequeue) && ($listen == 1)) { 
		my $audio = "";
		my $applicationKey = "";
		my $applicationCmd = "";

        	open(AUDIOFILE, "<".$aFile.".flac");
		while(<AUDIOFILE>) {
			$audio .= $_;
		}
		close(AUDIOFILE);
		my $ua = LWP::UserAgent->new;
		my $response = $ua->post($url, Content_Type => "audio/x-flac; rate=16000", Content => $audio);
		if ($response->is_success) {
			my $content = $response->content;
			open (TEMPFILE, ">>".$aFile.".txt");
			print TEMPFILE "$content";
			close(TEMPFILE);
		}
		my $speech = `cat $aFile.txt | sed 's/.*utterance":"//' | sed 's/","confidence.*//'`;
		my $confidence = `cat $aFile.txt | sed 's/.*confidence"://' | sed 's/\}\]\}//'`;
		`rm $aFile.txt &`;	
		`rm $aFile.flac &`;

		my $input_speech = "";
		if ($speech !~ /^{/) {			
			my $input_speech = $speech;
			chomp($input_speech);
			$input_speech =~ s/^\s+//;
			$input_speech =~ s/\s+$//;
			$input_speech = lc($input_speech);

			my $lastWord = "";
			my $allWordsTheSame = 1;
			my @wordsInText = split(/\s/, $input_speech);
			my $wordIndex = 0;
			while (($allWordsTheSame == 1) && ($wordIndex < $#wordsInText)) {
				my $currentWord = $wordsInText[$wordIndex++];
				if ($lastWord eq "") {
					$lastWord = $currentWord;
				}
				else {
					if ($currentWord ne $lastWord) {
						$allWordsTheSame = 0;
					}					
				}
			}

			if ($allWordsTheSame == 1) {
				$input_speech = "";
			}
			if ($input_speech =~ /\w+/) {
				lock ($command);
				lock ($listening);
				$listening = 1;
				$command = 0;
				
				if ($input_speech =~ /$computerName/) {
					my @speechArray = split(/$computerName/, $input_speech, 2);
					$input_speech = $speechArray[1];
					$input_speech =~ s/^\s+//;
				}
				
				if (($dictation == 1) && ($input_speech =~ /stop/) && ($input_speech =~ /dictation/)) {
					lock($dictation);
					$dictation = 0;
					$listening = 0;
					$input_speech = "";
					print "Stopping dictation mode...\n\n";
					`$speakCmd \"Stopping dictation.\" 2>.errorLog`;
					`rm .errorLog &`;
				}

				if (($input_speech =~ /start/) && ($input_speech =~ /dictation/)) {
					lock($dictation);
					$dictation = 1;
					$listening = 0;
					$input_speech = "";
					print "Starting dictation mode...\n";	
					`$speakCmd \"Starting dictation.\" 2>.errorLog`;
					`rm .errorLog &`;
				}
							
				if (($dictation == 0) && ($input_speech =~ /open/) || ($input_speech =~ /show/)) 				{
					for my $appKey (keys %applicationList) {
						if ($input_speech =~ /$appKey/) {
							$applicationKey = $appKey;
							$applicationCmd = $applicationList{$appKey};
							$command = 1;
							$listening = 0;
						}
					}
				}
								
			}

			if (($dictation == 0) && ($input_speech =~ /stop/)) {
					lock ($listen);
					lock ($listening);
					lock ($command);
					$listen = 0;
					$listening = 0;
					$command = 0;
					$input_speech = "";
					print "Exiting...(Please say 'Stop' again to exit.)\n\n";					
			}

			if ($dictation == 0) {
				foreach my $typeSpeech (@typePhrases) {
					if ($input_speech =~ /^$typeSpeech/) {
						$input_speech = substr($input_speech, length($typeSpeech) + 1);
						if ($input_speech =~ /\w+/) {
							print "Typing: $input_speech\n\n";
							SendKeys ("$input_speech");
							$input_speech = "";
						}
					}					
				}					
			}			

			if (($dictation == 1) && ($input_speech =~ /^select line/)) {
				SendKeys ('+({HOM})');
				$input_speech = "";
			}

			if (($dictation == 1) && ($input_speech =~ /^new line/)) {
				SendKeys ('~');
				$input_speech = "";
			}

			if (($dictation == 1) && ($input_speech =~ /^delete line/)) {
				SendKeys ('+({HOM}){DEL}');
				$input_speech = "";
			}

			if (($dictation == 1) && (($input_speech =~ /^delete/) || ($input_speech =~ /^undo/))) {
				SendKeys('^(+({LEF})){DEL}');
				$input_speech = "";
			}

			if (($dictation == 1) && ($input_speech =~ /^back space/)) {
				SendKeys ('{BAC}');
				$input_speech = "";
			}
			
			if ($input_speech =~ /^cut/) {
				SendKeys ('^(x)');
				$input_speech = "";
			}

			if ($input_speech =~ /^copy/) {
				SendKeys ('^(c)');
				$input_speech = "";
			}

			if ($input_speech =~ /^paste/) {
				SendKeys ('^(v)');
				$input_speech = "";
			}

			if ($input_speech =~ /^tab/) {
				SendKeys ('{TAB}');
				$input_speech = "";
			}
			if ($input_speech =~ /^enter/) {
				SendKeys ('~');
				$input_speech = "";
			}

			if ($input_speech =~ /^close program/) {
				SendKeys ('%({F4})');
				$input_speech = "";
			}

			if ($input_speech =~ /^next program/) {
				SendKeys ('%({TAB})');
				$input_speech = "";
			}

			if (($dictation == 1) && ($input_speech ne "") && ($confidence >=$audioConfidence)) 				{								
				print "$input_speech\n";
				SendKeys ("$input_speech ");
				$input_speech = "";
			}

			if (($dictation == 0) && ($command == 1) && ($input_speech =~ /\w+\s+/) && ($confidence >= $audioConfidence)) 	{
				my $randomInt = int(rand($#confirmPhrases)) - 1;
				my $confirm = $confirmPhrases[$randomInt];
				print "Opening ".$applicationKey."\n\n";
				$confirm = $confirm. " Opening ".$applicationKey;
				`$speakCmd \"$confirm\" 2>.errorLog`;
				`rm .errorLog &`;
				system ("$applicationCmd &");
			}
			if (($dictation == 0) && ($listening == 1) && ($input_speech =~ /\w+\s+/) && ($confidence >= $audioConfidence)) {
				my $chachaError = 0;
				my $isQuestion = 0;
				my $wolframError = 0;

				foreach my $questionPhrase (@questionPhrases) {
					if ($input_speech =~ /$questionPhrase/) {
						$isQuestion = 1;
					}
				}

				if ($isQuestion == 1) {					
					my $chachaquestion = $input_speech;					
					$chachaquestion =~ s/\s+/\+/gi;
					my $chacharesponse = "";
					$chacharesponse = get $chachaurl.$chachaquestion;
					if (defined($chacharesponse) == 1) {					
						my @arrayResp = split(/<h2>/, $chacharesponse);
						if (defined ($arrayResp[1]) == 1) {
							my @otherResp = split(/<span>/, $arrayResp[1]);
							$chacharesponse = $otherResp[0];
							$chacharesponse =~ s/^\s+//;
							$chacharesponse =~ s/\s+$//;
							while ($chacharesponse =~ /\<a.*\>/) {
								$chacharesponse =~ s/(\<a.*\>)(.+)(\<\/a.*\>)/$2/;
							}
						}
						else {
							$chacharesponse = "";
						}
					}
					else {
						$chacharesponse = "";
					}
					if (($chacharesponse eq "") || ($chacharesponse =~ /^\</)) {
						$chachaError = 1;
					}
					else {
						$chacharesponse =~ s/\&.*\;//g;
						$chacharesponse =~ s/^\s+//;
						$chacharesponse =~ s/\s+$//;
						my @chachaResponseArray = split(/\..*ChaCha/, $chacharesponse);
						if ($chacharesponse !~ /\.$/) {
							$chacharesponse = $chachaResponseArray[0].".";
						}
						chomp($chacharesponse);
						$megahal->learn($chacharesponse);
						`$speakCmd \"$chacharesponse\" 2>$aFile.errorLog`;
						`rm $aFile.errorLog &`;
							
						print "User: $input_speech\n$computerName: $chacharesponse\n\n";
												
					}
					lock($listening);
					$listening = 0;
				}

				if (($isQuestion == 1) && ($chachaError == 1)) {
					my $waQuery = $wolframAlpha->query(input => $input_speech);
					my $waResponse = "";
					if ($waQuery->success) {
						foreach my $pod (@{$waQuery->pods}) {
							if ($pod->title =~ /Result/) {
								foreach my $subpod (@{$pod->subpods}) {
									my $plainText = $subpod->plaintext;
									my $subpodTitle = $subpod->title;
									chomp ($plainText);
									chomp ($subpodTitle);
									$waResponse .= $plainText." ".$subpodTitle.".\n";
								}
							}							
						}						
					}
					else {
						$wolframError = 1;
					}
					$waResponse =~ s/^\s+//;
					$waResponse =~ s/\s+$//;
					chomp($waResponse);
					if ($waResponse eq "") {
						$wolframError = 1;					
					}
					else {						
						print "User: $input_speech\n$computerName: $waResponse\n\n";
						$waResponse =~ s/\(.*\)//g;
						`$speakCmd \"$waResponse\" 2>$aFile.errorLog`;
						`rm $aFile.errorLog &`;					
						lock($listening);
						$listening = 0;
					}					
				}

				if (($isQuestion == 0) || (($chachaError == 1) && ($wolframError == 1))) {
					my $intChatBot = int(rand(113));
					my $chatResponse = "";
					if ($intChatBot <= 29) {
						$chatResponse = $mybot->transform($input_speech);
					}
					else {
						$chatResponse = $megahal->do_reply($input_speech);	
					}
					$megahal->learn($input_speech.".");
					`$speakCmd \"$chatResponse\" 2>$aFile.errorLog`;
					`rm $aFile.errorLog &`;
					chomp($chatResponse);
					print "User: $input_speech\n$computerName: $chatResponse\n\n";
					lock ($listening);
					$listening = 0;				
				}
			}		
		}	
        }
}
