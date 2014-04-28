megatron
========

My version of Siri for Ubuntu 12.10+.  Modules available on CPAN.

Tested and working on : Ubuntu 12.04, 12.10, 13.04, 13.10, 14.04  Fedora 17, 18, 19, 20

This is not a complete list.  The program should work on any Linux machine provided the requirements are installed.


requirements
============

-  espeak:  linux text to speech program  
    install by typing 'sudo apt-get install espeak'
    
-  sox:  the Swiss army knife of sound programs 
    install by typing 'sudo apt-get install sox'
    
-  perl libraries:  WWW::WolframAlpha, AI::MegaHAL, LWP::Simple, Chatbot::Eliza, Thread::Queue, X11::GUITest
    e.g., install by typing: 'perl -MCPAN -e 'install WWW::WolframAlpha', to install module from CPAN.

   You will also need to install LWP::Protocol::https in order to communicate with google's speech to text api.
    

to run
======

./megatron.pl   (Assuming you've run 'chmod 755 megatron.pl')


The program will start by greeting you.  You can ask it to do things by saying, "Hey megatron" followed by
whatever you'd like to say.  You can ask it questions or just say stuff to it or ask it to do a few things.

Right now, the commands are pretty limitied and work on using a certain vocabulary ("open".  "start dictation", etc).

examples:  

"Hey megatron, can you open the internet?"  (Should open your internet browser, the same command "open" 
can be used to open any program.  The list can be customized in the megatron.conf file.)

"Hey megatron, what is the population of Iceland?"

Telling megatron to "stop" will exit the program.


common problems
===============

You might need to adjust the settings on your input microphone to get megatron to listen to you.

Once sox is installed, you can test out your recording device by typing 'sox -q -t alsa default test.wav rate 16k silence 1 0.1 5% 1 1.5 5%' and then play the file back using 'play test.wav'.

Make sure the test.wav file sounds audible, and that the sox program only stops recording when you stop speaking.

Open and run megatron.  The program should now be printing to the console what it thinks you're saying.

Also, you might want to turn the TV off or radio.  The microphone setting, if turned up too loud, can pick up ambient noise which can distort the recording.


ai
==

(NOTE: On many 64 bit systems, there is a bug in saving the brain file. 
 By default, this learning setting is disabled in the megatron.conf, set autosave=1 to allow the brain file to grow)
 
Megatron's brain is pretty limited and starts out empty initially.  It learns sentence structure from the things
you say to it. To speed up the learning process, a helper script is attached, which let's megatron's brain learn 
sentences from Wikipedia.  Install the 'WWW::Wikipedia' module from CPAN and run the script like below:

./teach_from_wikipedia 50000

Which will learn 50,000 English sentences from Wikipedia.


limitations
===========

The program doesn't know where you are geographically.  So if you ask it how the weather is going to be or a question
which is specific to your geography, it won't understand.


feedback
========
Any feedback or suggestions are greatly appreciated.  Thanks and enjoy.

vickumar@gmail.com
