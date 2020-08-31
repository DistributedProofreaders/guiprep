#!/usr/bin/perl
#
# guiprep.pl
#
my $currentver = '.41a';
#
# A perl script designed to help automate preparation of text files for Distributed Proofreaders.
#esponse
#
# The guiprep / Winprep pre-processing toolkit.   Written by Stephen Schulze.
#
#  This program is designed to help content providers prepare OCRed text files and images for the Distributed Proofreaders web site.
#  It will extract italic and bold markup as well as text from rtf format files, rejoin end-of-line hyphenated words, filter out bad
#  and undesirable characters and combinations, check for and fix the top 3400 or so scannos, rename the .txt and .png files into the
#  format needed by DP, check for zero byte files, and provides a easy mechanism to semi-automatically remove headers from the text files.
#
#  It has a built-in mini FTP client to upload the files to the site and provides hooks to link in your favorite text editor and image viewer
#  to help with the preparation process.
#
# For more details about use and operation, see the HTML manual included with the program and also on the web.
#
# This program may be freely used, copied, modified and distributed. Reverse engineering strictly encouraged.
#
# This software has no guarantees as to its fitness to do this or any other task.
#
#  Any damages to your computer, your data, your mental health or anything else as a result of using this software
#  are your problem and not mine. If not satisfied, your purchase price will be cheerfully refunded.

# Modifications
#
# grythumn
#   fix for directory lock problems when renaming
#
# Dave Morgan
#   fix for images/directories
#
# Malcolm Farmer:
#   minor Typo fixes
#   testart, ivstart & startpngcrush calls made Linux compatible
#   Don't dehyphenate numbers (makes indexes work better)
#   Page footers removal subroutine added
#   merged in these options from rfrank's cpprep:
#      Remove HTML markup (bold, italic, small caps)
#      Remove space before 'll
#      Remove space from I 'm,
#      Remove space from (s)he 's
#      Remove space from we 've
#      Remove space from we 'll
#      Remove space before n't
#      Remove space from I 'll
#      Remove space from I 've
#      Remove space from I 's
#      Convert '11 -> 'll
#      some of the "Spaceyquotes" regexps
#      mark possible missing spaces between words/sentences
#  remove footers in batch mode.
#  mark blank pages after header/footer removal
#
#
# lvl
#   don't convert solitary l to I  followed by ' and text (corrects behavour for French)
#




use 5.008;
use strict;
use Tk;
use Tk::widgets qw(Button Label Frame);
use Tk::Balloon;
use Tk::DialogBox;
use Tk::NoteBook;
use Tk::LabEntry;
use Tk::BrowseEntry;
use Tk::ROText;
use Tk::TextUndo;
use Tk::Pane;
use Tk::Checkbutton;
use Tk::FileSelect;
use Cwd;
use Net::FTP;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Storable;
if ($^O =~ /Win/) {require 'Win32API\File.pm'};
use locale;
use Time::HiRes qw( gettimeofday tv_interval );
use Encode::Unicode;
my $debug = 0;

# Global vars ########################################################################################

our $gextractbold = 1;
our $gitalicsopen ="<i>";
our $gitalicsclose="</i>";
our $gboldopen ="<b>";
our $gboldclose ="</b>";
our $gsupopen = "^{";
our $gsupclose = "}";
our $gzerobytetext = "[Blank Page]";
our @opt = (
1,1,1,1,1,1,1,1,1,1,
1,1,1,1,1,1,1,1,1,1,
1,1,1,1,0,1,1,1,1,1,
1,1,1,1,1,1,1,1,0,0,
0,1,1,1,1,1,1,0,1,0,
1,0,0,0,0,1,1,1,1,1,
1,1,1,1,1,1,0,1,1,1,
1,1,0,0,1,1,1,0,0,1,
1,1,1); # 82

# $opt[0] = Convert multiple spaces to single space.
# $opt[1] = Remove end of line spaces.
# $opt[2] = Remove space on either side of hyphens.
# $opt[3] = Remove space on either side of emdashes.
# $opt[4] = Remove space before periods.
# $opt[5] = Remove space before exclamation points.
# $opt[6] = Remove space before question marks.
# $opt[7] = Remove space before semicolons.
# $opt[8] = Remove space before commas.
# $opt[9] = Ensure space before ellipsis(except after period).
# $opt[10] = Convert two single quotes to one double.
# $opt[11] = Convert tii at the beginning of a word to th.
# $opt[12] = Convert solitary 1 to I.
# $opt[13] = Convert solitary 0 to O.
# $opt[14] = Convert vulgar fractions (М,Н,О) to written out.
# $opt[15] = Convert В and Г to ^2 and ^3.
# $opt[16] = Convert tli at the beginning of a word to th.
# $opt[17] = Convert rn at the beginning of a word to m.
# $opt[18] = Remove empty lines at top of page.
# $opt[19] = Convert multi consecutive blank lines to single.
# $opt[20] = Remove top line if number.
# $opt[21] = Remove bottom line if number.
# $opt[22] = Remove empty lines from bottom of page.
# $opt[23] = $extractbold
# $opt[24] = Convert degree symbol to written
# $opt[25] = Convert tb at the beginning of a word to th.
# $opt[26] = Convert wli at the beginning of a word to wh.
# $opt[27] = Convert wb at the beginning of a word to wh.
# $opt[28] = Batch Extract
# $opt[29] = Batch Dehyphenate
# $opt[30] = Batch Filter
# $opt[31] = Batch Spellcheck
# $opt[32] = Batch Rename
# $opt[33] = Batch Check Zeros
# $opt[34] = Convert hl at the beginning of a word to bl.
# $opt[35] = Convert hr at the beginning of a word to br.
# $opt[36] = Convert unlikly hyphens to em dashes
# $opt[37] = Convert a solitary l to I if proceeded by ' or " or space
# $opt[38] = Convert Ѓ to "Pounds
# $opt[39] = Convert Ђ to cents intelligently
# $opt[40] = Convert Ї to "Section
# $opt[41] = Remove space after open, before closing brackets.
# $opt[42] = Convert multiple consecutive underscores to em dash
# $opt[43] = Convert rnp in a word to mp.
# $opt[44] = Move punctuation outside of markup
# $opt[45] = Convert forward slash to comma apostrophe.
# $opt[46] = Convert solitary j to semicolon.
# $opt[47] = Batch Rename Pngs
# $opt[48] = Save FTP User & Password
# $opt[49] = Batch pngcrush
# $opt[50] = Convert Windows codepage 1252 glyphs 80-9F to Latin1 equivalents
# $opt[51] = Search case insensitive
# $opt[52] = Automatically Remove Headers during batch processing.
# $opt[53] = Automatically Remove Footers during batch processing
# $opt[54] = Build a standard upload batch and zip it to the project directory
# $opt[55] = Convert cb in a word to ch.
# $opt[56] = Convert gbt in a word to ght.
# $opt[57] = Convert [ai]hle in a word to [ai]ble.
# $opt[58] = Convert he to be if it follows to.
# $opt[59] = Convert \v or \\\\ to w.
# $opt[60] = Convert double commas to double quote.
# $opt[61] = Insert cell delimiters, "|" in tables.
# $opt[62] = Search whole word
# $opt[62] = Strip space after start & before end doublequotes.
# $opt[63] = Convert cl at the end of a word to d.
# $opt[64] = Convert pbt in a word to pht.
# $opt[65] = Convert rnm in a word to mm.
# $opt[66] = Batch run Englifh function
# $opt[67] = Extract sub/superscript markup
# $opt[68] = Convert vv at the beginning of a word to W
# $opt[69] = Convert !! at the beginning of a word to H
# $opt[70] = Convert X at the beginning of a word not followed by e to N
# $opt[71] = Convert ! in the middle of a word to l
# $opt[72] = Convert '!! to 'll
# $opt[73] = Use German style hyphens; "="
# $opt[74] = Convert to ISO 8859-1
# $opt[75] = Strip garbage punctuation from beginning of line.
# $opt[76] = Strip garbage punctuation from end of line.
# $opt[77] = Save files containing hyphenated and dehyphenated words
# $opt[78] = Extract <sc> </sc> maarkup for small caps
# $opt[79] = Remove HTML markup
# $opt[80] = Remove space from words with apostrophes
# $opt[81] = Convert '11 to 'll and remove any preceding space
# $opt[82] = despace quotes/mark dubious spaces
# $opt[83] = mark missing space between words/sentences

our $gpalette = 'grey80';
our $gcrushoptions =  '-bit_depth 1 -reduce ';
our $gimagesdir = 'pngs';

our $zerobytetext = $gzerobytetext;
our $italicsopen = $gitalicsopen;
our $italicsclose = $gitalicsclose;
our $boldopen = $gboldopen;
our $boldclose = $gboldclose;
our $supopen = $gsupopen;
our $supclose = $gsupclose;
our $palette = $gpalette;
our $editstart;
our $viewerstart;
our $linelength;
our @deletelines;
our $headersel;
our $startdir = getpwd();
our $lastrundir;
our $geometry = '640x480';
our $separator;
our ($interrupt, $batchmode, $bmessg);
our $ftp;
our $ftphostname = 'pgdp.net';
our $ftpusername;
our $ftppassword;
our %ftpaccount;
our @ftpbatch;
our @ftpdirlist;
our %ftpdircache;
our $ftpdownloaddir;
our $ftpinterrupt;
our $ftphome;
our $crushoptions = $gcrushoptions;
our $search = 0;
our $imagesdir = $gimagesdir;
our $filesearchindex;
our $filesearchindex1;
our $thissearch;
our $searchstartindex = '';
our $searchendindex = '0.0';
our @searchfilelist = ();

# End Global vars ####################################################################################
$SIG{ALRM} = 'IGNORE';	# ignore any watchdog timer alarms. subroutine that take a long time to complete can trip it
my $shelv = '-*-Helvetica-Medium-R-Normal--*-100-*-*-*-*-*-*';
my $helv = '-*-Helvetica-Medium-R-Normal--*-120-*-*-*-*-*-*';
my $cour = '-*-Courier-Medium-R-Normal--*-140-*-*-*-*-*-*';
my $courl = '-*-Courier-Medium-R-Normal--*-160-*-*-*-*-*-*';
my $helvb = '-*-Helvetica-Medium-R-Bold--*-160-*-*-*-*-*-*';
my $dirbox6;
my $runpngcrush;
my $foundfile;
my %seen = ();
my $hyphen = '-';
my $ftpscale = 1024;
my $winver;
my $startrnm = 1;

do 'settings.rc';

$opt[78] = 1;

$ftphostname  = 'pgdp.net' if ($ftphostname eq 'pgdp01.archive.org'); # Temporary force change from old server.

unless ($palette){$palette = $gpalette};

if ($^O =~ /Win/){
	$separator = '\\';
	$winver = `ver`;
	$winver =~ s/.*(Windows \w+) .*/$1/;
}else{
	$separator = '/';
}

chdir $lastrundir if defined $lastrundir;

our $pwd = getpwd();

# Create main window.
my $main = MainWindow->new(
	-title =>		'Guiprep Pre-processing Toolkit - '.$currentver,
);

# Set window size (pixels) the script TRIES to open with.
$main->geometry($geometry);

# Set the minimum window size.
$main->minsize(qw(600 480));

# Set an interesting palette color combo.
$main->setPalette("$palette");

my $mainbframe = $main->Frame()->pack(-anchor => 'nw');

my $bottomlabel = $mainbframe->Label(
	-text => "Working from the $pwd directory.",
	-font => '-*-Helvetica-Medium-R-Normal--*-160-*-*-*-*-*-*'
)->pack(-anchor => 'nw');

my $maintopframe = $main->Frame(
)->pack(-anchor => 'n', -expand => 'y', -fill => 'both');

my $book = $maintopframe->NoteBook( -ipadx => 6, -ipady => 6);

my $page2 = $book->add("page2", -label => "Select Options", -raisecmd => sub {$interrupt = 1;chdir $pwd;});
my $page1 = $book->add("page1", -label => "Process Text", -raisecmd => \&updateblist);
my $page8 = $book->add("page8", -label => "Search", -raisecmd => sub{$interrupt = 1; searchclear(); $filesearchindex1 = 1;
									@searchfilelist=(); $main->update; $main->Busy; searchincdec(); $main->Unbusy;});
my $page3 = $book->add("page3", -label => "Headers & Footers", -raisecmd => sub {emptybox(); $interrupt = 1;chdir $pwd;});
my $page4 = $book->add("page4", -label => "Change Directory", -raisecmd => sub {$interrupt = 1;chdir $pwd;});
my $page6 = $book->add("page6", -label => "Program Prefs", -raisecmd => sub {$interrupt = 1;chdir $pwd;});
my $page7 = $book->add("page7", -label => "FTP", -raisecmd => sub {$interrupt = 1; });
my $page5 = $book->add("page5", -label => "About", -raisecmd => sub {$interrupt = 1;chdir $pwd;});

## Page 1 layout ##################################################################################################################
my $p1text;

my $p1buttonbar = $page1->Frame(
)->pack(-side => 'left',
	-anchor => 'n',
	-pady => '4',
);

my $p1tframe = $page1->Frame(
)->pack(-side => 'right',
	-anchor => 'n',
	-padx => '5',
	-pady => '4',
	-fill => 'both',
	-expand => 'both'
);

$p1text = $p1tframe->Scrolled('ROText',
	-scrollbars =>		'oe',
 	-wrap => 		'word',
 	-background =>		'white',
 	-font =>		'-*-Helvetica-Medium-R-Normal--*-120-*-*-*-*-*-*',
 )->pack(-side => 'top', -anchor => 'n', -fill => 'both', -expand => 'both' );

BindMouseWheel($p1text);

# Make a frame to hold controls
my $p1b1f = $p1buttonbar->Frame()->pack(-side => 'top',	-anchor => 'n',);
my $p2cb28 = $p1b1f->Checkbutton(
	-variable => 	\$opt[28],
	-selectcolor => 'white',
	)->grid(-row=>1,-column=>1,-pady => '1');
my $extract = $p1b1f->Button(
	-command => 		sub {$interrupt = 0; xrtf();},
	-text =>		'Extract Markup',
	-width =>		'17'
)->grid(-row=>1,-column=>2,-pady => '1');
my $p2cb29 = $p1b1f->Checkbutton(
	-variable => 	\$opt[29],
	-selectcolor => 'white',
)->grid(-row=>2,-column=>1,-pady => '1');
my $dehyphen = $p1b1f ->Button(
	-command => 		sub {$interrupt = 0; dehyph();},
	-text =>		'Dehyphenate',
	-width =>		'17'
)->grid(-row=>2,-column=>2,-pady => '1');
my $p2cb32 = $p1b1f->Checkbutton(
	-variable => 	\$opt[32],
	-selectcolor => 'white',
)->grid(-row=>3,-column=>1,-pady => '1');
my $rename = $p1b1f->Button(
	-command => 		sub {$interrupt = 0; nam();},
	-text =>		'Rename Txt Files',
	-width =>		'17'
)->grid(-row=>3,-column=>2,-pady => '1');

my $p2cb30 = $p1b1f->Checkbutton(
	-variable => 	\$opt[30],
	-selectcolor => 'white',
)->grid(-row=>4,-column=>1,-pady => '1');
my $filter = $p1b1f ->Button(
	-command => 		sub {$interrupt = 0; filt();},
	-text =>		'Filter Files',
	-width =>		'17'
)->grid(-row=>4,-column=>2,-pady => '1');
my $p2cb31 = $p1b1f->Checkbutton(
	-variable => 	\$opt[31],
	-selectcolor => 'white',
)->grid(-row=>5,-column=>1,-pady => '1');
my $spellchk = $p1b1f ->Button(
	-command => 		sub {$interrupt = 0; splchk();},
	-text =>		'Fix Common Scannos',
	-width =>		'17'
)->grid(-row=>5,-column=>2,-pady => '1');
my $p2cb31 = $p1b1f->Checkbutton(
	-variable => 	\$opt[66],
	-selectcolor => 'white',
)->grid(-row=>6,-column=>1,-pady => '1');
my $spellchk = $p1b1f ->Button(
	-command => 		sub {$interrupt = 0; englifh();},
	-text =>		'Fix Olde Englifh',
	-width =>		'17'
)->grid(-row=>6,-column=>2,-pady => '1');
my $p2cb33 = $p1b1f->Checkbutton(
	-variable => 	\$opt[33],
	-selectcolor => 'white',
)->grid(-row=>7,-column=>1,-pady => '1');
my $zero = $p1b1f ->Button(
	-command => 	         sub {$interrupt = 0; zero();},
	-text =>		'Fix Zero Byte Files',
	-width =>		'17'
)->grid(-row=>7,-column=>2,-pady => '1');
my $p2cb74 = $p1b1f->Checkbutton(
	-variable => 	\$opt[74],
	-selectcolor => 'white',
)->grid(-row=>8,-column=>1,-pady => '1');
my $rename = $p1b1f ->Button(
	-command => 		sub {$interrupt = 0; conv();},
	-text =>		'Convert to ISO 8859-1',
	-width =>		'17'
)->grid(-row=>8,-column=>2,-pady => '1');
my $p2cb47 = $p1b1f->Checkbutton(
	-variable => 	\$opt[47],
	-selectcolor => 'white',
)->grid(-row=>9,-column=>1,-pady => '1');
my $pngrn = $p1b1f ->Button(
	-command => 	         sub {$interrupt = 0; pngrename();},
	-text =>		'Rename Png Files',
	-width =>		'17'
)->grid(-row=>9,-column=>2,-pady => '1');
my $p2cb49 = $p1b1f->Checkbutton(
	-variable => 	\$opt[49],
	-selectcolor => 'white',
)->grid(-row=>10,-column=>1,-pady => '1');
my $doall = $p1b1f->Button(
	-command => 		sub {$interrupt = 0; $runpngcrush = 1; pngcrush();},
	-text =>		'Run Pngcrush',
	-width =>		'17'
)->grid(-row=>10,-column=>2,-pady => '1');
my $p1b9f = $p1buttonbar->Frame(
)->pack(-side => 'top', -anchor => 'ne',);
$p1b9f->Label(
	-text =>'Renumber From'
)->grid(-row=>0,-column=>1,-pady => '1');
my $renamest = $p1b9f->Entry(
	-width => 6,
	-background => 'white',
	-textvariable => \$startrnm,
	-validate => 'all',
	-vcmd => sub{return 0 if $_[0] =~ /\D/; return 1;}
)->grid(-row=>0,-column=>2,-pady => '1');
my $batchbut = $p1b9f->Button(
	-command =>	sub{
				if (my @blist = $dirbox6->curselection){
					$interrupt = 0;
					batch();
				}else{
					$interrupt = 0;
					doall();
				}
			},
	-text =>		'Start Processing',
	-width =>		'12'
)->grid(-row=>1,-column=>2,-pady => '1');
my $p2cb51 = $p1b9f->Button(
	-command =>		\&tbackup,
	-text =>		'Make Backups',
	-width =>		'12'
)->grid(-row=>1,-column=>1,-pady => '1');
my $p1b10f = $p1buttonbar->Frame()->pack(-side => 'top', -anchor => 'ne',);
my $intbut = $p1b10f->Button(
	-command =>		sub {$interrupt = 1},
	-text =>		'Stop Processing',
	-width =>		'12'
)->grid(-row=>2,-column=>2,-pady => '1');
my $revert = $p1b10f->Button(
	-command =>		\&revert,
	-text =>		'Load Backups',
	-width =>		'12'
)->grid(-row=>2,-column=>1,-pady => '1');
my $p1b11f = $p1buttonbar->Frame()->pack(-anchor => 'n',-side => 'top');
my $pthelpbut = $p1b11f ->Button(
	-command => 		\&pthelp,
	-text =>		'?',
	-width =>		'2'
)->pack(-side => 'left', -pady => '1');
 my $savebut = $p1b11f ->Button(
	-command => 		\&saveptlog,
	-text =>		'Save log',
	-width =>		'7'
)->pack(-side => 'left', -pady => '1',-padx =>'1');
 my $clearbut = $p1b11f ->Button(
	-command => 		\&clear,
	-text =>		'Clear log',
	-width =>		'7'
)->pack(-side => 'left', -pady => '1',-padx =>'1');
my $p4blabelframe = $p1buttonbar->Frame()->pack(-anchor => 'n', -side => 'top',	-expand=>'y', -fill => 'y');

$bmessg = "No Directory Selected.";

my $p4bflabel = $p4blabelframe->Scrolled('ROText',
 	-scrollbars =>		'oe',
 	-wrap => 		'word',
 	-width => 		'23',
 	-font =>		'-*-Helvetica-Medium-R-Normal--*-110-*-*-*-*-*-*',
 )->pack(-side => 'top', -anchor => 'n', -fill => 'y', -expand => 'y', -padx => '2',-pady =>'2');
 BindMouseWheel($p4bflabel);

$p4bflabel->insert('insert',"$bmessg");

###################################################################################################################################

## Page 2 layout ##################################################################################################################
my $p2toplabel = $page2 -> Label(
	-text => "Select options for the markup extraction and filtering routines.\n",
	-font => $helvb)->pack;

my $p2buttons = $page2->Frame()->pack(-side => 'top',  -pady => '2', -anchor => 'n');

my $savesettings = $p2buttons ->Button(
	-command => 		\&save,
	-text =>		'Save Settings',
	-width =>		'15'
)->pack(-side => 'left', -padx => '10');

my $defaults = $p2buttons ->Button(
	-command => 		\&defaults,
	-text =>		'Default Markup',
	-width =>		'15'
)->pack(-side => 'left', -padx => '15');

my $blanklab = $p2buttons->Label(-text =>'Zero Byte Text', -font => $helvb)->pack(-side => 'right', -anchor => 'ne');

my $blank = $p2buttons->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -width =>	'30',
	 -font => 	$helvb,
	  )->pack(-side => 'right', -anchor => 'ne');

$blank->insert(0, $zerobytetext);

# Make a frame to contain all the widgets.
my $p2o1 = $page2->Frame()->pack(-side => 'top', -fill => 'x', -pady => '5', -anchor => 'n');

my $italopen = $p2o1->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helvb,
	  )->pack(-side => 'left', -anchor => 'n');
$italopen->insert(0, $italicsopen);

my $itolab = $p2o1->Label(-text =>' Italics open', -font => $helvb)->pack(-side => 'left', -anchor => 'nw');

my $itclab = $p2o1->Label(-text =>' Italics close', -font => $helvb)->pack(-side => 'right', -anchor => 'nw');

my $italclose = $p2o1->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helvb,
	  )->pack(-side => 'right', -anchor => 'n');
$italclose->insert(0, $italicsclose);

my $p2o2 = $page2->Frame()->pack(-side => 'top', -fill => 'x', -pady => '5', -anchor => 'n');
my $bopen = $p2o2->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helvb,
	  )->pack(-side => 'left', -anchor => 'nw');
$bopen->insert(0, $boldopen);
my $bolab = $p2o2->Label(-text =>' Bold open', -font => $helvb)->pack(-side => 'left', -anchor => 'nw');

my $boclab = $p2o2->Label(-text =>' Bold close  ', -font => $helvb)->pack(-side => 'right', -anchor => 'ne');
my $bclose = $p2o2->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helvb,
	  )->pack(-side => 'right', -anchor => 'ne');
$bclose->insert(0, $boldclose);

my $p2o3 = $page2->Frame()->pack(-side => 'top', -fill => 'x', -pady => '5', -anchor => 'n');
my $supsopen = $p2o3->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helvb,
	  )->pack(-side => 'left', -anchor => 'nw');
$supsopen->insert(0, $supopen);
my $supolab = $p2o3->Label(-text =>' Superscript open', -font => $helvb)->pack(-side => 'left', -anchor => 'nw');

my $supclab = $p2o3->Label(-text =>' Superscript close  ', -font => $helvb)->pack(-side => 'right', -anchor => 'ne');
my $supsclose = $p2o3->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helvb,
	  )->pack(-side => 'right', -anchor => 'ne');
$supsclose->insert(0, $supclose);

my $p2o4 = $page2->Frame(-relief => 'groove', -borderwidth => 2)->pack(-side => 'top', -fill => 'x', -pady => '2', -padx =>'2');

my $p2cb23 = $p2o4->Checkbutton(
	-variable => 	\$opt[23],
	-selectcolor => 'white',
	-text =>	'Extract Bold markup from rtf files.',
)->grid(-row=>0, -column =>1 ,-padx => '5', -sticky => 'w');

my $p2cb61 = $p2o4->Checkbutton(
	-variable => 	\$opt[61],
	-selectcolor => 'white',
	-text =>	'Insert cell delimiters, "|" in tables.',
)->grid(-row=>0, -column =>2 ,-padx => '5', -sticky => 'w');


my $p2cb67 = $p2o4->Checkbutton(
	-variable => 	\$opt[67],
	-selectcolor => 'white',
	-text =>	'Extract sub/superscript markup',
)->grid(-row=>1, -column =>1 ,-padx => '5', -sticky => 'w');

my $p2cb73 = $p2o4->Checkbutton(
	-variable => 	\$opt[73],
	-selectcolor => 'white',
	-text =>	'Dehyphenate using German style hyphens; "="',
	-command =>	sub{if ($opt[73]){$hyphen = "="}else{$hyphen = "-"}},
)->grid(-row=>1, -column =>2 ,-padx => '5', -sticky => 'w');

my $p2cb78 = $p2o4->Checkbutton(
	-variable => 	\$opt[78],
	-selectcolor => 'white',
	-text =>	'Insert small caps markup during RTF extraction',
	-command =>	sub{if ($opt[73]){$hyphen = "="}else{$hyphen = "-"}},
)->grid(-row=>2, -column =>1 ,-padx => '5', -sticky => 'w');

my $p2cb77 = $p2o4->Checkbutton(
	-variable => 	\$opt[77],
	-selectcolor => 'white',
	-text =>	'Save hyphens.txt & dehyphen.txt containing hyphenated and dehyphenated words from the dehyphenate routine.',
	-command =>	sub{if ($opt[73]){$hyphen = "="}else{$hyphen = "-"}},
)->grid(-row=>3, -column =>1, -columnspan => 2, -padx => '5', -sticky => 'w');


my $batchremove = $p2o4->Checkbutton(
	-variable => 	\$opt[52],
	-selectcolor => 'white',
	-text =>	"Automatically Remove Headers during batch processing. Be sure you understand the implications before enabling.",
)->grid(-row=>4, -column =>1, -columnspan => 2, -padx => '5', -sticky => 'w');


my $batchremove = $p2o4->Checkbutton(
	-variable => 	\$opt[53],
	-selectcolor => 'white',
	-text =>	"Automatically Remove Footers during batch processing. Be sure you understand the implications before enabling.",
)->grid(-row=>5, -column =>1, -columnspan => 2, -padx => '5', -sticky => 'w');


my $batchzip = $p2o4->Checkbutton(
	-variable => 	\$opt[54],
	-selectcolor => 'white',
	-text =>	"Build a standard upload batch and zip it to the project directory during batch processing.",
)->grid(-row=>6, -column =>1, -columnspan => 2, -padx => '5', -sticky => 'w');

my $p2o5 = $page2->Frame(-relief => 'groove', -borderwidth => 2
)->pack(-side => 'top', -fill => 'both', -expand => 'y', -pady=>'4',-padx =>'2');

my $p2opts = $p2o5->Scrolled('Pane', -scrollbars => 'w'
)->pack(-side => 'top', -anchor => 'n', -fill => 'both', -expand => 'y', -pady=>'6',-padx =>'2');

BindMouseWheel($p2opts);

my $grow = 0;

my $p2cb0 = $p2opts->Checkbutton(
	-variable => 	\$opt[0],
	-selectcolor => 'white',
	-text =>	'Convert multiple spaces to single space.',
)->grid(-row => $grow, -column => 1, -padx => '5', -sticky => 'w');

my $p2cb50 = $p2opts->Checkbutton(
	-variable => 	\$opt[50],
	-selectcolor => 'white',
	-text =>	'Convert Windows-1252 codepage glyphs 80-9F.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb1 = $p2opts->Checkbutton(
	-variable => 	\$opt[1],
	-selectcolor => 'white',
	-text =>	'Remove end of line spaces.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb36 = $p2opts->Checkbutton(
	-variable => 	\$opt[36],
	-selectcolor => 'white',
	-text =>	'Convert spaced hyphens to em dashes.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb42 = $p2opts->Checkbutton(
	-variable => 	\$opt[42],
	-selectcolor => 'white',
	-text =>	'Convert consecutive underscores to em dashes.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb2 = $p2opts->Checkbutton(
	-variable => 	\$opt[2],
	-selectcolor => 'white',
	-text =>	'Remove space on either side of hyphens.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb60 = $p2opts->Checkbutton(
	-variable => 	\$opt[60],
	-selectcolor => 'white',
	-text =>	'Convert double commas to double quote.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb3 = $p2opts->Checkbutton(
	-variable => 	\$opt[3],
	-selectcolor => 'white',
	-text =>	'Remove space on either side of emdashes.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb4 = $p2opts->Checkbutton(
	-variable => 	\$opt[4],
	-selectcolor => 'white',
	-text =>	'Remove space before periods.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb5 = $p2opts->Checkbutton(
	-variable => 	\$opt[5],
	-selectcolor => 'white',
	-text =>	'Remove space before exclamation points.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb6 = $p2opts->Checkbutton(
	-variable => 	\$opt[6],
	-selectcolor => 'white',
	-text =>	'Remove space before question marks.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb7 = $p2opts->Checkbutton(
	-variable => 	\$opt[7],
	-selectcolor => 'white',
	-text =>	'Remove space before semicolons.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb8 = $p2opts->Checkbutton(
	-variable => 	\$opt[8],
	-selectcolor => 'white',
	-text =>	'Remove space before commas.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb41 = $p2opts->Checkbutton(
	-variable => 	\$opt[41],
	-selectcolor => 'white',
	-text =>	'Remove space after open, before closing brackets.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb9 = $p2opts->Checkbutton(
	-variable => 	\$opt[9],
	-selectcolor => 'white',
	-text =>	'Ensure space before ellipsis(except after period).',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb10 = $p2opts->Checkbutton(
	-variable => 	\$opt[10],
	-selectcolor => 'white',
	-text =>	'Convert two single quotes to one double.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;


my $p2cb12 = $p2opts->Checkbutton(
	-variable => 	\$opt[12],
	-selectcolor => 'white',
	-text =>	'Convert solitary 1 to I.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');



my $p2cb37 = $p2opts->Checkbutton(
	-variable => 	\$opt[37],
	-selectcolor => 'white',
	-text =>	'Convert solitary lower case l to I.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb13 = $p2opts->Checkbutton(
	-variable => 	\$opt[13],
	-selectcolor => 'white',
	-text =>	'Convert solitary 0 to O.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb14 = $p2opts->Checkbutton(
	-variable => 	\$opt[14],
	-selectcolor => 'white',
	-text =>	'Convert vulgar fractions (М,Н,О) to written out.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;


my $p2cb15 = $p2opts->Checkbutton(
	-variable => 	\$opt[15],
	-selectcolor => 'white',
	-text =>	'Convert В and Г to ^2 and ^3.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');



my $p2cb38 = $p2opts->Checkbutton(
	-variable => 	\$opt[38],
	-selectcolor => 'white',
	-text =>	'Convert Ѓ to "Pounds".',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;



my $p2cb39 = $p2opts->Checkbutton(
	-variable => 	\$opt[39],
	-selectcolor => 'white',
	-text =>	'Convert Ђ to "cents".',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb40 = $p2opts->Checkbutton(
	-variable => 	\$opt[40],
	-selectcolor => 'white',
	-text =>	'Convert Ї to "Section".',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb24 = $p2opts->Checkbutton(
	-variable => 	\$opt[24],
	-selectcolor => 'white',
	-text =>	'Convert А to "degrees".',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb45 = $p2opts->Checkbutton(
	-variable => 	\$opt[45],
	-selectcolor => 'white',
	-text =>	'Convert forward slash to comma apostrophe.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb59 = $p2opts->Checkbutton(
	-variable => 	\$opt[59],
	-selectcolor => 'white',
	-text =>	'Convert \v or \\\\ to w.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb46 = $p2opts->Checkbutton(
	-variable => 	\$opt[46],
	-selectcolor => 'white',
	-text =>	'Convert solitary j to semicolon.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb16 = $p2opts->Checkbutton(
	-variable => 	\$opt[16],
	-selectcolor => 'white',
	-text =>	'Convert tli at the beginning of a word to th.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb11 = $p2opts->Checkbutton(
	-variable => 	\$opt[11],
	-selectcolor => 'white',
	-text =>	'Convert tii at the beginning of a word to th.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;


my $p2cb25 = $p2opts->Checkbutton(
	-variable => 	\$opt[25],
	-selectcolor => 'white',
	-text =>	'Convert tb at the beginning of a word to th.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb26 = $p2opts->Checkbutton(
	-variable => 	\$opt[26],
	-selectcolor => 'white',
	-text =>	'Convert wli at the beginning of a word to wh.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;


my $p2cb27 = $p2opts->Checkbutton(
	-variable => 	\$opt[27],
	-selectcolor => 'white',
	-text =>	'Convert wb at the beginning of a word to wh.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb17 = $p2opts->Checkbutton(
	-variable => 	\$opt[17],
	-selectcolor => 'white',
	-text =>	'Convert rn at the beginning of a word to m.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb34 = $p2opts->Checkbutton(
	-variable => 	\$opt[34],
	-selectcolor => 'white',
	-text =>	'Convert hl at the beginning of a word to bl.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb35 = $p2opts->Checkbutton(
	-variable => 	\$opt[35],
	-selectcolor => 'white',
	-text =>	'Convert hr at the beginning of a word to br.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb43 = $p2opts->Checkbutton(
	-variable => 	\$opt[43],
	-selectcolor => 'white',
	-text =>	'Convert rnp in a word to mp.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb68 = $p2opts->Checkbutton(
	-variable => 	\$opt[68],
	-selectcolor => 'white',
	-text =>	'Convert vv at the beginning of a word to w.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb69 = $p2opts->Checkbutton(
	-variable => 	\$opt[69],
	-selectcolor => 'white',
	-text =>	'Convert !! at the beginning of a word to H',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb70 = $p2opts->Checkbutton(
	-variable => 	\$opt[70],
	-selectcolor => 'white',
	-text =>	'Convert initial X not followed by e to N.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb71 = $p2opts->Checkbutton(
	-variable => 	\$opt[71],
	-selectcolor => 'white',
	-text =>	'Convert ! inside a word to l.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb72 = $p2opts->Checkbutton(
	-variable => 	\$opt[72],
	-selectcolor => 'white',
	-text =>	'Convert \'!! to \'ll.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb80 = $p2opts->Checkbutton(
	-variable => 	\$opt[80],
	-selectcolor => 'white',
	-text =>	'Remove space before  apostrophes.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb81 = $p2opts->Checkbutton(
	-variable => 	\$opt[81],
	-selectcolor => 'white',
	-text =>	'Convert \'11 to \'ll.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb65 = $p2opts->Checkbutton(
	-variable => 	\$opt[65],
	-selectcolor => 'white',
	-text =>	'Convert rnm in a word to mm.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb55 = $p2opts->Checkbutton(
	-variable => 	\$opt[55],
	-selectcolor => 'white',
	-text =>	'Convert cb in a word to ch.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb56 = $p2opts->Checkbutton(
	-variable => 	\$opt[56],
	-selectcolor => 'white',
	-text =>	'Convert gbt in a word to ght.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb57 = $p2opts->Checkbutton(
	-variable => 	\$opt[57],
	-selectcolor => 'white',
	-text =>	'Convert [ai]hle in a word to [ai]ble.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;


my $p2cb63 = $p2opts->Checkbutton(
	-variable => 	\$opt[63],
	-selectcolor => 'white',
	-text =>	'Convert cl at the end of a word to d.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb64 = $p2opts->Checkbutton(
	-variable => 	\$opt[64],
	-selectcolor => 'white',
	-text =>	'Convert pbt in a word to pht.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;

my $p2cb58 = $p2opts->Checkbutton(
	-variable => 	\$opt[58],
	-selectcolor => 'white',
	-text =>	'Convert he to be if it follows to.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb44 = $p2opts->Checkbutton(
	-variable => 	\$opt[44],
	-selectcolor => 'white',
	-text =>	'Move punctuation outside of markup.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;


my $p2cb75 = $p2opts->Checkbutton(
	-variable => 	\$opt[75],
	-selectcolor => 'white',
	-text =>	'Strip garbage punctuation from beginning of line.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb18 = $p2opts->Checkbutton(
	-variable => 	\$opt[18],
	-selectcolor => 'white',
	-text =>	'Remove empty lines at top of page.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');

++$grow;


my $p2cb76 = $p2opts->Checkbutton(
	-variable => 	\$opt[76],
	-selectcolor => 'white',
	-text =>	'Strip garbage punctuation from end of line.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb19 = $p2opts->Checkbutton(
	-variable => 	\$opt[19],
	-selectcolor => 'white',
	-text =>	'Convert multi consecutive blank lines to single.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb20 = $p2opts->Checkbutton(
	-variable => 	\$opt[20],
	-selectcolor => 'white',
	-text =>	'Remove top line if number.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');

my $p2cb21 = $p2opts->Checkbutton(
	-variable => 	\$opt[21],
	-selectcolor => 'white',
	-text =>	'Remove bottom line if number.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb22 = $p2opts->Checkbutton(
	-variable => 	\$opt[22],
	-selectcolor => 'white',
	-text =>	'Remove empty lines from bottom of page.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


my $p2cb79 = $p2opts->Checkbutton(
	-variable => 	\$opt[79],
	-selectcolor => 'white',
	-text =>	'Remove HTML markup (bold, italics, smallcap).',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


++$grow;

my $p2cb82 = $p2opts->Checkbutton(
	-variable => 	\$opt[82],
	-selectcolor => 'white',
	-text =>	'Tidy up/mark dubious spaced quotes.',
)->grid(-row => $grow, -column => 2 ,-padx => '5', -sticky => 'w');


my $p2cb82 = $p2opts->Checkbutton(
	-variable => 	\$opt[83],
	-selectcolor => 'white',
	-text =>	'Mark possible missing spaces between word/sentences.',
)->grid(-row => $grow, -column => 1 ,-padx => '5', -sticky => 'w');


###################################################################################################################################

###################################################################################################################################

## Page 3 layout ##################################################################################################################
# Put some explanatory text at the top of the window.

my $p3toplabel = $page3 -> Label(
	-text => "Select the lines to delete.\nLines with a white background will be deleted.",
	-font => $helvb)->pack;

# Make a frame to contain  the widgets.
my $optlist = $page3->Frame()->pack(-side => 'top', -fill => 'both', -expand => 'both');
# Create the balloon widget used by the tooltips.
my $b = $optlist->Balloon(
	-state => 		'balloon',
	-balloonposition =>	'mouse',
);

# Make a subframe for row one of buttons and populate it.
my $buttonbar1 = $optlist->Frame()->pack(-anchor=>'n',-expand=>'no', -fill => 'none');

# Populate it with buttons.

my $gethbut = $buttonbar1 ->Button(
	-command =>  		\&getheaders,
	-text =>		'Get Headers',
	-width =>		'15'
)->pack(-side => 'left');


my $getfbut = $buttonbar1 ->Button(
	-command =>  		\&getfooters,
	-text =>		'Get Footers',
	-width =>		'15'
)->pack(-side => 'left');


my $headhelpbut = $buttonbar1 ->Button(
	-command =>  		\&helphr,
	-text =>		'?',
	-width =>		'2'
)->pack(-side => 'left', -padx => '12');




# now for row 2

my $buttonbar2 = $optlist->Frame()->pack(-anchor=>'n',-expand=>'no', -fill => 'none');



my $allbut = $buttonbar2 ->Button(
	-command =>  		\&setall,
	-text =>		'Select All',
	-width =>		'15'
)->pack(-side => 'left');


my $nonebut = $buttonbar2 ->Button(
	-command =>		\&clearall,
	-text =>		'Unselect All',
	-width =>		'15'
)->pack(-side => 'left');



my $togglebut = $buttonbar2 ->Button(
	-command =>		\&toggle,
	-text =>		'Toggle Selection',
	-width =>		'15'
)->pack(-side => 'left');

my $okbut = $buttonbar2 ->Button(
	-command => 		\&ok,
	-text =>		'Remove Selected',
	-width =>		'15'
)->pack(-side => 'left');





# Set up tooltip help popups
 $b->attach($okbut,
	     -balloonmsg => "Write the changes.",
	     -initwait =>	'750',
          );

$b->attach($nonebut,
	     -balloonmsg => "Unselect all lines. (Remove None).",
	     -initwait =>	'750',
          );

$b->attach($allbut,
	     -balloonmsg => "Select all lines. (Remove All).",
	     -initwait =>	'750',
          );

$b->attach($togglebut,
	     -balloonmsg => "Reverse the state of the current selection.",
	     -initwait =>	'750',
          );

$b->attach($gethbut,
	     -balloonmsg => "Get the headers from the text directory.",
	     -initwait =>	'750',
          );

$b->attach($getfbut,
	     -balloonmsg => "Get the footers from the text directory.",
	     -initwait =>	'750',
          );


# Add a listbox to display all of the headers/footers.
my $lbox = $optlist->Scrolled('Listbox',
	-scrollbars =>		'oe',
	-background =>		'white',
	-selectmode =>		'multiple'
)->pack(-anchor=>'nw', -fill => 'both',-expand=>'both',  -padx => '5', -pady => '5');

BindMouseWheel($lbox);
$lbox->eventAdd('<<edit>>' =>  '<Double-Button-1>');
$lbox->bind('<<edit>>', sub {
		my ($clickedfil);
		my $clicked = $lbox->get('active');
		$clicked =~ m/^(.*?\.txt)/;
		my $clickedfile = $1;
		if ($^O =~ /Win/){
			$clickedfil = $pwd .'\\text\\' . $clickedfile;
		}else{
			$clickedfil = $pwd .'/text/' . $clickedfile;
		}
		if ($editstart){
			testart($clickedfil);
		}else{
			my $response = $main->messageBox(
				-icon => 'error',
				-message => "Could not start your text editor $editstart\nWould you like to set up a text editor?.",
				-title => 'Editor not found',
				-type => 'YesNo',
			);
			if ($response eq 'yes'){
				editorsel();
				testart($clickedfil);
			}
		}
	});
$lbox->eventAdd('<<view>>' =>  '<Button-2>','<Button-3>');
$lbox->bind('<<view>>', sub {
		my ($clickedfil);
		my $clicked = $lbox->get('active');
		$clicked =~ m/^(.*?\.txt)/;
		my $clickedfile = $1;
		$clickedfile =~ s/txt$/png/;
		$clickedfil = $pwd.$separator.$imagesdir.$separator.$clickedfile;
		if ($viewerstart){
			ivstart($clickedfil);
		}else{
			my $response = $main->messageBox(
				-icon => 'error',
				-message => "Could not start your image viewer.\nWould you like to set up an image viewer?.",
				-title => 'Image Viewer Not Found',
				-type => 'YesNo',
			);
			if ($response eq 'yes'){
				viewersel();
				ivstart($clickedfil);
			}

		}
});


###################################################################################################################################

## Page 4 layout ##################################################################################################################

my $p4topframe1 = $page4->Frame()->pack(-side => 'top', -anchor => 'n');

 my $cdhelpbut = $p4topframe1->Button(
	-command =>  		\&helpcd,
	-text =>		'?',
	-width =>		'2'
)->pack(-side => 'left', -anchor => 'n', -pady => '5', -padx => '15');

my $p4topframe = $page4->Frame(-height => '5')->pack(-side => 'top', -anchor => 'nw');

if ($^O =~ /Win/){
	my $drv;
	my $drive = substr(getpwd(),0,3);
	my @drivelist = getdrives();
	my $drives = $p4topframe->BrowseEntry(
		-label => "Select Drive",
		-variable => 	\$drive,
		-state => 	'readonly',
		-width =>	'5',
		-listwidth =>	'12',
		-browsecmd => 	\&chdirectory,
)->pack(-anchor => 'nw', -side => 'left', -padx => '25', -pady => '1');

    	foreach $drv(@drivelist) {$drives->insert("end", $drv)};
}

my $p4lframe =  $page4->Frame()->pack(-side => 'top', -anchor => 'n');

my $tdirlabel = $p4lframe->ROText(
	-font => 	$helvb,
	-relief => 	'flat',
	-height => '1',
)->pack(-side => 'top', -anchor => 'n', -padx => '5');

$tdirlabel->insert('end',$pwd);

my $p4mframe =  $page4->Frame()->pack(-side => 'top', -anchor => 'n', -expand=>'y', -fill =>'y', );

my $p4rframe =  $p4mframe->Frame()->pack(-side => 'left', -anchor => 'n', -expand=>'y', -fill =>'y', );

my $dirbox = $p4rframe->Scrolled('Listbox',
	-label => "Change To Directory:",
	-scrollbars =>		'osoe',
	-width =>		'35',
	-height =>		'12',
	-background =>		'white',
	-selectmode =>		'single'
)->pack(-side => 'top', -anchor=> 'n', -padx => '15', -pady => '25', -expand=>'y', -fill =>'y', );
BindMouseWheel($dirbox);

my $pdrframe =  $p4mframe->Frame()->pack(-side => 'right', -anchor => 'n', -expand=>'y', -fill =>'y', );

$dirbox6 = $p4mframe->Scrolled('Listbox',
	-label => "Select Directories To Batch Process: (Optional)",
	-scrollbars =>		'osoe',
	-width =>		'35',
	-height =>		'12',
	-background =>		'white',
	-selectmode =>		'multiple'
)->pack(-side => 'top', -anchor=> 'n', -padx => '15', -pady => '25', -expand=>'y', -fill =>'y', );
BindMouseWheel($dirbox6);

my @dirlist6 = getdirs();
shift @dirlist6;
$dirbox6->insert('end', @dirlist6);

my @dirlist = getdirs();
$dirbox->insert('end', @dirlist);
$dirbox->eventAdd('<<Change>>' =>  '<Double Button-1>');
$dirbox->bind('<<Change>>', sub {
	my @changeto = $dirbox->curselection;
	chdirectory(1, $dirlist[$changeto[0]]);
	@dirlist = getdirs();
});

###################################################################################################################################

## Page 5 layout ##################################################################################################################

my $p5frame =  $page5->Frame->pack(-side => 'top', -anchor => 'n', -padx => '10',-pady => '10', -expand =>'both',-fill=>'both');
 my $p5rframetext = $p5frame->Scrolled('ROText',
 	-scrollbars =>		'oe',
 	-background => 		'white',
 	-wrap => 		'word',
 	-font =>		'helv',
 	-height =>		'24',
 )->pack(-expand =>'both',-fill=>'both');
 BindMouseWheel($p5rframetext);

  $p5rframetext->insert('end',"\n".'The guiprep / Winprep pre-processing toolkit.   Written by Stephen Schulze.'.
  	"\n\n".
 	'  This program is designed to help content providers prepare OCRed text files and images for the Distributed Proofreaders web site. '.
 	'It will extract italic and bold markup as well as text from rtf format files, rejoin end-of-line hyphenated words, '.
 	'filter out bad and undesirable characters and combinations, check for and fix the top 3400 or so scannos, rename the '.
 	'.txt and .png files into '.
 	'the format needed by DP, check for zero byte files, and provides a easy mechanism to semi-automatically remove headers '.
 	'from the text files.'."\n It has a built-in mini FTP client to upload the files to the site and provides hooks to link ".
 	'in your favorite text editor and image viewers to help with the preparation process.'.
 	 "\n\n\n".
 	 '  For more details about use and operation, see the HTML manual included with the program and also on the web.'.
 	 "\n\n".
 	"  This program may be freely used, copied, modified and distributed. Reverse engineering strictly encouraged.\n\nThis software has ".
 	'no guarantees as to its fitness to do this or any other task.'.
 	"\n".
 	'Any damages to your computer, your data, your mental health or anything else as a result of using this software '.
 	'are your problem and not mine. If not satisfied, your purchase price will be cheerfully refunded.'
 	);

##########################################################################################################################

## Page 6 layout #########################################################################################################

my $p6bframe = $page6->Frame()->pack(-side => 'top', -anchor => 'n');

my $p6bframe1 = $p6bframe->Frame()->pack(-side =>'left', -anchor => 'nw');

my $b6blbl = $p6bframe1->Label(
	-text => 	"Try a different color scheme.\nDouble click on a palette to use it.\n(Warning, some are truly putrid.)",
)->pack(-side => 'top');
my $palletlabel = $p6bframe1->Label(-text=>"Current palette - $palette")->pack(-side => 'top',-pady=>5);

my $defcolor = $p6bframe1->Button(
	-command =>		sub{
					$palette = $gpalette;
					$main->setPalette("$palette");
					$palletlabel->configure(-text=>"Current palette - $palette");
				},
	-text =>		'Default palette',
	-width =>		'15'
)->pack(-side => 'top');

my $p6list = $p6bframe1->Scrolled(qw/Listbox -width 20 -height 8 -scrollbars e -background white/
)->pack(-side =>'left', -padx => '5', -pady => '2');

BindMouseWheel($p6list);
    $p6list->bind('<Double-1>' =>
        sub  {				# palette selection code stolen directly from widgets examples included with perl
		$p6list->Busy;
		$_[0]->setPalette($_[0]->get('active'));
		$palette = $_[0]->get('active');
		$palletlabel->configure(-text=>"Current palette - $palette");
		$p6list->Unbusy;
	    },
    );
	# Ooooo... look at all the pretty colors.....
$p6list->insert(0, qw/gray60 gray70 gray80 gray85 gray90
gray95 snow1 snow2 snow3 snow4 seashell1 seashell2 seashell3 seashell4
AntiqueWhite1 AntiqueWhite2 AntiqueWhite3 AntiqueWhite4 bisque1
bisque2 bisque3 bisque4 PeachPuff1 PeachPuff2 PeachPuff3 PeachPuff4
NavajoWhite1 NavajoWhite2 NavajoWhite3 NavajoWhite4 LemonChiffon1
LemonChiffon2 LemonChiffon3 LemonChiffon4 cornsilk1 cornsilk2
cornsilk3 cornsilk4 ivory1 ivory2 ivory3 ivory4 honeydew1 honeydew2
honeydew3 honeydew4 LavenderBlush1 LavenderBlush2 LavenderBlush3
LavenderBlush4 MistyRose1 MistyRose2 MistyRose3 MistyRose4 azure1
azure2 azure3 azure4 SlateBlue1 SlateBlue2 SlateBlue3 SlateBlue4
RoyalBlue1 RoyalBlue2 RoyalBlue3 RoyalBlue4 blue1 blue2 blue3 blue4
DodgerBlue1 DodgerBlue2 DodgerBlue3 DodgerBlue4 SteelBlue1 SteelBlue2
SteelBlue3 SteelBlue4 DeepSkyBlue1 DeepSkyBlue2 DeepSkyBlue3
DeepSkyBlue4 SkyBlue1 SkyBlue2 SkyBlue3 SkyBlue4 LightSkyBlue1
LightSkyBlue2 LightSkyBlue3 LightSkyBlue4 SlateGray1 SlateGray2
SlateGray3 SlateGray4 LightSteelBlue1 LightSteelBlue2 LightSteelBlue3
LightSteelBlue4 LightBlue1 LightBlue2 LightBlue3 LightBlue4 LightCyan1
LightCyan2 LightCyan3 LightCyan4 PaleTurquoise1 PaleTurquoise2
PaleTurquoise3 PaleTurquoise4 CadetBlue1 CadetBlue2 CadetBlue3
CadetBlue4 turquoise1 turquoise2 turquoise3 turquoise4 cyan1 cyan2
cyan3 cyan4 DarkSlateGray1 DarkSlateGray2 DarkSlateGray3
DarkSlateGray4 aquamarine1 aquamarine2 aquamarine3 aquamarine4
DarkSeaGreen1 DarkSeaGreen2 DarkSeaGreen3 DarkSeaGreen4 SeaGreen1
SeaGreen2 SeaGreen3 SeaGreen4 PaleGreen1 PaleGreen2 PaleGreen3
PaleGreen4 SpringGreen1 SpringGreen2 SpringGreen3 SpringGreen4 green1
green2 green3 green4 chartreuse1 chartreuse2 chartreuse3 chartreuse4
OliveDrab1 OliveDrab2 OliveDrab3 OliveDrab4 DarkOliveGreen1
DarkOliveGreen2 DarkOliveGreen3 DarkOliveGreen4 khaki1 khaki2 khaki3
khaki4 LightGoldenrod1 LightGoldenrod2 LightGoldenrod3 LightGoldenrod4
LightYellow1 LightYellow2 LightYellow3 LightYellow4 yellow1 yellow2
yellow3 yellow4 gold1 gold2 gold3 gold4 goldenrod1 goldenrod2
goldenrod3 goldenrod4 DarkGoldenrod1 DarkGoldenrod2 DarkGoldenrod3
DarkGoldenrod4 RosyBrown1 RosyBrown2 RosyBrown3 RosyBrown4 IndianRed1
IndianRed2 IndianRed3 IndianRed4 sienna1 sienna2 sienna3 sienna4
burlywood1 burlywood2 burlywood3 burlywood4 wheat1 wheat2 wheat3
wheat4 tan1 tan2 tan3 tan4 chocolate1 chocolate2 chocolate3 chocolate4
firebrick1 firebrick2 firebrick3 firebrick4 brown1 brown2 brown3
brown4 salmon1 salmon2 salmon3 salmon4 LightSalmon1 LightSalmon2
LightSalmon3 LightSalmon4 orange1 orange2 orange3 orange4 DarkOrange1
DarkOrange2 DarkOrange3 DarkOrange4 coral1 coral2 coral3 coral4
tomato1 tomato2 tomato3 tomato4 OrangeRed1 OrangeRed2 OrangeRed3
OrangeRed4 red1 red2 red3 red4 DeepPink1 DeepPink2 DeepPink3 DeepPink4
HotPink1 HotPink2 HotPink3 HotPink4 pink1 pink2 pink3 pink4 LightPink1
LightPink2 LightPink3 LightPink4 PaleVioletRed1 PaleVioletRed2
PaleVioletRed3 PaleVioletRed4 maroon1 maroon2 maroon3 maroon4
VioletRed1 VioletRed2 VioletRed3 VioletRed4 magenta1 magenta2 magenta3
magenta4 orchid1 orchid2 orchid3 orchid4 plum1 plum2 plum3 plum4
MediumOrchid1 MediumOrchid2 MediumOrchid3 MediumOrchid4 DarkOrchid1
DarkOrchid2 DarkOrchid3 DarkOrchid4 purple1 purple2 purple3 purple4
MediumPurple1 MediumPurple2 MediumPurple3 MediumPurple4 thistle1
thistle2 thistle3 thistle4/);

 # end colors

my $p6bframe2 = $p6bframe->Frame()->pack(-side =>'right', -anchor => 'ne', -padx=>'15');

my $p6pngsdirlbl = $p6bframe2->Label(
	-text => "Name of directory under your project directory\nwhere your PNG images are located.",
)->pack(-padx =>'10');

my $p6pngsdirentry = $p6bframe2->Entry(
	-background => 'white',
	-width =>	'35',
)->pack();

my $chpngsdirbut = $p6bframe2->Button(
	-command =>		sub{$imagesdir = $p6pngsdirentry->get; save();},
	-text =>		'OK',
	-width =>		'6'
)->pack(-side => 'top', -pady => '5');

$p6pngsdirentry->insert(0,"$imagesdir");

my $p6bbframe = $page6->Frame()->pack();

my $editsel = $p6bbframe->Button(
	-command =>		\&editorsel,
	-text =>		'Setup Text Editor',
	-width =>		'15'
)->pack(-side => 'left', -padx => '10', -pady => '1');

my $editlabel = $p6bbframe->ROText(
	-height => '4',
	-relief => 'flat',
	-font => '-*-Helvetica-Medium-R-Normal--*-120-*-*-*-*-*-*',
)->pack(-side => 'left',-pady => '1');

my $p6bcframe = $page6->Frame()->pack();

my $viewsel = $p6bcframe->Button(
	-command =>		\&viewersel,
	-text =>		'Setup Image Viewer',
	-width =>		'15'
)->pack(-side => 'left', -padx => '10', -pady => '1');

my $viewlabel = $p6bcframe->ROText(
	-height => '4',
	-relief => 'flat',
	-font => '-*-Helvetica-Medium-R-Normal--*-120-*-*-*-*-*-*',
)->pack(-side => 'left');

$editlabel->insert('end',"\nBrowse to find text editor. Wordpad or Notepad or equivalent for Windows.\n");
if ($editstart){
	$editlabel->insert('end',"Current Editor is set to - $editstart.");
}else{
	$editlabel->insert('end',"No Editor is selected.");
}

$viewlabel->insert('end',"\nBrowse to find image viewer.\n");

if ($viewerstart){
	$viewlabel->insert('end',"Current image viewer is set to - $viewerstart.");
}else{
	$viewlabel->insert('end',"No image viewer is selected.");
}

my $p6crushframe = $page6->Frame()->pack(-side => 'top', -anchor => 'n');

my $crushentry = $p6crushframe->Entry(
	 -relief => 'sunken',
	 -background => 'white',
	 -font => 	$helv,
	 -width => 	'46',
)->pack(-side => 'left', -anchor => 'n',-pady => '12');

my $crushlab = $p6crushframe->Label(-text =>"Pngcrush\noptions")->pack(-side => 'left', -anchor => 'n',-pady => '5');

my $crushdefaults = $p6crushframe->Button(
	-command =>		sub {$crushoptions = $gcrushoptions;
					$crushentry->delete(0,'end');
					$crushentry->insert(0, $crushoptions);},
	-text =>		'Default Pngcrush Options',
	-width =>		'20'
)->pack(-side => 'left', -padx => '5', -pady => '3');

my $crushreadme = $p6crushframe->Button(
	-command =>		sub {testart($startdir.$separator."pngcrush".$separator."README.txt")},

	-text =>		'View Pngcrush Help',
	-width =>		'20'
)->pack(-side => 'left', -padx => '5', -pady => '5');

my $p6crushlframe = $page6->Frame()->pack(-side => 'top', -anchor => 'n');

my $crushlab1 = $p6crushlframe->Scrolled('ROText',
	-scrollbars => 'oe',
	-wrap => 'word',
	-background => 'white',
	-height => '6')->pack(-side => 'top', -anchor => 'n',-pady => '4');

$crushlab1->insert('end', "-bit_depth 1 converts the file to single bit color (black & white).\n\n-reduce reduces the color palette ".
	"to only contain colors actually used in the image.\n\n".
	"You can use nearly any of the standard options, a few will not work very well because of the way the script handles files. ".
	"For instance the -d (output directory) will definitely cause problems, as will -e (output extension). Most of the rest can be ".
	"used with no problem. The script uses the \"pngcrush [options] infile.png outfile.png\" format. See the readme file for options ".
	"and explanations."
);

$crushentry->insert(0, $crushoptions);

sub editorsel{
	my $tempval = $editsel->getOpenFile(-title =>'Select your text editor.');
	if ($tempval){
		$editstart = $tempval;
		if ($^O =~ /Win/){
			$editstart =~ s/\//\\/g;
		}
	}
	save();
	$editlabel->delete('1.0','end');
	$editlabel->update;
	$editlabel->insert('end',"Browse to find text editor. Wordpad or Notepad or equivalent for Windows.\nPico or joe or equivalent for Linux.\n");
	if ($editstart){
		$editlabel->insert('end',"Current Editor is set to - $editstart.");
	}else{
		$editlabel->insert('end',"No Editor is selected.");
	}
	$editlabel->update;
}
sub viewersel{
	my $tempval = $viewsel->getOpenFile(-title =>'Select your image viewer.');
	if ($tempval){
		$viewerstart = $tempval;
		if ($^O =~ /Win/){
			$viewerstart =~ s/\//\\/g;
		}
	}
	save();
	$viewlabel->delete('1.0','end');
	$viewlabel->update;
	$viewlabel->insert('end',"\nBrowse to find image viewer.\n");
	if ($viewerstart){
		$viewlabel->insert('end',"Current image viewer is set to - $viewerstart.");
	}else{
		$viewlabel->insert('end',"\nNo image viewer is selected.");
	}
	$viewlabel->update;
}
##########################################################################################################################

## Page 7 layout #########################################################################################################

my $p7frame = $page7->Frame()->pack(-side => 'top', -anchor => 'nw', -expand => 'y',-fill => 'both', -padx =>'10', -pady => '10');

my $p7statframe = $p7frame->Frame()->pack(-side => 'top', -anchor => 'n');
my $p7host;
my $p7user;
my $p7pass;
my $p7home;

my $p7hostlabel = $p7statframe->Label(
	-font =>	$helv,
	-text =>	'-Host Name-'
)->grid(-row=>1, -column=>1,-pady=>3);
my $p7userlabel = $p7statframe->Label(
	-font =>	$helv,
	-text =>	'-User Name-'
)->grid(-row=>1, -column=>2);
my $p7passlabel = $p7statframe->Label(
	-font =>	$helv,
	-text =>	'-Password-'
)->grid(-row=>1, -column=>3);
my $p7homelabel = $p7statframe->Label(
	-font =>	$helv,
	-text =>	'-Home Dir-'
)->grid(-row=>1, -column=>4);
$p7host = $p7statframe->BrowseEntry(
	 -relief => 'sunken',
	  -font => 	$helv,
	  -width =>	23,
	  -variable=> \$ftphostname,
	  -browsecmd => sub{
	  			$p7user->delete(0,'end');
	  			$p7user->insert('end',$ftpaccount{$ftphostname}[0]);
	  			$p7pass->delete(0,'end');
	  			$p7pass->insert('end',$ftpaccount{$ftphostname}[1]);
	  			$p7home->delete(0,'end');
	  			$p7home->insert('end',$ftpaccount{$ftphostname}[2]);
  			},
	  )->grid(-row=>2, -column=>1,-pady=>3);
$p7user = $p7statframe->Entry(
	 -relief => 'sunken',
	 -width =>	20,
	 -font => 	$helv,
)->grid(-row=>2, -column=>2,-pady=>3);
$p7pass = $p7statframe->Entry(
	 -relief => 'sunken',
	 -width =>	20,
	 -font => 	$helv,
	 -show=>	'*',
	  )->grid(-row=>2, -column=>3,-pady=>3);
$p7home = $p7statframe->Entry(
	 -relief => 'sunken',
	 -width =>	20,
	 -font => 	$helv,
	  )->grid(-row=>2, -column=>4,-pady=>3);
foreach (keys %ftpaccount){$p7host->insert(0, $_)}
$p7user->insert(0, $ftpusername);
$p7pass->insert(0, $ftppassword);
$p7home->insert(0, $ftphome);

my $p7buttonframe = $p7frame->Frame()->pack(-side => 'top', -anchor => 'n', -pady => '2');

my $ftpcbutton = $p7buttonframe->Button(
	-command =>		\&ftpconnect,
	-text =>		'Connect',
	-width =>		'10'
)->pack(-side => 'left', -padx => '2',-pady => '4');

my $ftpdbutton = $p7buttonframe->Button(
	-command =>		\&ftpdisconnect,
	-text =>		'Disconnect',
	-width =>		'10'
)->pack(-side => 'left', -padx => '2',-pady => '4');

my $ftpslbutton = $p7buttonframe->Button(
	-command =>		\&ftpsavelog,
	-text =>		'Save Log',
	-width =>		'10'
)->pack(-side => 'left', -padx => '2',-pady => '4');

my $ftpclbutton = $p7buttonframe->Button(
	-command =>		\&ftpclearlog,
	-text =>		'Clear Log',
	-width =>		'10'
)->pack(-side => 'left', -padx => '2',-pady => '4');

my $ftphelpbutton = $p7buttonframe->Button(
	-command =>		\&ftphelp,
	-text =>		'?',
	-width =>		'2'
)->pack(-side => 'left', -padx => '2',-pady => '4');

$p7buttonframe->Checkbutton(
	-variable => 	\$opt[48],
	-selectcolor => 'white',
	-text =>	"Save User\n& Password"
)->pack(-side => 'left',-pady => '4');

$p7buttonframe->Radiobutton(
	-variable => 	\$ftpscale,
	-value=>	1024,
	-selectcolor => 'white',
	-text =>	"KiloBytes"
)->pack(-side => 'left',-pady => '4');

$p7buttonframe->Radiobutton(
	-variable => 	\$ftpscale,
	-value=>	128,
	-selectcolor => 'white',
	-text =>	"Kilobits"
)->pack(-side => 'left',-pady => '4');

my $p7logframe = $p7frame->Frame()->pack(-side => 'top', -anchor => 'n', -pady => '2');

my $ftplog = $p7logframe->Scrolled('ROText',
 	-scrollbars =>		'oe',
 	-background => 		'white',
 	-wrap => 		'word',
 	-width =>		'120',
 	-height => 		'8',
 	-font =>		$helv,
 )->pack(-side => 'top', -anchor => 'n');
BindMouseWheel($ftplog);

my $p7status = $p7logframe->ROText(
	-font =>	$helv,
	-background => 'white',
	-height =>	'1',
	-width => 	'120',
)->pack(-side => 'left', -anchor => 'n',-pady=>1);

$p7status->insert('end',"No Connection....");

 my $pbatchbutframe =  $p7frame->Frame()->pack(-side => 'top', -anchor => 'n');

 my $buildbatchbutton = $pbatchbutframe->Button(
	-command =>		\&ftpbuildbatch,
	-text =>		'Build Batch',
	-width =>		'11'
)->pack(-side => 'left', -padx => '2',-pady => '4', -anchor => 'n');

 my $addfilebutton = $pbatchbutframe->Button(
	-command =>		\&ftpaddfile,
	-text =>		'Add a File',
	-width =>		'11'
)->pack(-side => 'left', -padx => '2',-pady => '4', -anchor => 'n');

 my $zipbatchbutton = $pbatchbutframe->Button(
	-command =>		\&ftpbatchzip,
	-text =>		'Zip Batch Files',
	-width =>		'12'
)->pack(-side => 'left', -padx => '2',-pady => '4', -anchor => 'n');

my $clearbatchbutton = $pbatchbutframe->Button(
	-command =>		\&ftpclearbatch,
	-text =>		'Clear Local List',
	-width =>		'12'
)->pack(-side => 'left', -padx => '2',-pady => '4', -anchor => 'n');

my $ftpuplbutton = $pbatchbutframe->Button(
	-command =>		\&ftpupload,
	-text =>		'Send Files',
	-width =>		'11'
)->pack(-side => 'left', -padx => '2',-pady => '4', -anchor => 'n');

my $ftpstpbutton = $pbatchbutframe->Button(
	-command =>		sub {$ftpinterrupt = 1; },
	-text =>		'Stop Transfer',
	-width =>		'11'
)->pack(-side => 'left', -padx => '2',-pady => '4', -anchor => 'n');

my $ftpmkdnldbutton = $pbatchbutframe->Button(
	-command =>		\&ftpdownload,
	-text =>		'Download',
	-width =>		'11'
)->pack(-side => 'left', -padx => '2', -pady => '4', -anchor => 'n');

my $pbatchentryframe =  $p7frame->Frame()->pack(-side => 'top', -anchor => 'n',);

my $ftpmkdirbutton = $pbatchentryframe->Button(
	-command =>		\&ftpmkdir,
	-text =>		'Make New Directory',
	-width =>		'16'
)->pack(-side => 'left', -pady => '2', -anchor => 'n');

my $ftpmkdirentry = "projectID";

my $ftpmkdir = $pbatchentryframe->Entry(
	-background => 'white',
	-width => 	'30',
)->pack(-side => 'left', -anchor => 'n', -padx => '6',-pady => '6');

$ftpmkdir->insert('0',"$ftpmkdirentry");

my $ftpchdirbutton = $pbatchentryframe->Button(
	-command =>		\&ftpchdir,
	-text =>		'Chdir Sel',
	-width =>		'8'
)->pack(-side => 'left', -pady => '2', -padx => '2', -anchor => 'n');

my $ftpcdubutton = $pbatchentryframe->Button(
	-command =>		\&ftpcdup,
	-text =>		'Chdir Up',
	-width =>		'8'
)->pack(-side => 'left', -padx => '2',-pady => '2', -anchor => 'n');

my $ftprenbutton = $pbatchentryframe->Button(
	-command =>		\&ftprename,
	-text =>		'Rename',
	-width =>		'8'
)->pack(-side => 'left', -pady => '2', -padx => '2', -anchor => 'n');

 my $ftpdelbutton = $pbatchentryframe->Button(
	-command =>		\&ftpremove,
	-text =>		'Delete',
	-width =>		'8'
)->pack(-side => 'left', -pady => '2', -padx => '2', -anchor => 'n');

my $ftpcombutframe =  $p7frame->Frame()->pack(-side => 'top', -anchor => 'n',);

my $ftppwd = $ftpcombutframe->ROText(
	-background => 		'white',
	-font =>		$helv,
	-height =>		'1',
	-width => 		'70',
)->pack(-side => 'right', -anchor => 'n', -pady => '6');

my $p7dirlabel = $ftpcombutframe->Label(
	-font =>	$helv,
	-text =>	"Remote\nDirectory"
)->pack(-side => 'right', -anchor => 'n', -padx => '3',-pady => '1');

my $p7boxframe =  $p7frame->Frame()->pack(-side => 'top', -anchor => 'n', -expand=>'yes', -fill =>'both');

my $pbatchframe =  $p7boxframe->Frame()->pack(-side => 'left', -anchor => 'nw', -expand=>'yes', -fill =>'both');

my $ftpbatchbox = $pbatchframe->Scrolled('Listbox',
	-label => "Local Listing",
	-scrollbars =>		'osoe',
	-width =>		'40',
	-height =>		'12',
	-background =>		'white',
	-font =>		$helv,
	-selectmode =>		'extended'
)->pack(-side => 'top', -anchor=> 'n', -padx => '1', -pady => '1', -expand=>'yes', -fill =>'both' );
BindMouseWheel($ftpbatchbox);

my $pservlistframe =  $p7boxframe->Frame()->pack(-side => 'right', -anchor => 'ne', -expand=>'yes', -fill =>'both');

my $servlistbox = $pservlistframe->Scrolled('Listbox',
	-label => "Remote Listing.",
	-scrollbars =>		'osoe',
	-width =>		'40',
	-height =>		'12',
	-background =>		'white',
	-font =>		$helv,
	-selectmode =>		'single'
)->pack(-side => 'top', -anchor=> 'n', -padx => '1', -pady => '1', -expand=>'yes', -fill =>'both', );

BindMouseWheel($servlistbox);

$ftpbatchbox->eventAdd('<<Delfile>>' =>  '<Double-Button-2>','<Double-Button-3>');
$ftpbatchbox->bind('<<Delfile>>', sub {ftpbatchremove()});
$ftpbatchbox->eventAdd('<<open>>' =>  '<Double-Button-1>');
$ftpbatchbox->bind('<<open>>', sub { extopen()});

$servlistbox->eventAdd('<<Download>>' =>  '<Button-2>','<Button-3>');
$servlistbox->bind('<<Download>>', sub {ftpdownload()});
$servlistbox->eventAdd('<<Cd>>' =>  '<Double-Button-1>');
$servlistbox->bind('<<Cd>>', sub { ftpchdir()});
$servlistbox->eventAdd('<<Del>>' =>  '<Delete>');
$servlistbox->bind('<<Del>>', sub {ftpremove()});

###########################################################################################################
# page 8 Search & Replace.

my $p8f1 = $page8->Frame()->pack(-side => 'top', -anchor => 'n',-pady=>'2');

my $searchlabel = $p8f1->Label(
	-text =>	'Search Text',
	-width =>		'10',
)->pack(-side => 'left', -anchor => 'n', -padx => '1');

my $searchentry = $p8f1->Entry(
	-background => 'white',
	-width => 	'50',
	-font => $cour,
)->pack(-side => 'left', -anchor => 'n', -padx => '6',-pady => '4');

my $searchbutton1 = $p8f1->Button(
	-command => 		sub {$interrupt = 0; search();},
	-text =>		'Search',
	-width =>		'12'
)->pack(-side => 'left', -padx => '6', -anchor => 'n');

my $p8f01 = $page8->Frame()->pack(-side => 'top', -anchor => 'n',-pady=>'2');

my $replacelabel = $p8f01->Label(
	-text =>	'Replacement',
	-width =>		'10',
)->pack(-side => 'left', -anchor => 'n', -padx => '1');

my $replaceentry1 = $p8f01->Entry(
	-background => 'white',
	-width => 	'50',
	-font => $cour,
)->pack(-side => 'left', -anchor => 'n', -padx => '6',-pady => '4');

my $replacebutton1 = $p8f01->Button(
	-command => 		sub {$interrupt = 0; replace($replaceentry1->get);},
	-text =>		'Replace',
	-width =>		'7'
)->pack(-side => 'left', -padx => '2', -anchor => 'nw');

my $rsbutton1 = $p8f01->Button(
	-command => 		sub {$interrupt = 0; replace($replaceentry1->get); search();},
	-text =>		'R & S',
	-width =>		'7'
)->pack(-side => 'left', -padx => '2', -anchor => 'n');

my $p8f02 = $page8->Frame()->pack(-side => 'top', -anchor => 'n',-pady=>'2');

my $replacelabel2 = $p8f02->Label(
	-text =>	'Alternate 1',
	-width =>		'10',
)->pack(-side => 'left', -anchor => 'n', -padx => '1');

my $replaceentry2 = $p8f02->Entry(
	-background => 'white',
	-width => 	'50',
	-font => $cour,
)->pack(-side => 'left', -anchor => 'n', -padx => '6',-pady => '4');

my $replacebutton2 = $p8f02->Button(
	-command => 		sub {$interrupt = 0; replace($replaceentry2->get);},
	-text =>		'Replace',
	-width =>		'7'
)->pack(-side => 'left', -padx => '2', -anchor => 'nw');

my $rsbutton2 = $p8f02->Button(
	-command => 		sub {$interrupt = 0; replace($replaceentry2->get); search();},
	-text =>		'R & S',
	-width =>		'7'
)->pack(-side => 'left', -padx => '2', -anchor => 'n');

my $p8f03 = $page8->Frame()->pack(-side => 'top', -anchor => 'n',-pady=>'2');

my $replacelabel3 = $p8f03->Label(
	-text =>	'Alternate 2',
	-width =>		'10',
)->pack(-side => 'left', -anchor => 'n', -padx => '1');

my $replaceentry3 = $p8f03->Entry(
	-background => 'white',
	-width => 	'50',
	-font => $cour,
)->pack(-side => 'left', -anchor => 'n', -padx => '6',-pady => '4');

my $replacebutton3 = $p8f03->Button(
	-command => 		sub {$interrupt = 0; replace($replaceentry3->get);},
	-text =>		'Replace',
	-width =>		'7'
)->pack(-side => 'left', -padx => '2', -anchor => 'nw');

my $rsbutton3 = $p8f03->Button(
	-command => 		sub {$interrupt = 0; replace($replaceentry3->get); search();},
	-text =>		'R & S',
	-width =>		'7'
)->pack(-side => 'left', -padx => '2', -anchor => 'n');

my $p8f2 = $page8->Frame()->pack(-side => 'top', -anchor => 'n');

my $searchsavebutton = $p8f2->Button(
	-command => 		sub {$interrupt = 0; searchsave();},
	-text =>		'Save Open File',
	-width =>		'12'
)->pack(-side => 'left', -pady => '1', -padx => '2', -anchor => 'nw');

my $p8cb51 = $p8f2->Checkbutton(
	-variable => 	\$opt[51],
	-selectcolor => 'white',
	-text => 	'Case Insensitive'
)->pack(-side => 'left', -anchor => 'n', -pady => '1');

my $p8cb53 = $p8f2->Checkbutton(
	-variable => 	\$opt[62],
	-selectcolor => 'white',
	-text => 	'Whole word only'
)->pack(-side => 'left', -anchor => 'n', -pady => '1');

my $searchfile = $p8f2->ROText(
	-relief => 'flat',
	-font => '-*-Helvetica-Medium-R-Normal--*-140-*-*-*-*-*-*',
	-height => '1',
	-width => '20',
)->pack(-side => 'left', -anchor => 'n', -padx => '4', -pady => '4');

my $replaceallbutton = $p8f2->Button(
	-command => 		sub {$interrupt = 0; replaceall();},
	-text =>		'Replace All',
	-width =>		'12'
)->pack(-side => 'left', -pady => '1', -padx => '2', -anchor => 'nw');

my $p8f5 = $page8->Frame()->pack(-side => 'top', -anchor => 'n');

my $decfilebutton = $p8f5->Button(
	-command => 		sub {$filesearchindex1--; searchincdec();},
	-text =>		'<-- Previous File',
	-width =>		'14'
)->pack(-side => 'left', -pady => '4', -padx => '10', -anchor => 'n');

my $incfilebutton = $p8f5->Button(
	-command => 		sub {$filesearchindex1++; searchincdec();},
	-text =>		'Next File -->',
	-width =>		'14'
)->pack(-side => 'left', -pady => '4', -padx => '10', -anchor => 'n');

my $searchfileslist = $p8f5->BrowseEntry(
		-label => "Go to File -",
		-variable => 	\$filesearchindex1,
		-state => 	'readonly',
		-width =>	'8',
		-listwidth =>	'22',
		-browsecmd => 	\&searchincdec,
)->pack(-anchor => 'n', -side => 'left', -padx => '10', -pady => '8');

my $seefilebutton = $p8f5->Button(
	-command => 		sub {
				my $file = $searchfilelist[$filesearchindex];
				$file =~ s/(?<=\.)txt$/png/;
				$file = $pwd.$separator.$imagesdir.$separator.$file;
				&viewersel unless $viewerstart;
				ivstart($file);
				},
	-text =>		'See Image',
	-width =>		'14'
)->pack(-side => 'left', -pady => '4', -padx => '10', -anchor => 'n');

my $p8f3 = $page8->Frame()->pack(-side => 'top', -anchor => 'n',-expand =>'both', -fill => 'both');

my $displaybox = $p8f3->Scrolled('TextUndo',
	-scrollbars => 'osoe',
	-background => 'white',
	-width => 	'100',
	-font => $courl,
	-height => 	'30',
	-wrap => 	'word',
)->pack(-side => 'top', -anchor => 'n', -padx => '6',-pady => '6', -expand =>'both', -fill => 'both');
$displaybox->tagConfigure('highlight', background => 'yellow');
BindMouseWheel($displaybox);

###########################################################################################################

###########################################################################################################

$book->pack(
	 -anchor => 'nw',
	 -expand => 'both',
	 -fill => 'both',
	 -padx => 5,
	 -pady => 5,
	 -side => "top",
	 );

MainLoop;

###########################################################################################################
#Subroutines used by page 1 - Process text
###########################################################################################################

sub xrtf{
	my $amount;
	chentries(); 				# Get any changed markup from the options entry boxes
	p1log("\nExtracting markup from rtf files in textwo directory. - Please wait...\n");
	if (chdir "textwo"){
		$amount = extract();
		chdir "..";
		return 0 if $interrupt;
		p1log("\nFinished - $amount files.\n");
	}else{
		p1log("\nCan't find textwo directory.\n");

	}
	p1log("\nExtracting markup from rtf files in textw directory. - Please wait...\n");
	if (chdir "textw"){
		$amount = extract();
		chdir "..";
		return 0 if $interrupt;
		p1log("\nFinished - $amount files.\n");
	}else{
		p1log("\nCan't find textw directory.\n");
	}
}

sub dehyph{
	p1log("\nChecking which dehyphenate routine to run. - Please wait...\n");
	if (chdir "textw"){
		chdir "..";
		if (chdir "textwo"){
			chdir"..";
			dehyphen2();
		}else{
			dehyphen1();
		}
	}
}

sub filt{
	p1log("\nFiltering bad and undesirable characters. - Please wait...\n");
	if (chdir"text"){
		filter();
		chdir"..";
	}else{
		p1log("\nCan't find text directory.\n");
		return 0;
	}
}
sub nam {
	my $count;
	p1log("\nRenaming .txt files in text directory. - Please wait...\n");
	if (chdir'text'){
		$count = ren('txt','text');
		chdir"..";
	}else{
		p1log("\nCan't find text directory.\n");
		return 0;
	}
	unless($interrupt){
		p1log("\nFinished - $count files.\n");
	}
}
sub zero{
	p1log("\nChecking for and fixing empty files. - Please wait...\n");
	if (chdir"text"){
		fixempty();
		chdir"..";
	}else{
		p1log("\nCan't find text directory.\n");
		return 0;
	}
	unless($interrupt){
		p1log("\nFinished.\n");
	}
}
sub conv {
	my $count;
	p1log("\nConverting .txt files in text directory to ISO 8859-1. - Please wait...\n");
	if (chdir"text"){
		$count = convert();
		chdir"..";
	}else{
		p1log("\nCan't find text directory.\n");
		return 0;
	}
	unless($interrupt){
		p1log("\nFinished - $count files.\n");
	}
}
sub doall{
	return 0 if $interrupt;
	xrtf() if $opt[28];
	return 0 if $interrupt;
	dehyph() if $opt[29];
	return 0 if $interrupt;
	nam() if $opt[32];
	return 0 if $interrupt;
	filt() if $opt[30];
	return 0 if $interrupt;
	splchk() if $opt[31];
	return 0 if $interrupt;
	englifh() if $opt[66];
	return 0 if $interrupt;
	zero() if $opt[33];
	return 0 if $interrupt;
	conv() if $opt[74];
	pngrename() if $opt[47];
	return 0 if $interrupt;
	pngcrush() if $opt[49];
	return 0 if $interrupt;
	unless($interrupt){
		p1log("\nFinished all selected routines.\n");
	}
}

sub clear {
	$p1text->delete('1.0','end');
}

sub saveptlog{

	my $savefilename = $p1text->getSaveFile(-initialfile => "processlog.txt", -initialdir => $pwd);
	$savefilename=~ s/\//$separator/g;
	if ($savefilename ne ''){
		open (SAVE, ">$savefilename");
		print SAVE ($p1text->get('1.0','end'));
		close SAVE;
	}
}

sub break{
	$interrupt = 1;
	p1log("\nProcessing was halted\n");
}

sub pngrename{
	my $count;
	p1log("\nRenaming .png files in $imagesdir directory. - Please wait...\n");
	if (chdir"$imagesdir"){
		$count = ren('png',$imagesdir);
		chdir"..";
	}else{
		p1log("\nCan't find $imagesdir directory.\n");
		return 0;
	}
	unless($interrupt){
		p1log("\nFinished - $count files.\n");
	}
}

#######################################################################################################################
# Routine to extract italic and bold markup (primarily) from rtf files.
#
# Expects to be run in the directory that the rtf files are in. Returns the number of text files extracted.
#
sub extract {
					# Initialize and localize variables
	my ($token_type, $argument, $parameter, $italflag, $boldflag, $capsflag, $pardflag, @row, $textsz, $cellsz, $lastcell, $intable,$sub,$sup);
	my ($flag, @flag, $chnum, $chr, $space, $newline, $txtfile, $picture, $level, $shape);
	my ($fonttable,$curf,$curcpg,%fonts);
	my $extractbold = 0 unless $opt[23];
my($i);
	$extractbold = 1 if $opt[23];

	my @rtffiles = glob("*.rtf");					# Get a list of rtf files
	if (scalar @rtffiles == 0){
		p1log("\nNo rtf files found.\n");	# Let the user know that something is happening
		return 0;
	}
	my $tracker;
	foreach (@rtffiles) { 						# Step through the list
		open(RTFFILE,"<$_");					# Open the next file in the list
		my $buffer = <RTFFILE>;					# Read in a line from the file
		($txtfile = $_) =~ s/rtf$/txt/;				# Get the file name and change the extension to .txt
		open(TXTFILE, ">$txtfile");				# Open the text file for output
		$level=0;
		$pardflag=1;						# Set a variable to check for the rtf file header
		$shape=0;
		$fonttable=0;
		$curf=-1;
		$curcpg="ascii";
		%fonts=();
		p1log(++$tracker % 10);				# Let the user know that something is happening
		if ($interrupt){break(); return 0};
		while($buffer) {					# As long as there is something in the buffer
			( $token_type, $argument, $parameter ) = get_token(\$buffer);	# Get the next token, pass a pointer to the buffer
			if ($token_type eq 'eof'){ 					# If buffer is empty
				$buffer = <RTFFILE>;				# Read in a line from the file
			};
			if ($token_type eq "group" or $token_type eq "endgroup"){ 					# If the token is a group, reset all text markup
				while ($flag = pop @flag){print TXTFILE $flag; print TXTFILE (" ") if ($space); }
				 print TXTFILE ("}")if ($sub);
				 print TXTFILE ("$supclose")if ($sup);
				 $textsz++ if (($sup||$sub)&&$intable);
				$space = $italflag = $boldflag = $capsflag = $picture = $sub = $sup = $intable = 0;
				if($token_type eq "group") {
					$level++;
				} elsif($token_type eq "endgroup") {
					$level--;
					if($level<$shape) {
						$shape=0;
					}
					if($level<$fonttable) {
						$fonttable=0;
					}
				}
			};

			if($fonttable eq 0) {

			if($shape eq 0) {

			if ($token_type eq "control"){					# If the token is a control, take the appropriate action
				if ($argument eq "pard") {
						if ($pardflag) {print TXTFILE ("\n")};  # For more info about the different control tokens
					  	$pardflag=0; 				# read the help file for RTF::Tokenizer at
					  	$italflag=$boldflag=$capsflag=0;	# http:\\www.cpan.org
				}elsif ($argument eq "par")     { print TXTFILE "\n\n"; 		# Paragraph, insert 2 newlines
				}elsif ($argument eq "line")    { print TXTFILE "\n"; $space = 1; 	# New line, (soft return), insert 1 new line. Trap end of line markup spacing errors
				}elsif ($argument eq "tab")     { print TXTFILE "      ";  		# Tab, insert spaces
				}elsif ($argument eq "endash")  { print TXTFILE "-"; 			# Convert named endash to -
				}elsif ($argument eq "emdash")  { print TXTFILE "--"; 			# Convert named emdash to --
				}elsif ($argument eq "pict")    { $picture = 1; 			# Flag binary data
				}elsif ($argument eq "\\")      { print TXTFILE "\\"; 			# Convert rtf control character
				}elsif ($argument eq "\{")      { print TXTFILE "{";  			# Convert rtf control character
				}elsif ($argument eq "\}")      { print TXTFILE "}";  			# Convert rtf control character
				}elsif ($argument eq "\~")      { print TXTFILE " ";  			# Convert rtf control character
				}elsif ($argument eq "\-")      { print TXTFILE "-";  			# Convert rtf control character
				}elsif ($argument eq "f")		{
									if($fonts{$parameter}) {
										$curcpg = "cp".$fonts{$parameter};
									} else {
										$curcpg="ascii"
									}
				}elsif ($argument eq "sub")     { $sub = 1 if $opt[67];
				}elsif ($argument eq "super")   { $sup = 1 if $opt[67];
				}elsif ($argument eq "nosupersub")  {
									print TXTFILE ("}")if ($sub&&$opt[67]);
									print TXTFILE ("$supclose")if ($sup&&$opt[67]);
									$sub = $sup = 0;
				}elsif ($argument eq "intbl") { $intable = 1; print TXTFILE ('|')if $opt[61];
				}elsif ($argument eq "row")     { @row=(); print TXTFILE ("\n"); $lastcell = 0;
				}elsif ($argument eq "cellx")   {
									push @row, (int(($parameter-$lastcell)/120)+1);
									$lastcell = $parameter;
									#print "$lastcell @row\n";
				}elsif ($argument eq "cell")    {
									$cellsz = shift @row;
									print TXTFILE ("\xA0" x ($cellsz-$textsz-1));
									#print "$cellsz $textsz\n";
									$textsz = 0;
									$intable = 0;

				}elsif ($argument eq "i" )      { 	if ($parameter eq "0" ) { 	# Italics markup
										if  ($italflag) {
											print TXTFILE $italicsclose;
											pop @flag;
											print TXTFILE (" ") if ($space);
											$space = $italflag = 0;
										}
									} else {
										unless($italflag || $pardflag){
											print TXTFILE $italicsopen;
											$italflag=1; $space = 0;
											push @flag,$italicsclose;
										}
									}
				}elsif ($argument eq "b" )      { 	if ($parameter eq "0" ){	# Bold markup
										if  ($boldflag) {
											print TXTFILE $boldclose;
											pop @flag;
											print TXTFILE (" ") if ($space);
											$space = $boldflag = 0;
										}
									} else {
										if ($extractbold) {
											unless($boldflag || $pardflag){
												print TXTFILE $boldopen;
												$boldflag=1; $space = 0;
												push @flag,$boldclose;
											}
										}
									}
				}elsif ($argument eq "scaps" )  { 	if ($parameter eq "0" ){	# Small caps markup
										if ($capsflag and $opt[78]){
											print TXTFILE '</sc>';
											pop @flag;
										}
										$capsflag = 0;
									} else {
										if ($opt[78]) {
											unless($capsflag || $pardflag){
												print TXTFILE '<sc>';
												push @flag,'</sc>';
											}
										}
										$capsflag = 1;
									}

				}elsif ($argument eq "u")       {
									my $unicode = chr($parameter);
									utf8::encode $unicode;
									print TXTFILE $unicode;	# unicode

				}elsif ($argument eq "cf")       {
									#print TXTFILE "\x8d";	# unknown character from ABBYY

				}elsif ($argument eq "'" )      {	#hex encoded characters
									next if ($parameter eq '3f');	# Throw away hex question marks. Abbyy adds one after EVERY unicode char. :-(
									$chnum = hex($parameter);	# Handle characters > 128
									$chr=pack('C',$chnum);
									Encode::from_to($chr,$curcpg,"utf-8");
									print TXTFILE $chr;
				}elsif ($argument eq "shp")       {
									$shape=$level;
				}elsif ($argument eq "fonttbl")       {
									$fonttable=$level;
				}
			}
			if ($token_type eq "text"){				# The token is text.
				unless($pardflag || $picture) {			# Print it to the output file if we are through the header.
					if ($sub){$argument = '_{'.$argument};
					if ($sup){$argument = $supopen.$argument};
					if ($intable){
						$textsz += length($argument);
						$argument =~ s/ /\xA0/g;
					};
					if($capsflag and !$opt[78]){
						print TXTFILE (uc($argument));
					}else{
						print TXTFILE ($argument);
					};
				};
			};
		}; #shape

		}else { #fonttable
			if($argument eq "f") {
				$curf=$parameter;
			}elsif($argument eq "cpg") {
				$fonts{$curf}=$parameter;
			};
		};

		};

		$pardflag=0;		# Clean up variables and file handles for next file
		$parameter=99;
		$token_type="";
		$level=0;
		$shape=0;
		$fonttable=0;
		close(TXTFILE);
		close(RTFFILE);
	};
	return(scalar @rtffiles);
};

###################################################################################################
# Relevant subroutines ripped from RTF::Tokenizer perl module and modified to work standalone.
#
# RTF::Tokenizer originally written by Peter Sergeant <rtft@clueball.com>

sub get_token {
	my $self = shift;

	my $start_character = substr( ${$self}, 0, 1, '' );

	# Most likely to be text, so we check for that first
	if ( $start_character =~ /[^\\}\r\n\t{]/ ) {
		local($^W); # Turn off warnings here
		${$self} =~ s/^([^\{\}\\\n\r]+)//;
		return( 'text', $start_character . $1, '' );

	# Second most likely to be a control character
	} elsif ( $start_character eq "\\" ) {
		return( 'control', grab_control($self) );

	# Probably a group then
	} elsif ( $start_character eq "{" ) {
		return( 'group', 1, '');

	} elsif ( $start_character eq "}" ) {
    		return( 'endgroup', 0, '');

	} elsif ( $start_character eq "\n" ) {
		return( 'eof', 1, 0 )
	}
}

sub grab_control {

	my $self = shift;

	# Some handler for \bin here, when I work it out
	if ( ${$self} =~ s/^\*// ) {
		return( '*','');

	# Unicode characters
	} elsif ( ${$self} =~ s/^u(\d+)\??// ) {
		return( 'u', $1 );

	# An honest-to-god standard control word:
	} elsif ( ${$self} =~ s/^([a-z]{1,32})((?:\d+|-\d+))?(?:[ ]|(?=[^a-z0-9]))//i ) {
			my $param = ''; $param = $2 if defined($2);
			return( $1, $param ) unless $1 eq 'bin';
			# Binary data or uc

	# hex-dec character
	} elsif ( ${$self} =~ s/^'([0-9abcdef][0-9abcdef])//i ) {
		return( "'", $1 );

	# Control symbol
	} elsif ( ${$self} =~ s/^([-_~:|{}*\'\\\\])// ) {
		return( $1, '' );

	# Anything else we can't identify, discard, for the purposes of this script
	} else {
		return( '', 0 );
	}
}
##########################################################################################################

##########################################################################################################
# Dehyphenate subroutine that doesn't require two sets of files

sub dehyphen1{
	my ($match, $line, $list);
	my $filenames = '*.txt';

	p1log("\nDehyphenating single set of files in \"textw\" into \"text\" directory.\n\nBuilding dictionary. Please wait...\n");

	loaddic() if (-e "$startdir/nohyph.dict"); # If nohyph.dict exists, add the words to the dehyphenization dictionary

	chdir"textw";
	my @listing = glob($filenames);						# Get a list of files
	foreach $list(@listing) {						# Step though the file list
		my $lastLineEndedWithHyphen;
		open(TXT, '<', $list);
		while ($line = <TXT>) {						# Get a line of text
			utf8::decode($line);
			while ($line =~ /(\p{Alpha}+['\p{Alpha}]*?\p{Alpha})(?=\W|$)(?!$hyphen\s*$)/g) { # Take each word on the line
				unless ($lastLineEndedWithHyphen) {
					$match = $1;
      	 				$seen{$match}++;			# and make a new hash key or increment it if already exists
				}
				 $lastLineEndedWithHyphen = 0;
      	 		}							# in other words, build a list of all of the non hyphenated words in the file
			if ( $line =~ /-\s*$/ ) {
				$lastLineEndedWithHyphen = 1;
			}
		}
		close TXT;
	}
	chdir"..";
	dehyphen();
}

##########################################################################################################
# Dehyphenate subroutine that uses two sets of files

sub dehyphen2{
	my ($match, $line, $list);
	my $filenames = '*.txt';

	p1log("\nDehyphenating files in \"textw\" and \"textwo\" into \"text\" directory.\n\nBuilding dictionary. Please wait...\n");

	loaddic() if (-e "$startdir/nohyph.dict"); # If nohyph.dict exists, add the words to the dehyphenization dictionary

	chdir"textwo";
	my @listing = glob($filenames);						# Get a list of files
	foreach $list(@listing) {						# Step though the file list
		open(TXT, "<$list");
		while ($line = <TXT>) {						# Get a line of text
			utf8::decode($line);
			while ($line =~ /(\p{Alpha}+['\p{Alpha}]*?\p{Alpha})/g ) { 	# Take each word on the line
				$match = $1;
      	 			$seen{$match}++;				# and make a new hash key or increment it if already exists
      	 		}							# in other words, build a list of all of the non hyphenated words in the file
		}
		close TXT;
	}
	chdir"..";
	dehyphen();
}
##########################################################################################################
sub loaddic{
	open my $txt, '<', "$startdir/nohyph.dict";
	while(<$txt>) {
		utf8::decode($_);
		while (/(\p{Alpha}+['\p{Alpha}]*?\p{Alpha})/g) { # Take each word on the line
      			$seen{$1}++;				# and make a new hash key or increment it if already exists
      		}
      	}
}
##########################################################################################################
sub dehyphen{
	my ($file, $thisline, $nextline, $list) ;
	my ($word, $startword, $endword, $punct);
	my $filenames = "*.txt";
	p1log("Checking if \"text\" directory exists...\n");
	if (opendir(DIR,"text")) {
		closedir(DIR);
		p1log("Directory exists, clearing out all text files...\n");
		cleardir();
	}else{
		p1log("Creating directory...\n");
		mkdir ("text",0777)
	};			# Make a "text" directory to hold output unless it already exists
	if ($hyphen eq "="){p1log("Dehyphenating using German style hyphens =.\n")}
	chdir"textw";
	my @listing = glob($filenames);
	chdir"..";
	if ($debug){
		open (WORDFILE, ">words.txt");
		print WORDFILE join ("\n", sort keys %seen);
		close WORDFILE;
	}

	p1log("Dehyphenating text files...\n");
	open (HYFILE, ">hyphens.txt") if $opt[77];
	open (NOHYFILE, ">dehyphen.txt")if $opt[77];
	my $tracker;
	foreach $list(@listing) {
		local($^W); 							# Turn off warnings locally
		open (INFILE, "<textw/$list");					# Open a file of the non breaking text.
		open (OUTFILE, ">text/$list");				 	# Open a file to write changes to.
		p1log(++$tracker % 10);
		$thisline = <INFILE>;
		utf8::decode($thisline);
		$thisline =~ s/[\x96\xAD]/-/g;					# Convert ndash or nonbreaking dash to regular dash
		$thisline =~ s/\x97/--/g;					# Convert mdash to two regular dashes
		while ($nextline = <INFILE>){
			utf8::decode($nextline);
			$thisline =~ s/ $//g;
			$nextline =~ s/[\x96\xAD\x{2010}\x{2011}]/-/g;		# Convert ndash or nonbreaking dash to regular dash
			$nextline =~ s/[\x97\x{2012}\x{2013}\x{2014}\x{2015}]/--/g;	# Convert mdash to two regular dashes

			if ($thisline =~ /$hyphen$/){
				if ($thisline =~ /(\w[\w']*?)($hyphen$)/){		# Search for lines ending with a hyphen
					$endword = $1}
				if ($thisline =~ /(\w[\w']*?) ($hyphen$)/){		# or a spaced hyphen
					$endword = "$1 "}
				if ($nextline =~ /^([$hyphen\w'<]+\w*)([^\p{IsSpace}]*)/){	# and get the the first word or part word from the next line
					$startword = $1;
					$punct = $2;
				}else{
					$startword = $hyphen;
				}
				if ($endword){$word = $endword.$startword	# speculatively join the two word segments
				}else{$word = ''};
									# check to see if the speculative word  is in the dictionary or if one of the halves is
									# a common prefix or suffix
				if ((exists($seen{$word}))||($startword =~ /^\b[\w]?ing[s]?/)||($startword =~/^\b[ts]ion[s]?/)||($startword =~/^\best[s]?/)||
				($startword =~/^\b[dt]?ed/)||($startword =~/^\b[\w]?ly/)||($startword =~ /^\ber[s]?/)||($startword =~/^\b[mst]?ent[s]?/)||($startword =~/^\b[\w]?ie[s]?/)||
				($startword eq 'ness')||($endword eq 'con')||($endword eq 'ad')||($endword eq 'as')||($endword eq 'en')||($endword eq 'un')||($endword eq 're')||($endword eq 'de')||($endword eq 'im')) {
					$thisline =~ s/[\w']*?$hyphen$/$word$punct/;		#if so, save it and move any punctuation up to the previous line
					if ($opt[77]){print NOHYFILE "$word \t$list  1\n" unless ($word eq $hyphen)};
				}elsif($startword eq $hyphen){
				# hmmmm.. there wasn't a word entity starting the next line. better leave it alone.
					$thisline =~ s/[\w']*?$hyphen$/$endword$hyphen/;
				}elsif( $startword =~ /^[A-Z]|^[0-9]/ ) {
					# if the startword starts with a Capital letter or a number, leave the hyphen
					$thisline =~ s/[\w']*?( ?)$hyphen$/$endword$hyphen$1$startword$punct/;
					print HYFILE "$endword$hyphen$1$startword \t$list  2\n" if $opt[77];
				}elsif( exists($seen{$startword}) || (exists($seen{$endword})&&( ($endword ne 'as')&&($endword ne 'be')&&($endword ne 'in')&&($endword ne 'on')) ) ){
					$thisline =~ s/[\w']*?( ?)$hyphen$/$endword$hyphen$1$startword$punct/;
					print HYFILE "$endword$hyphen$1$startword \t$list  3  $word\n" if $opt[77];
				}else {							# Word not found in dictionary or prefix/suffix list? leave the hyphen but move it up
					$thisline =~ s/$endword$hyphen$/$endword$startword$punct/;
					print NOHYFILE "$endword$startword \t$list  4\n" if $opt[77];
				}

                          $nextline =~ s/^([$hyphen\w'<]+\w*)([^\p{IsSpace}]*)\s*//; 	#clean up the word half from the next line
			  $startword = $endword = $punct = '';
			}
		  utf8::encode $thisline;
		  print OUTFILE $thisline;						# save the line
		  $thisline = $nextline;						# move the line up
		}
		utf8::encode $thisline;
		print OUTFILE $thisline;
		close OUTFILE;
		close INFILE;
		if ($interrupt){break(); return 0};
	}
	p1log("\nFinished.\n");
	close NOHYFILE if $opt[77];
	close HYFILE if $opt[77];
	%seen = ();
}
##########################################################################################################
# Clean text files out of directory

sub cleardir{
	my $file;
	chdir"text";
	my @list = glob("*.txt");
	foreach $file(@list){unlink $file}
	chdir"..";
}

##########################################################################################################

##########################################################################################################
# Zero byte file cleanup. Expects to run in the directory
#

sub fixempty{
	my $file;
	my $size;
	my @listing = glob("*.txt");				# Get a list of text files.
	my $tracker;
	foreach $file(@listing) {				# Step through the list.
		p1log(++$tracker % 10);			# Let the user know that something is happening
		if ($interrupt){break(); return 0};
		if (-z $file) {
			open (OUTFILE, ">>$file");		# Handle the zero byte files
			print OUTFILE $zerobytetext;
			close (OUTFILE);
			p1log("\n$file was zero bytes.\n"); 	# Warn the user about zero byte files
	 	}
	 	 $size += (-s $file); # Gets file size (post zero length fix)  and counts total size
	}
	if ((scalar @listing) > 0) {p1log("\nAverage file size - ".int($size / scalar @listing) ." bytes.\n");}; #
}
##################################################################################################################

##################################################################################################################
# Filter out undesirable characters / combinations
#

sub filter {
	my ($line, $linecount, $tempstring, $newlines, $endlines, $pageno, $index, $file);
	my ($regi, $regb, %fixup, $key, $value,$temp);
	my $impossibles = 0;
	$regi = $italicsopen . $italicsclose;		# Build markup matching pattern
	$regb = $boldopen . $boldclose;			# Build markup matching patter
	my @listing = glob("*.txt");			# Get a list of text files.
	my $tracker;
	foreach $file(@listing) {			# Step through the list.
		p1log(++$tracker % 10);		# Let the user know that something is happening
		if ($interrupt){break(); return 0};
		open(OLD, "<$file");       		# Open the next file for reading
		open(NEW, ">temp");			# Open a temp file for writing
		$linecount = $newlines = $endlines = $linelength = 0; # Clear out some variables
		$pageno = "";
		while ($line = <OLD>) {			# Read a line from the file  while there are any lines left
			$linecount++;
			utf8::decode($line);

##### Pre-processing only! Use with care after proofing! #################################################################
			$linelength = length($line) if (length($line)> $linelength);  # for short last line check

			$line =~ s/\s{3,}[\p{Punct}\s]+$// if $opt[75];

	  if ($opt[76]){          # dubious first character in line
		       $line =~ s/^[\^_](?!\{)//;
			$line =~ s/^([\^_]\{)/ $1/;
			$line =~ s/^\p{Punct}+(\p{Punct})/$1/;
			$line =~ s/^ ([\^_]\{)/$1/;
		   };
			$line =~ s/  / /g if $opt[0];			# Get rid of extra spaces
			$line =~ s/\s(["'])\s(\p{Alpha}+)\s\1 / \1\2\1 /g;
			$line =~ s/^(\s*)(\p{IsUpper}+)(\s\p{IsLower}+)/\1\u\L\2\E\3/ if $linecount < 7;
			$line =~ s/Ѓ([\d,]*\d)(\D)/$1 Pounds $2/g if $opt[38];# Convert Ѓ to Pounds intelligently
			$line =~ s/(?<![ainu])j(?=\s)/;/g if $opt[46];	# Convert solitary j or at end of word (unless it follows a i n or u) to semicolon
                        if ($opt[50]){	# Convert Windows codepage 1252 glyphs 80-9F to Latin1 equivalents
			           $line =~ s/\x82/'/g;
			           $line =~ s/\x83/f/g;
			           $line =~ s/\x84/"/g;
			           $line =~ s/\x85/\.\.\./g;
			           $line =~ s/\x86/\*/g;
			           $line =~ s/\x87/\*\*/g;
			           $line =~ s/\x88/^/g;
			           $line =~ s/\x89/0\/00/g;
			           $line =~ s/\x8A/S/g;
			           $line =~ s/\x8B/'/g;
		                   $line =~ s/\x8C/OE/g;
			           $line =~ s/\x8E/Z/g;
			           $line =~ s/\x91/'/g;
			           $line =~ s/\x92/'/g;
			           $line =~ s/\x93/"/g;
			           $line =~ s/\x94/"/g;
			           $line =~ s/\x95/\*/g;
			           $line =~ s/\x98/\~/g;
			           $line =~ s/\x99/TM/g;
			           $line =~ s/\x9A/s/g;
			           $line =~ s/\x9B/'/g;
			           $line =~ s/\x9C/oe/g;
			           $line =~ s/\x9E/z/g;
				   }
			$line =~ s/[\x96\xAD\x{2010}\x{2011}]/-/g;		#Convert ASCII and unicode dashes and hyphens to std DP format.
			$line =~ s/[\x97\x{2012}\x{2013}\x{2014}\x{2015}]/--/g;	# these will cause all kinds of grief if left untrapped
			$line =~ s/,,/"/g if $opt[60];			# Convert double commas to a Double quote
			$line =~ s/__/--/g if $opt[42];			# Convert multiple consecutive underscores to em dash
			$line =~ s/ -$/--/g if $opt[36];		# Convert unlikly hyphens to em dashes
			$line =~ s/ - /--/g if $opt[36];		# Convert unlikly hyphens to em dashes
			$line =~ s/ ?- ?/-/g if $opt[2];		# Get rid of spaces on either side of hyphens
			$line =~ s/ ?-- ?/--/g if $opt[3];		# Get rid of spaces on either side of emdashes
			$line =~ s/ \./\./g if $opt[4];			# Get rid of space before periods
			$line =~ s/ \?/\?/g if $opt[6];  		# Get rid of space before question marks
			$line =~ s/ \;/\;/g if $opt[7];			# Get rid of space before semicolons
			$line =~ s/ :/:/g if $opt[7];			# Get rid of space before colons
			$line =~ s/ ,/,/g if $opt[8];    		# Get rid of space before commas			$line =~ s/(?<=(\(|\{|\[)) //g if $opt[41];	# Get rid of space after opening brackets
			$line =~ s/ (?=(\)|\}|\]))//g if $opt[41];	# Get rid of space before closing brackets
			$line =~ s/(?<!\.)\.{3}(?!\.)/ \.\.\./g if $opt[9]; # Insert a space before an ellipsis except after a period
			$line =~ s/(?<!(\W))\/(?=\W)/,'/g if $opt[45];	# Convert forward slash to comma apostrophe
			$line =~ s/''/"/g if $opt[10];		# Convert 2 single quotes to 1 double quote
			$line =~ s/(?<=['" ])1\b(?!\.)/I/g if $opt[12];	# Convert a solitary 1 to I if proceeded by ' or " or space

                        $line =~ s/(?<=['" ])l\b(?!')/I/g if $opt[37];	# Convert a solitary l to I if proceeded by ' or " or space
                        $line =~ s/(?<=['" ])l'(?![a-zA-ZР-жи-іј-џ])/I'/g if $opt[37];  # but not if foillowed by '[text] (common in French)


			$line =~ s/(?<=[\n'" ])0\b/O/g if $opt[13];	# Convert a solitary 0 to O if proceeded by ' or "
			$line =~ s/М/ 1\/4 /g if $opt[14];		# Convert vulgar 1/4 to written out
			$line =~ s/Н/ 1\/2 /g if $opt[14];		# Convert vulgar 1/2 to written out
			$line =~ s/О/ 3\/4 /g if $opt[14];		# Convert vulgar 3/4 to written out
			$line =~ s/А/ degrees /g if $opt[24];		# Convert degree symbol to written
			$line =~ s/ 1Ђ/ 1 cent/g if $opt[39];		# Convert Ђ to cents intelligently
			$line =~ s/Ђ/ cents/g if $opt[39];		# Convert Ђ to cents intelligently
			$line =~ s/Ї/Section/g if $opt[40];		# Convert Ї to Section
			$line =~ s/В/\^2/g if $opt[15];			# Convert superscript 2 to ^2
			$line =~ s/Г/\^3/g if $opt[15];			# Convert superscript 3 to ^3
			$line =~ s/(?<=')\/\/(?=\W)/ll/g if $opt[45]; 	# Convert double forward slash
			$line =~ s/\\v/w/g if $opt[59]; 		# Convert backslash v to w
			$line =~ s/\\\\/w/g if $opt[59]; 		# Convert double backslash to w
			if ($opt[16]){while($line =~ s/(?<=\b)tli(\w*)/th$1/){push @{$fixup{$file}},"tli$1 to th$1";$impossibles++;}};# Convert tli at the beginning of a word to th
			if ($opt[16]){while($line =~ s/(?<=\b)Tli(\w*)/Th$1/){push @{$fixup{$file}},"Tli$1 to Th$1";$impossibles++;}};# Convert Tli at the beginning of a word to Th
			if ($opt[11]){while($line =~ s/(?<=\b)tii(\w*)/th$1/){push @{$fixup{$file}},"tii$1 to th$1";$impossibles++;}};# Convert tii at the beginning of a word to th
			if ($opt[11]){while($line =~ s/(?<=\b)Tii(\w*)/Th$1/){push @{$fixup{$file}},"Tii$1 to Th$1";$impossibles++;}};# Convert Tii at the beginning of a word to Th
			if ($opt[17]){while($line =~ s/(?<=\b)rn(\w*)/m$1/){push @{$fixup{$file}},"rn$1 to m$1";$impossibles++;}};	# Convert rn at the beginning of a word to m

	     if ($opt[25]){    #convert tb -> th
                  while($line =~ s/(?<=\b)tb(\w*)/th$1/){ #at beginning of word
                       push @{$fixup{$file}},"tb$1 to th$1";
                       $impossibles++;}
 		  while($line =~ s/(?<=\b)(\w*)tb$/$1th/){ #at the end of a word
                       push @{$fixup{$file}},"$1tb to $1th";
                       $impossibles++;};
	          while($line =~ s/(?<=\b)Tb(\w*)/Th$1/){ #Tb at the beginning of a word
                       push @{$fixup{$file}},"Tb$1 to Th$1";
                       $impossibles++;}
                  };
			if ($opt[26]){while($line =~ s/(?<=\b)wli(\w*)/wh$1/){push @{$fixup{$file}},"wli$1 to wh$1";$impossibles++;}};# Convert wli at the beginning of a word to wh
			if ($opt[26]){while($line =~ s/(?<=\b)Wli(\w*)/Wh$1/){push @{$fixup{$file}},"Wli$1 to Wh$1";$impossibles++;}};# Convert Wli at the beginning of a word to Wh
			if ($opt[27]){while($line =~ s/(?<=\b)wb(\w*)/wh$1/){push @{$fixup{$file}},"wb$1 to wh$1";$impossibles++;}};	# Convert wb at the beginning of a word to wh
			if ($opt[27]){while($line =~ s/(?<=\b)Wb(\w*)/Wh$1/){push @{$fixup{$file}},"Wb$1 to Wh$1";$impossibles++;}};	# Convert Wb at the beginning of a word to Wh
			if ($opt[34]){while($line =~ s/(?<=\b)hl(\w*)/bl$1/){push @{$fixup{$file}},"hl$1 to bl$1";$impossibles++;}};	# Convert hl at the beginning of a word to bl
			if ($opt[35]){while($line =~ s/(?<=\b)hr(\w*)/br$1/){push @{$fixup{$file}},"hr$1 to br$1";$impossibles++;}};	# Convert hr at the beginning of a word to br
			if ($opt[68]){while($line =~ s/(?<=\b)VV(\w*)/W$1/){push @{$fixup{$file}},"VV$1 to W$1";$impossibles++;}};	# Convert vv at the beginning of a word to W
			if ($opt[68]){while($line =~ s/(?<=\b)[vV]{2}(\w*)/w$1/){push @{$fixup{$file}},"vv$1 to w$1";$impossibles++;}};	# Convert vv at the beginning of a word to W
			if ($opt[69]){while($line =~ s/\!\!(\w+)/H$1/){push @{$fixup{$file}},"!!$1 to H$1";$impossibles++;}};	# Convert !! at the beginning of a word to H
			if ($opt[70]){while($line =~ s/(?<=\b)X([^eEIVXDLMC\s-]\w*)/N$1/){push @{$fixup{$file}},"X$1 to N$1";$impossibles++;}};	# Convert X at the beginning of a word not followed by e to N
			if ($opt[71]){while($line =~ s/(\w+)\!(\w+)/$1l$2/){push @{$fixup{$file}},"$1!$2 to $1l$2";$impossibles++;}};	# Convert ! in the middle of a word to l
			if ($opt[72]){          	# Convert !! to  ll
                                      while($line =~ s/[(\w*)| ]'11\b/$1'll/){
                                          push @{$fixup{$file}},"$1'11 to $1'll";
                                          $impossibles++;
                                          }
                                     }
                         if ($opt[81]){                 #convert '11 to 'll  space before 'll
                                      while($line =~ s/'11/'ll/){
                                              push @{$fixup{$file}},"'11 converted to 'll";
				              }
                                      }


                        if ($opt[80]){      #remove spaces from apostrophe'd words...
                                      $line =~ s/ 'll/'ll/g;
                                      $line =~s/\bI\s'm\b/I'm/g;
                                      $line =~ s/\bhe\s's\b/he's/g;
                                      $line =~ s/\bHe\s's\b/He's/g;
                                      $line =~ s/\bshe\s's\b/she's/g;
                                      $line =~ s/\bShe\s's\b/She's/g;
                                      $line =~ s/\bwe\s'll\b/we'll/g;
                                      $line =~ s/ n't\b/n't/g;
                                      $line =~s/\bI\s'll\b/I'll/g;
                                      $line =~s/\bI\s've\b/I've/g;
                                      $line =~s/\bI\s's\b\b/I's/g;
                                      $line =~s/\bI\s'd\b/\bI'd/g;
                                      $line =~s/\s've\b/'ve/g;
                                     }

if ($opt[82]){        #remove extra spaces from quotes
              $line =~ s/^" /"/;  # start of line doublequote	      
              $line =~ s/ "$/"/;  #  end of line doublequote
              $line =~s/\s"-/"-/g;
              $line =~s/the\s"\s/the\s"/g;
              $line =~s/([.,!]) (["'] )/$1$2/g;      # punctuation, space, quote, space
              $line =~s/(\s["']\s)/$1\[*double spaced quote?]/g; #mark if unresolvable
             }

if ($opt[83]){    # mark potential missing space between words 
               $line =~s/([a-z][?!,;\.])([a-zA-Z])/$1\[\*Missing space?\]$2/g;
              }

		if ($opt[43]){while($line =~ s/(\w*?)rnp(\w*)/$1mp$2/){push @{$fixup{$file}},"$1rnp$2 to $1mp$2";$impossibles++;};# Convert rnp in a word to mp
				while ($line =~ s/([tT])umpike/$1urnpike/){pop @ {$fixup{$file}};$impossibles--}};

       if ($opt[55]){# Convert cb in a word to ch
	   while($line =~ s/(\w*)cb\b/$1ch/){
                     push @{$fixup{$file}},"$1cb to $1ch";
                     $impossibles++;
		 };
	   while($line =~ s/\bcb(\w*)/ch$1/){
                     push @{$fixup{$file}},"cb$1 to ch$1";
                     $impossibles++;
                 };
           };
			if ($opt[56]){while($line =~ s/(\w*?)gbt(\w*)/$1ght$2/){push @{$fixup{$file}},"$1gbtp$2 to $1ght$2";$impossibles++;}};# Convert gbt in a word to ght
			if ($opt[64]){while($line =~ s/(\w*?)pbt(\w*)/$1pht$2/){push @{$fixup{$file}},"$1pbtp$2 to $1pht$2";$impossibles++;}};# Convert pbt in a word to pht
			if ($opt[65]){while($line =~ s/(\w*?)mrn(\w*)/$1mm$2/){push @{$fixup{$file}},"$1mrn$2 to $1mm$2";$impossibles++;}};# Convert mrn in a word to mm
			if ($opt[57]){while($line =~ s/(\w*?)([ai])hle(\w*)/$1$2ble$3/){push @{$fixup{$file}},"$1$2hle$3 to $1$2ble$3";$impossibles++;}};# Convert [ai]hle in a word to [ai]ble
			if ($opt[63]){while($line =~ s/(\w*?)cl(?=\b)/$1d/){push @{$fixup{$file}},"$1cl to $1d";$impossibles++;}};	# Convert cl at the end of a word to d
			if ($opt[58]){while($line =~ s/\bto he\b/to be/){push @{$fixup{$file}},"\"to he\" to \"to be\"";$impossibles++;}};# Convert to he to to be
			$line =~ s/([?!]) "/$1"/g;
			$line =~ s/ !/!/g if $opt[5];  							# Get rid of space before exclamation points
 			$line =~ s/ $// if $opt[1];							# Get rid of spaces at end of line

                        if ($opt[79]){           # remove HTML markup if required-- done before any other markup operation)
                                    $line =~ s/$italicsopen//g;
                                    $line =~ s/$italicsclose//g;
                                    $line =~ s/$boldopen//g;
                                    $line =~ s/$boldclose//g;
                                    $line =~s/<\/sc>//g;
                                    $line =~s/<sc>//g;
                                   }
 			$line =~ s/(\p{Punct}+)(<\/sc>)/$2$1/g if $opt[78];				# Move punctuation outside of markup
			$line =~ s/ $italicsclose/$italicsclose/g;					# Close up spaces in markup
			$line =~ s/$italicsclose(\p{Alpha})/$italicsclose $1/g;				# Close up spaces in markup
			$line =~ s/([\p{Alpha}>])([^\p{Alpha}>]+?)($italicsclose)/$1$3$2/g if $opt[44];	# Move punctuation outside of markup
			$line =~ s/(?<= )(\p{Alpha}*?)(\P{Alpha}+?)$italicsclose/$1$italicsclose$2/g if $opt[44];	# Move punctuation outside of markup
			$line =~ s/($italicsopen)(['"])/$2$1/g if $opt[44];				# Move punctuation outside of markup
			$line =~ s/ $boldclose/$boldclose/g;						# Close up spaces in markup
			$line =~ s/([\p{Alpha}>])([^\p{Alpha}>]+?)($boldclose)/$1$3$2/g if $opt[44];	# Move punctuation outside of markup
			$line =~ s/(?<= )(\p{Alpha}*?)(\P{Alpha}+?)$boldclose/$1$boldclose$2/g if $opt[44];	# Move punctuation outside of markup
			$line =~ s/($boldopen)(['"])/$2$1/g if $opt[44];				# Move punctuation outside of markup
			$line =~ s/$boldclose$italicsclose/$italicsclose$boldclose/g;			# Fix nested markup
			$line =~ s/$regi|$regb//g; 							# Get rid of empty markup
			$line =~ s/  / /g if $opt[0];							# Final clean up of extra spaces **Duplicate but necessary**
			$line =~ s/\xA0/ /g;								# Convert nonbreaking spaces to regular spaces, needs to be last to preserve table layouts

######################################################################################################################

			if ($linecount==1 && $line eq "\n"){if ($opt[18]) {$linecount = 0}else {print NEW $line}#Remove empty lines from the top of the file
			}elsif ($linecount==1 && ($line =~ /^\d+?$/ || $line =~ /^$gboldopen\d+?$gboldclose$/ || $line =~ /^$gitalicsopen\d+?$gitalicsclose$/) && $pageno eq "") {
				if ($opt[20]) {$linecount = 0}else{print NEW $line}			#If top line has nothing but digits, remove it
			}elsif ($linecount > 1 && $line eq "\n" && $pageno eq "") {$newlines++; 	# Track empty newlines (before a possible page number)
			}elsif ($linecount > 2 && $line eq "\n" && $pageno ne "") {$endlines++ if ($opt[22]);	# Track empty newlines after page number
			}elsif ($linecount > 2 && ($line =~ /^\d+?$/ || $line =~ /^$gboldopen\d+?$gboldclose$/ || $line =~ /^$gitalicsopen\d+?$gitalicsclose$/) && $pageno eq "") {
				if ($opt[21]){$pageno = $line}else{print NEW $line} 			# If line has nothing but digits, track it
			}else {										# More text so:
				for ($index = $newlines; $index > 0; $index--) {print NEW "\n" unless $opt[19]};# Print tracked newlines or
				print NEW "\n" if $newlines && $opt[19];				# just one if thats your preference
				print NEW ("$pageno");							# Must not have been page number so print it
				for ($index = $endlines; $index > 0; $index--) {print NEW "\n" unless $opt[19]};# Print newlines after, too
				print NEW "\n" if $endlines && $opt[19];				# or just one if thats your preference
				utf8::encode $line;
				print NEW $line; 							# Print the text
				$newlines = $endlines = 0;						# and clear the tracking variables
				$pageno = "";
			}
		}
		close(OLD);  									# Clean up file handles
		close(NEW);
		unlink $file;									# Delete file
		rename("temp", $file);
		{
			local(*INPUT, $/);
			open (INPUT, "$file");
			$line = <INPUT>;
		}
		utf8::decode($line);

  if ($opt[78]){	            # Close up spaces in markup
		$line =~ s/(\s+)(<\/sc>)/$2$1/g;
 		$line =~ s/(<sc>)(\s+)/$2$1/g;
 		$line =~ s/(\p{Punct}+)(<\/sc>)/$2$1/g; # Move punctuation outside of markup
             }

		$line =~ s/ *?\n(<\/[IiBb]>) ?/$1\n/g;		# fix up any ending markup at the beginning of a line.
		for my $abbr('e.g', 'i.e', 'ibid', 'etc','loc', 'cit', 'Ib', 'cf', 'op', 'et seq'){
			$line =~ s/<i>(\Q$abbr\E)<\/i>\./<i>$1.<\/i>/ig;
		}
		open(NEW, ">temp");
		utf8::encode $line;
		print NEW $line;
		close NEW;
		unlink $file;									# Delete file
		rename("temp", $file);
	}											# Rename temporary file to filename
	unless($interrupt){
		p1log("\nFinished. $impossibles unlikely letter combination".(($impossibles != 1) ?"s":"")." changed:\n");
		foreach $key (sort keys %fixup){				# Scroll if necessary
			p1log("\nIn File $key, ".(scalar @{$fixup{$key}})." replacement".((scalar @{$fixup{$key}})>1 ? "s were made. - Changed:\n" : " was made. - Changed:\n"));
			foreach $value(@{$fixup{$key}}){
				p1log("$value;\n");
			}
 		}
	}
}
##########################################################################################################

##########################################################################################################
# A basic file renamer
# The glob function has sort semantics built in to it so sort is not necessary
# with grythumn's (partial) fix for directory lock problems, avoiding renaming directories

sub ren {
	my ($extension,$directory) = @_;
	chdir'..';
	my $tempdir = time;
	# rename $directory,$tempdir;
	mkdir ($tempdir,0777);
	chdir $directory;
	my ($list, $newname);
	my $filecnt = $startrnm; 						#Initialize and localize some variables
	my @listing = glob("*.$extension");					# Get a list of files in the current directory.
	my $fnumber = $#listing + $startrnm;
	$fnumber = 1000 if (length($startrnm) > 3);
	unless (scalar @listing){
		p1log("\nNo $extension files found.\n");
		return 0;
	}
	chdir'..';
	my $tracker;
        my @filelist;
	foreach $list(@listing) {						# Step through the list.
	   	p1log(++$tracker % 10);							# Let the user know that something is happening.
		if ($interrupt){break(); return 0};
		if ($fnumber < 1000){						# If there is less than 1000 files, use 000.xxx format.
			$newname = sprintf('%03s%s', $filecnt, ".$extension");
		} elsif ($fnumber < 10000){					# If there is less than 10000 files, use 0000.xxx format.
			$newname = sprintf('%04s%s', $filecnt, ".$extension");
		} else {							# If there is more than 9999 files, use 00000.xxx format.
			$newname = sprintf('%05s%s', $filecnt, ".$extension");
		}

  if (rename("$directory/$list","$tempdir/$newname")){
         push(@filelist,$newname); } else {
         p1log("Could not rename file $list to $newname. File already exists or is in use.\n");   # Rename the file.
      }
      $filecnt++;
   }
   my $file;
   p1log("\nMoving files back to original directory:\n");
   foreach $file(@filelist) { p1log("."); rename("$tempdir/$file","$directory/$file"); }

	rmdir $tempdir;
	chdir'text';
	return $filecnt-$startrnm;
}

##########################################################################################################

sub splchk{
	my ($file, $filename, $misspelled, $correct, $return, $thisdir);
	my $fixed = 0;
	p1log("\nChecking for and fixing commonly misscanned words. - Please wait...\n");
	my (%replaced, $key, $test);
	our %scannos;
	{
		$thisdir = getpwd();
		chdir "$startdir";
		unless ($return = do 'scannos.rc') { 				# load scannos list
			unless (defined $return){
				if ($@) {					# trap errors
					p1log("\nCould not parse scannos.rc, file may be corrupted. Scanno check aborted.\n")
				}else {
					p1log("\nCould not find scannos.rc file. Scanno check aborted.\n")
				}
				chdir "$thisdir";
				return 0;
			}
		}
		chdir "$thisdir";
	 }
	if (chdir"text"){
		my @files = glob "*.txt";
		my (@filewords,$word);					# get a list of files
		my $tracker;
		foreach $filename(@files){
			{
				local(*INPUT, $/);			# slurp in a file
				open (INPUT, "$filename");
				$file = <INPUT>;
			}
			utf8::decode($file);
			@filewords = split/\W+/, $file;
			foreach $word(@filewords){			# check for scannos
				if (exists $scannos{$word}){
					$misspelled = $word;
					$correct = $scannos{$word};
					$file =~ s/(?<=\b)$misspelled(?![\w-])/$correct/g;
					$fixed++;
					push @{$replaced{$filename}}, "$misspelled to $correct";
				}
			}
			open (OUTFILE, ">$filename");
			utf8::encode $file;
			print OUTFILE $file;
			close (OUTFILE);
			p1log(++$tracker % 10);			# Let the user know that something is happening.
			if ($interrupt){break(); chdir "$thisdir"; return 0};
		}
		chdir "..";
	}else{
		p1log("\nCan't find text directory.\n");
		return 0;
	}
	p1log("\nFinished. $fixed scanno".(($fixed != 1) ? "s found.\n\n" : " found.\n\n")); # Corrected $fixed words.
	foreach $key (sort keys %replaced){
		p1log("\nIn file $key, ".(scalar @{$replaced{$key}})." replacement".		# display list of changes made
		((scalar @{$replaced{$key}})>1 ? "s were made. - Changed:\n" : " was made. - Changed:\n"));
		foreach $test(sort @{$replaced{$key}}){
			p1log("$test;\n");
		}
	}
}

sub englifh{
	my ($file, $filename, $misspelled, $correct, $return, $thisdir);
	my $fixed = 0;
	p1log("\nChecking for and fixing long ess (f) words. - Please wait...\n");
	my (%replaced, $key, $test);
	my $fwords;
	{
		$thisdir = getpwd();
		chdir "$startdir";
		$fwords = retrieve('fcannos.bin');
		chdir "$thisdir";
	 }
	if (chdir"text"){
		my @files = glob "*.txt";
		my (@filewords,$word);					# get a list of files
		my $tracker;
		foreach $filename(@files){
			{
				local(*INPUT, $/);			# slurp in a file
				open (INPUT, "$filename");
				$file = <INPUT>;
			}
			utf8::decode($file);
			@filewords = split/\W+/, $file;
			foreach $word(@filewords){
				next unless ($word =~ /f/);
				if (exists $$fwords{lc($word)}){
					$misspelled = $word;
					$correct = $$fwords{lc($word)};
					$file =~ s/\b($misspelled)\b/lc$correct^($1^lc$1)&(lc$correct^uc$correct)/gie;
					$fixed++;
					push @{$replaced{$filename}}, "$misspelled to $correct";
				}
			}										# check for scannos
			open (OUTFILE, ">$filename");
			utf8::encode $file;
			print OUTFILE $file;
			close (OUTFILE);
			p1log(++$tracker % 10);			# Let the user know that something is happening.
			if ($interrupt){break(); return 0};
		}
		chdir "..";
	}else{
		p1log("\nCan't find text directory.\n");
		return 0;
	}
	p1log("\nFinished. $fixed Olde Englifh word".(($fixed != 1) ? "s found.\n\n" : " found.\n\n")); # Corrected $fixed words.
	foreach $key (sort keys %replaced){				# Scroll if necessary
		p1log("\nIn file $key, ".(scalar @{$replaced{$key}})." replacement".		# display list of changes made
		((scalar @{$replaced{$key}})>1 ? "s were made. - Changed:\n" : " was made. - Changed:\n"));
		foreach $test(sort @{$replaced{$key}}){
			p1log("$test;\n");
		}
	}
}

##########################################################################################################
# Degrades files from UTF-8 to iso 8859-1

sub convert {
	my ($list, $newname,$file);
	my $filecnt = 0; 							#Initialize and localize some variables
	my @listing = glob("*.txt");					# Get a list of files in the current directory.
	my $fnumber = @listing;							# See how many files there are.
	unless (scalar @listing){
		p1log("\nNo .txt files found.\n");
		return 0;
	}
	my $tracker;
	foreach $list(@listing) {						# Step through the list.
	   	$filecnt++;
	   	p1log(++$tracker % 10);							# Let the user know that something is happening.
		local(*INPUT, $/);
		open (INPUT, "$list");
		$file = <INPUT>;
		close(INPUT);

		utf8::decode($file);
		$file = betagreek($file);
		utf8::encode($file);
		Encode::from_to($file,"utf-8","iso 8859-1");

		open (OUTPUT, ">$list");
		print OUTPUT $file;
		close (OUTPUT);
	}
	return $filecnt;
}
##########################################################################################################

sub pngcrush{
	my ($pngfile, @pngsdone, $filesleft, $infile, $outfile, $errline);
	my $thisdir = getpwd();
	if(chdir"_pngsback_") { 					# check a few things before starting
		p1log("\nIt appears that pngcrush was already run on these pngs. Checking for unfinished files.\n");
		chdir $thisdir;
		chdir"$imagesdir";
		@pngsdone = glob "*.png";
		chdir $thisdir;
	}else{
		unless(chdir"$imagesdir") {
			p1log("\nUnable to find $imagesdir directory.\n");
			chdir $thisdir;
			return 0;
		}
	}
	chdir $thisdir;
	rename "$imagesdir",'_pngsback_';				# fast backup... may be problem cross platform..
	mkdir ("$imagesdir",0777);					# make a directory to hold shrunken files
	$crushoptions = $crushentry->get;				# get the options from the prefs tab
	chomp $crushoptions;						# remove any stray newlines
	my $crushstart = $startdir . $separator . 'pngcrush' . $separator . 'pngcrush.exe';	#build a program path

	chdir"_pngsback_";
	my @listing = glob "*.png";					# get a list of png files
	foreach (@pngsdone){shift @listing};
	$filesleft = scalar @listing;
	if ($filesleft){
		p1log("\nCompressing the png files. Original files saved in _pngsback_ directory. $filesleft files to process.\nPlease wait.\n\n");

		foreach $pngfile(@listing){
			$infile = $pngfile;				# working from the backup directory to save path space. only 128 characters in dos/win
			$outfile = ".." . $separator . $imagesdir . $separator . $pngfile;	# build path to save filename.
			pngcrushstart($crushstart,$crushoptions,$infile,$outfile);		# crush the png
			open (ERR, "<err");
			while ($errline = <ERR>){
				if ($errline =~ /(length)|(method)/){				# capture interesting output from program & display it
					p1log("$errline");
				}
			}
			p1log("\n");
			close ERR;
			unlink "err";
			$filesleft--;
			if ($interrupt){						# it takes so long to do this, I made it restartable in the middle
				p1log("\nThere are still $filesleft files left unprocessed. Re-run pngcrush to finish them.\n");
				break();
				chdir $thisdir;
				return 0};
		}
	}
	chdir $thisdir;
	p1log("\nFinished compressing pngs, original files in _pngsback_.\nOK.\n");
	$runpngcrush = 0;
}

sub pngcrushstart{
	my ($crushstart,$crushoptions,$infile,$outfile);
	($crushstart,$crushoptions,$infile,$outfile) = @_;
	if ($^O =~ /Win/){
		open (BAT,">run.bat");
		print BAT '@echo off'."\n";
		print BAT "\"$crushstart\" $crushoptions \"$infile\" \"$outfile\" > err\n\n";
		close BAT;
		system "run.bat";
#		unlink "run.bat";
	}				#if not windows, assume Linux, the following works under Slackware at least...
	else {	$crushstart="pngcrush ";
                system $crushstart." ".$crushoptions." ".$infile." ".$outfile." >err\n\n";

	}
}

sub  pthelp{
	my $pthelp = $main->messageBox(-title => "Process Text Help", -type => "OK", -icon => 'question',
	-message => "Extract markup will process rtf files into text files with italics and bold markup. It will expect to find at least the folder ".
	"\"textw\" and possibly \"textwo\" with RTF files in them.\n\nDehyphenate will use the files in \"textw\" (and \"textwo\", if present) ".
	"to rejoin end-of-line hyphens and will place the results in a folder named \"text\".\n\n".
	"Rename Text Files will rename the text files in the \"text\" directory into the format needed by DP. Works in the \"text\" directory.\n\n".
	"Filter Files will perform all of the pattern ".
	"search-and-replace selections specified on the Select Options tab. Works in the \"text\" directory.\n\n".
	"Fix Olde English should only be used on files that contain long s characters - which are often scanned as 'f'. ".
	"It will search for all words that have an f in them, convert any f's that should unambiguously be s and mark ambiguous instances with an asterisk.\n\n".
	"Fix Common Scannos will search and replace all of the common scannos specified in the included scannos.rc file. Works in the \"text\" directory.\n\n".
	"Fix Zero Byte Files will check for zero length files, warn you if found, and insert the text specified on the Select Options tab. Works in the \"text\" directory.\n\n".
	"Convert to ISO 8859-1 will down convert UTF-8 files to Latin-1. Guiprep natively works in UTF-8 now so files need to be converted for use on DP (for now.)\n\n".
	"Rename Png Files will rename the png files in the $imagesdir directory into the format needed by DP.\n\n".
	"Run Pngcrush will run the external program pngcrush.exe on the files in the $imagesdir directory.\n\n".
	'Pngcrush is a .png file optimizer to reduce file sizes. In my experience, it will reduce size of png '.
	'files saved from Abbyy about 7-10%. Since the files get up and downloaded so often, it is worth the time in my opinion.'.
	'It generally takes 2-5 seconds to process each png file, so large numbers of '.
	'files will take a while to process.'."\n\nIf desired, you can adjust the options for pngcrush on the Program Prefs tab. ".
	"The original files will be put in the directory \"_pngsback_\". ".
	"If processing is interrupted, you can restart it and it will pick up where it left off. ".
	"Or you can just delete the $imagesdir directory and rename _pngsback_ to $imagesdir to revert to the originals.".
	"\n\nThe start and stop processing buttons are pretty much self explanatory.\nThe Make Backups and Load Backups buttons will save ".
	"and revert to backups of your text files. You can do this if you like before trying different filter options or search and ".
	"replace to reduce lost time incase you get undesired results.\nThe Clear Log and Save Log buttons will save or clear the ".
	"status box contents."
);
}

sub tbackup{
	my (@filelist, $file, $body, $save);
	p1log("\nBacking up texts into textback directory. - Please wait...\n");
	unless(opendir(DIR,"textback")) { mkdir ("textback",0777)};			# Make a backup directory unless it already exists
	closedir(DIR);
	chdir "text";
	@filelist = glob"*.txt";
	chdir"..";
	my $tracker;
	foreach $file(@filelist){
		p1log(++$tracker % 10);
		open (INFILE, "<text/$file");
		open (OUTFILE, ">textback/$file");
		while($body = <INFILE>){						# back up all of the text files
			print OUTFILE $body;
		}
		close INFILE;
		close OUTFILE;
	}
}

sub revert{
	if (opendir(DIR,"textback")){
		closedir(DIR);
		p1log("\nReverting to backup texts from textback directory. - Please wait...\n");
		my (@filelist, $file, $body, $save);
		chdir "textback";
		@filelist = glob"*.txt";
		chdir"..";
		my $tracker;
		foreach $file(@filelist){
			p1log(++$tracker % 10);
			open (INFILE, "<textback/$file");
			open (OUTFILE, ">text/$file");
			while($body = <INFILE>){					# load backups
				print OUTFILE $body;
			}
			close INFILE;
			close OUTFILE;
		}
	}else{
	p1log("\nNo backup directory found. Have you saved backups?\n");
	}
}

sub p1log{
	my $msg = shift;
	$p1text->insert('end',$msg);
	$p1text->update;
	$p1text->yviewMoveto('1.');
	return;
}
##########################################################################################################

##########################################################################################################
#  Subroutines used by page 2 - Options
sub save{
	my ($index, $savethis);
	chentries();				# Save the various options and variables that are valuable session to session
	$geometry = $main->geometry();
	$ftpusername = $p7user->get;
	$ftppassword = $p7pass->get;
	$ftphome = $p7home->get;
	chdir"$startdir";
	my $savefile = 'settings.rc';
	open(SAVE, ">$savefile");
	print SAVE ('# This file contains your saved settings for guiprep.pl. It is automatically generated when you save your settings.',"\n");
	print SAVE ('# If you delete it, all the settings will revert to defaults. You shouldn\'t ever have to edit this file manually.',"\n\n");
	$savethis = $zerobytetext; $savethis =~ s/\\$/\\\\/g;		# need to escape any trailing backslash on the saved options, will corrupt setting file
	print SAVE ('$zerobytetext = \'',$savethis,'\';',"\n");
	$savethis = $italicsopen; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$italicsopen  = \'',$savethis,'\';',"\n");
	$savethis = $italicsclose; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$italicsclose = \'',$savethis,'\';',"\n");
	$savethis = $boldopen; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$boldopen     = \'',$savethis,'\';',"\n");
	$savethis = $boldclose; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$boldclose    = \'',$savethis,'\';',"\n\n");
	$savethis = $supopen; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$supopen     = \'',$savethis,'\';',"\n");
	$savethis = $supclose; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$supclose    = \'',$savethis,'\';',"\n\n");
	print SAVE ('@opt = (');
	foreach $index(@opt) {print SAVE "$index,"};
	print SAVE (');',"\n\n");
	$savethis = $pwd; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$lastrundir   = \'',$savethis,'\';',"\n");
	print SAVE ('$palette      = \'',$palette,'\';',"\n");
	$savethis = $editstart; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$editstart    = \'',$savethis,'\';',"\n");
	$savethis = $viewerstart; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$viewerstart  = \'',$savethis,'\';',"\n");
	print SAVE ('$geometry     = \'',$geometry,'\';',"\n");
	$savethis = $ftphostname; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$ftphostname  = \'',$savethis,'\';',"\n");
	$savethis = $ftpusername; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$ftpusername  = \'',$savethis,'\';',"\n") if $opt[48];
	$savethis = $ftppassword; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$ftppassword  = \'',$savethis,'\';',"\n") if $opt[48];
	$savethis = $ftphome; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$ftphome  = \'',$savethis,'\';',"\n") if $opt[48];
	$savethis = $crushoptions; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$crushoptions = \'',$savethis,'\';',"\n");
	$savethis = $imagesdir; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$imagesdir    = \'',$savethis,'\';',"\n");
	$savethis = $ftpdownloaddir; $savethis =~ s/\\$/\\\\/g;
	print SAVE ('$ftpdownloaddir = \'',$savethis ,'\';',"\n");
	$ftpaccount{$ftphostname}[0] = $p7user->get if $opt[48];
	$ftpaccount{$ftphostname}[1] = $p7pass->get if $opt[48];
	$ftpaccount{$ftphostname}[2] = $p7home->get if $opt[48];
	foreach $savethis(keys %ftpaccount){
		print SAVE '$ftpaccount{\'',$savethis,'\'} = [\'',$ftpaccount{$savethis}[0],'\',\'',$ftpaccount{$savethis}[1],'\',\'',$ftpaccount{$savethis}[2],'\'];',"\n";
	}
	close (SAVE);
	chdir"$pwd";
}

sub chentries{
	$italicsopen = $italopen->get||$gitalicsopen;		# check to see if any markup options have changed
	$italicsclose = $italclose->get||$gitalicsclose;
	$boldopen = $bopen->get||$gboldopen;
	$boldclose = $bclose->get||$gboldclose;
	$zerobytetext = $blank->get||$gzerobytetext;
	$supopen = $supsopen->get||$gsupopen;
	$supclose = $supsclose->get||$gsupclose;
}

sub defaults{					# Revert to default markup on Save option tab
	my $index;
	$zerobytetext = $gzerobytetext;
	$blank->delete(0,'end');
	$blank->insert(0, $zerobytetext);
	$italicsopen = $gitalicsopen;
	$italopen->delete(0,'end');
	$italopen->insert(0, $italicsopen);
	$italicsclose = $gitalicsclose;
	$italclose->delete(0,'end');
	$italclose->insert(0, $italicsclose);
	$boldopen = $gboldopen;
	$bopen->delete(0,'end');
	$bopen->insert(0, $boldopen);
	$boldclose = $gboldclose;
	$bclose->delete(0,'end');
	$bclose->insert(0, $boldclose);
	$supopen = $gsupopen;
	$supsopen->delete(0,'end');
	$supsopen->insert(0,$supopen);
	$supclose = $gsupclose;
	$supsclose->delete(0,'end');
	$supsclose->insert(0,$supclose);
}

###################################################################################################################################

#  Subroutines used by page 3 - Remove Headers/footers

# Subroutine to handle Remove Headers/footers button.

sub ok{
	my ($head, $line);
 	my @selected = $lbox->curselection;
        foreach $head(@selected) {
		undef $deletelines[$head];
                }
           if ($headersel==1)
         {

	 open (HEADS, ">headers.xxx");
	 foreach $line(@deletelines){
		print HEADS ("$line\n") if defined $line;
	 }
	 close (HEADS);
	 delheaders();
	 emptybox();
	 unlink "headers.xxx";

}
else
{

	open (FEET, ">footers.xxx");
	foreach $line(@deletelines){
		print FEET ("$line\n") if defined $line;
	}
	close (FEET);
	delfooters();
	emptybox();
	unlink "footers.xxx";
  }
 
}

sub emptybox{
	$lbox->delete(0, 'end');
}

# Subroutine to handle Unselect All button.
sub clearall{
	$lbox->selectionSet(0,'end')
}

# Subroutine to toggle the selection.
sub toggle{
	my $index;
	my @selected = $lbox->curselection;
 	$lbox->selectionSet(0,'end');
	foreach $index(@selected){
		$lbox->selectionClear($index);
	}
}

# Subroutine to handle Select All button.
sub setall{
	$lbox->selectionClear(0,'end')
}

sub getheaders{
        $headersel=1;
	$lbox->delete(0, 'end');
	while (scalar (@deletelines)){ pop @deletelines};
	my ($file, $line, @listing);
	my $topline = '';
	if (chdir"text"){
		@listing = glob("*.txt");			# Get a list of text files.
		chdir"..";
	}
	foreach $file(@listing) {				# Step through the list.
		open (TXT, "<text/$file");			# Open a file.
		$topline = <TXT>;
		utf8::decode($topline);
		chomp $topline;
		unless($topline =~ /\Q$zerobytetext\E/) {
			$line = sprintf "%-12s  %s",$file,$topline;	# Record top line of file
			push @deletelines, $line;
		}
		close(TXT);
	}
	unless (scalar @deletelines) {
		my $response = $main->messageBox(
			-icon => 'error',
			-message => 'Could not find text directory or directory was empty.',
			-title => 'No Headers',
			-type => 'OK',
		);
	}
	# Populate the list box with the header array.
	$lbox->insert('end', @deletelines );
	$lbox->yview('scroll',1,'units');
	$lbox->update;
	$lbox->yview('scroll',-1,'units');
	clearall();
	if ($batchmode){
		open (HEADS, ">headers.xxx");			# special section for batch mode - bypasses a lot of display logic which won't be seen
		foreach $line(@deletelines){
			print HEADS ("$line\n");
		}
		close (HEADS);
	}
}


sub getfooters{
        $headersel=2;
        $lbox->delete(0, 'end');
	while (scalar (@deletelines)){ pop @deletelines};
	my ($file, $line, @listing);
	my $bottomline = '';
	my $textin = '';
        if (chdir"text"){
		@listing = glob("*.txt");			# Get a list of text files.
		chdir"..";
	}
	foreach $file(@listing) {				# Step through the list.
		open (TXT, "<text/$file");			# Open a file.
		while ( $textin = <TXT>)
                {
		    if (eof(TXT)){$bottomline=$textin}
		}


	utf8::decode($bottomline);
		chomp $bottomline;
		unless($bottomline =~ /\Q$zerobytetext\E/) {
			$line = sprintf "%-12s  %s",$file,$bottomline;	# Record last line of file
			push @deletelines, $line;
		}
		close(TXT);
	}
	unless (scalar @deletelines) {
		my $response = $main->messageBox(
			-icon => 'error',
			-message => 'Could not find text directory or directory was empty.',
			-title => 'No Footers',
			-type => 'OK',
		);
	}
	# Populate the list box with the header array.
	$lbox->insert('end', @deletelines );
	$lbox->yview('scroll',1,'units');
	$lbox->update;
	$lbox->yview('scroll',-1,'units');
	clearall();
	if ($batchmode){
		open (FEET, ">footers.xxx");			# special section for batch mode - bypasses a lot of display logic which won't be seen
		foreach $line(@deletelines){
			print FEET ("$line\n");
		}
		close (FEET);
	}
}


sub delheaders {
	my (@headers, $topline, $line, $lines, $file, $filename);
	unless (open (HEADS, "<headers.xxx")){			# Open a file to write changes to.
		 my $response = $main->messageBox(
		-icon => 'error',
		-message => 'Could not open headers.txt processing file.',
		-title => 'File Not Found',
		-type => 'OK');
	}
	my $headerfilter = $zerobytetext;
	#$headerfilter =~  s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g; 	#escape meta characters
	while ($line = <HEADS>){
		$line =~ /^(.+?\.txt)(?=\s)/;
		$filename = $1;
		push (@headers, $filename) unless ($line =~ /\Q$headerfilter\E/);
	}
	close(HEADS);
	chdir "text";
	foreach $file (@headers) {
   		$lines = 0;
		if (open(TXT, "<$file")){		# Open a file.
			open(NEW, ">temp");		# Open a temp file for writing
			while ($line = <TXT>){
                            last if ($line eq eof);
			    next if ($lines == 1 && $line eq "\n");
			    print NEW $line if $lines;	# Print line of file
			    $lines++;
			    }   
  # at this point, if $lines=1, the only line in the file has been deleted....
		            if ($lines==1){print NEW "[Blank Page]";}	
                        close(TXT);  		 # Clean up file handles
			close(NEW);
			unlink "$file";				# Delete file
			rename("temp", $file);			# Rename temporary file to filename
			}
		    }
	  
	chdir"..";
    }


sub delfooters {
	my (@footers, $lastline, $line, $lines, $file, $filename);
	unless (open (FEET, "<footers.xxx")){			# Open a file to write changes to.
		 my $response = $main->messageBox(
		-icon => 'error',
		-message => 'Could not open footers.txt processing file.',
		-title => 'File Not Found',
		-type => 'OK');
	}
	my $footerfilter = $zerobytetext;
	#$footerfilter =~  s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g; 	#escape meta characters
	while ($line = <FEET>){
		$line =~ /^(.+?\.txt)(?=\s)/;
		$filename = $1;
		push (@footers, $filename) unless ($line =~ /\Q$footerfilter\E/);
	}
	close(FEET);
	chdir "text";
	foreach $file (@footers) {
   		$lines = 0;
		if (open(TXT, "<$file")){		# Open a file.
			open(NEW, ">temp");		# Open a temp file for writing


			while ($line = <TXT>){
				print NEW $line if not (eof(TXT));	# Print line of file
				$lines++;
			}
                        if ($lines==0){ print NEW "[Blank Page]"};
			close(TXT);  				# Clean up file handles
			close(NEW);
			unlink "$file";				# Delete file
			rename("temp", $file);			# Rename temporary file to filename
		}
	}
	chdir"..";
}




sub helphr{
	my $cdhelpbox = $main->messageBox(-title => "Help with Header Removal", -type => "OK", -icon => 'question',
	-message => '   Click on Get Headers to get a list showing the fisrts line from each file in the text directory. '.
        'Get Footers will show the last line from each file.Check each line and if you would like to remove it, select it.'.
        'Selected lines will have a white background. '.
	'Alternately you can use the Select All, Unselect All and Toggle Selection buttons to make bulk changes to the '.
	'selection list. Once you are satisfied with your selection list, press Remove Selected to write all of the changes '.
	"to the selected files. You can refresh the list by pressing Get Headers or Get Footers again and repeat if desired/necessary. ".
	"\n\n   You can also open individual pages in a text editor if you want to do more significant ".
	"changes or just want to see the whole page. If your png files are in the $imagesdir directory and are named in the ".
	"upload format, you can also open an image viewer window to do side by side comparisons.\n\n\n".
	"INVOKE the text editor by double left clicking on a file from the list.\n\n".
	"INVOKE the image viewer by selecting (left click) a file from the list, then right click.\n\n".
	"Remember to refresh your header/footer list if you do any edits to the text files.");
}

sub testart{
	my $clickedfil = shift;
	my $exe = $editstart;
	chdir"$startdir";
	if ($^O =~ /Win/){
		$exe = Win32::GetShortPathName($editstart);
		$clickedfil = Win32::GetShortPathName($clickedfil);
	}
	runner($exe, $clickedfil);
	chdir"$pwd";
}

sub ivstart{
	my $clickedfil = shift;
	my $exe = $viewerstart;
	chdir"$startdir";
	if ($^O =~ /Win/){
		$exe = Win32::GetShortPathName($viewerstart);
		$clickedfil = Win32::GetShortPathName($clickedfil);
	}
	runner($exe, $clickedfil);
	chdir"$pwd";
}

###################################################################################################################################
# Subroutines used by page 4 - Change Directory

sub getpwd{
	my $cwd = cwd();
	my $wincwd = $cwd;
	$wincwd =~ s/\//\\/g;
	$wincwd = ucfirst($wincwd);
	my $pd = $cwd;
	my $os = $^O;
	if ($os =~ /Win/){$pd = $wincwd}
	return $pd;
}

sub getdrives{
	my ($drive, @drives);
	my @drivelist = Win32API::File::getLogicalDrives();
	foreach  $drive(@drivelist){
		push @drives, ucfirst($drive)
	}
	return @drives;
}

sub getdirs{
	my (@dirs, $dir);
	my @list = glob("*");
	push @dirs, "..";
	foreach $dir(@list) {
		push @dirs, $dir if -d $dir;
	}
	return @dirs;
}

sub chdirectory{
	my $d = shift;
	$d = shift;
	chdir $d;
	$pwd = getpwd();
	$dirbox->delete('0', 'end');
	$dirbox6->delete('0', 'end');
	my @dirlist = getdirs();
	$dirbox->insert('end', @dirlist);
	shift @dirlist;
	$dirbox6->insert('end', @dirlist);
	$tdirlabel->delete('1.0', 'end');
    	$tdirlabel->insert('end', "$pwd");
    	$bottomlabel->destroy;
   	$bottomlabel = $mainbframe->Label(
		-text => "Working from the $pwd directory.",
		-font => '-*-Helvetica-Medium-R-Normal--*-160-*-*-*-*-*-*'
)->pack(-anchor => 'nw');
    	$lbox->delete(0, 'end');
    	save();
}

sub helpcd{
	my $cdhelpbox = $main->messageBox(-title => "Help with Directory / Batch selection", -type => "OK", -icon => 'question',
	-message => '   The present working directory is shown just above the selection boxes and in the top status bar. Change '.
 	 'directories by clicking on the directory '.
 	 'name in the list. Click on the .. to go up one level. The current directory will change in response to selections made.'.
	 "\n\n".
	 '   FOR INTERACTIVE PROCESSING: Select a directory to be the present working directory. The working directory '.
 	 'should be your "project" directory, with the directories textw and textwo beneath it. If you do not see the directories textw and '.
	 'textwo (or text, if you are skipping markup extraction and dehyphenization) in '.
	 'the select box, the script will probably not work correctly, and will complain.'.
	 "\n\n".
	 '   FOR BATCH PROCESSING: Select the directories you want to batch process in the right selection box. Each directory in the batch will need to have the prerequisite '.
	 'child directories required for the particular routines you want to run on it. Extract and Dehyphenate will expect to find the textw and textwo '.
	 'directories. (The text directory will be generated by Dehyphenate if necessary.) Filter, Fix Common Scannos, Rename and Fix Zero Byte routines will expect to find '.
	 'the text directory. After the directories are selected, got to Process Text and press Process Batch to start batch processing. '.
	 'Select which routines to batch run on the text files on the Process Text tab.'.
	 "\n\nThere is now an option to do batch header removal at the top of the page. This will blindly remove the top line of text ".
	 "from each file in the text directory. Use with caution. It is recommended that Remove headers be done in interactive mode."
	 );
}
###################################################################################################################################
# Subroutines used by Batch Mode

sub batch{
	$interrupt = 0;
	$batchmode = 1;
	$bmessg = "Working... Please wait...\n";
	$p4bflabel->delete('1.0','end');
	$p4bflabel->insert('end',"$bmessg");
	$p4bflabel->update;
	@dirlist6 = getdirs();
	shift @dirlist6;
	my ($bdir, @batchlist);
	my @blist = $dirbox6->curselection;
	foreach $bdir(@blist) {
		push @batchlist, $dirlist6[$bdir];
	}
	unless (scalar @batchlist){
		updateblist();
		p1log("No batch found.\n");
		$batchmode = 0;
		return 0,
	}
	$dirbox6->selectionClear('1.0','end');
	foreach $bdir(@batchlist){
		next if $interrupt;
		chdir $bdir;
		p1log("Batch processing files in the $bdir directory.\n");
		doall();
		if ($opt[52]){
			p1log("\nBatch mode automatic header removal in progress... - Please wait.\n");
			getheaders();
			delheaders();
			p1log("\nFinished automatic header removal.\n");
			zero();
		}
       
		if ($opt[53]){
			p1log("\nBatch mode automatic footer removal in progress... - Please wait.\n");
			getfooters();
			delfooters();
			p1log("\nFinished automatic header removal.\n");
			zero();
		}
		if ($opt[54]){
			p1log("\nBuilding zip file of project files... - Please wait.\n");
			$book->raise('page7');
			$book->update;
			ftpbuildbatch();
			ftpbatchzip();
			$book->raise('page1');
			$book->update;
			p1log("\nZip file done.\n");
		}
		chdir "..";
		p1log("\nFinished batch processing files in $bdir directory.\n\n\n");
		$bmessg = "$bdir files done.\n";
		$p4bflabel->insert('end',"$bmessg");
		$p4bflabel->yviewMoveto('1.');
	}
	$interrupt = 0;
	$batchmode = 0;
	$dirbox6->selectionClear(0,'end');
	$bmessg = "Finished Batch.";
	$p4bflabel->delete('1.0','end');
	$p4bflabel->insert('end',"$bmessg");
	p1log("\n--Done with batch.--\n\n");
}

sub updateblist
{
	my ($bdir, @batchlist, $twflag, $twoflag, $imagesflag);
	$p4bflabel->delete('1.0','end');
	@dirlist6 = getdirs();
	shift @dirlist6;
	my @blist = $dirbox6->curselection;
	foreach $bdir(@blist) {
		push @batchlist, $dirlist6[$bdir];
	}
	if (scalar @batchlist){
		$bmessg="Selected Directories to Process:\n\n";
		 foreach $bdir(@batchlist){
			$bmessg = $bmessg . "$bdir\n";
		}
		$p4bflabel->insert('end',"$bmessg");
	}else {
		$bmessg = "No Batch Directories Selected. \nInteractive mode.\n\n";
		$p4bflabel->insert('end',"$bmessg");
		if (chdir"$imagesdir"){
			chdir"..";
			$p4bflabel->insert('end',"$imagesdir directory found.\n");
		}else {
			$p4bflabel->insert('end',"$imagesdir directory not found.\n");
		}
		if (chdir"textwo"){
			$twoflag =1;
			chdir"..";
			$p4bflabel->insert('end',"textwo directory found.\n");
		}else {
			$p4bflabel->insert('end',"textwo directory not found.\n");
		}
		if (chdir"textw"){
			$twflag =1;
			chdir"..";
			$p4bflabel->insert('end',"textw directory found.\n");
		}else {
			$p4bflabel->insert('end',"textw directory not found.\n\nWill not be able to use Extract or Dehyphenate routines.\n\n");
		}
		if (chdir"text"){
			chdir"..";
 			$p4bflabel->insert('end',"text directory found.\n");
		}else {
			unless($twflag && $twoflag){
				$p4bflabel->insert('end',"text directory not found.\n");
			}
		}
                if (chdir"images"){
                   $imagesflag =1;
                   chdir"..";
                   $p4bflabel->insert('end',"illustrations directory found.\n");            }else {
              $p4bflabel->insert('end',"illustrations directory not found.\n");
                }
     }

     $p4bflabel->update;
     $interrupt = 0;
}

#######################################################################################################################

sub ftplogger{
	my $msg = shift;
	$ftplog->insert('end',$msg);
	$ftplog->update;
	$ftplog->yviewMoveto('1.'); # Scroll if necessary
	return;
}

sub ftpstatus{
	my $msg = shift;
	$p7status->delete('1.0','end');
	$p7status->insert('end',$msg);
	$p7status->update;
	return;
}

sub extopen{
	my $clickedfil;
	my @selectionlist = $ftpbatchbox->curselection;
	if (@selectionlist){
		$clickedfil = $ftpbatchbox->get($selectionlist[0]);
	}
	if ($clickedfil =~ /\.txt$/){
		if ($editstart){
			testart($clickedfil);
		}else{
			my $response = $main->messageBox(
				-icon => 'error',
				-message => "Could not start your text editor $editstart\nWould you like to set up a text editor?.",
				-title => 'Editor not found',
				-type => 'YesNo',
			);
			if ($response eq 'yes'){
				editorsel();
				testart($clickedfil);
			}
		}
	}elsif ($clickedfil =~ /(\.png$|\.jpg$|\.tif$|\.bmp$)/){
		if ($viewerstart){
			ivstart($clickedfil);
		}else{
			my $response = $main->messageBox(
				-icon => 'error',
				-message => "Could not start your image viewer.\nWould you like to set up an image viewer?.",
				-title => 'Image Viewer Not Found',
				-type => 'YesNo',
			);
			if ($response eq 'yes'){
				viewersel();
				ivstart($clickedfil);
			}
		}
	}
}

sub ftpbuildbatch{
	my ($batchfile, @filelist, $thisdir, $howmany, $addfile, $thisfile, @zerofiles);
	$ftpbatchbox->delete('0','end');
	@ftpbatch = ();
	if (chdir"$imagesdir"){
		$thisdir = getpwd();
		ftplogger("Adding .png files from $thisdir directory.");
		@filelist = glob"*.png";
		unless (scalar @filelist){
			ftplogger("\nNo .png files in the $imagesdir directory!");
		}
		foreach $addfile(@filelist){
			$thisfile = $thisdir.$separator.$addfile;
			push @ftpbatch,$thisfile;
			push @zerofiles, $thisfile if (-s $thisfile == 0);
			$ftpbatchbox->insert('end',$thisfile);
			$ftpbatchbox->update;
			$ftplog->yviewMoveto('1.'); # Scroll if necessary
		}
		$howmany = scalar @filelist;
		ftplogger(" $howmany .png files added.\n");
		chdir"..";
	}else {
		ftplogger("$imagesdir directory not found. Are you in the correct working directory?\n");
	}
	if (chdir"text"){
		$thisdir = getpwd();
		ftplogger("Adding .txt files from $thisdir directory.");
		@filelist = glob"*.txt";
		unless (scalar @filelist){
			ftplogger("\nNo .txt files in the text directory! ");
		}
		foreach $addfile(@filelist){
			$thisfile = $thisdir.$separator.$addfile;
			push @ftpbatch,$thisfile;
			push @zerofiles, $thisfile if (-s $thisfile == 0);
			$ftpbatchbox->insert('end',$thisfile);
			$ftpbatchbox->update;
		}
		$howmany = scalar @filelist;
		ftplogger(" $howmany .txt files added.\n");
		chdir"..";
	}else {
		ftplogger("text directory not found. Are you in the correct working directory?\n");
	}
        if (chdir"images"){
       $thisdir = getpwd();
       ftplogger("Adding illustration files from $thisdir directory.");
       @filelist = glob"*.*";
       unless (scalar @filelist){
          ftplogger("\nNo files in the $imagesdir directory!");
       }
       foreach $addfile(@filelist){
          $thisfile = $thisdir.$separator.$addfile;
          push @ftpbatch,$thisfile;
          push @zerofiles, $thisfile if (-s $thisfile == 0);
          $ftpbatchbox->insert('end',$thisfile);
          $ftpbatchbox->update;
          $ftplog->yviewMoveto('1.'); # Scroll if necessary
       }
       $howmany = scalar @filelist;
       ftplogger(" $howmany illustration files added.\n");
       chdir"..";
    }

       if (@zerofiles){
		ftplogger("Warning! zero byte files:\n");
		foreach $thisfile(@zerofiles){ftplogger("$thisfile\n");};
	}
	ftplogger("OK.\n");
}

sub ftpbatchzip{
	my ($thisdir,$zipname,$file,$filepath,$member,$archivename,$status,$zip,$count,@filestats,$size);
	ftplogger("\nBuilding zip file $zipname from batch.\n");
	$thisdir = getpwd();
	$thisdir =~ /([^\\\/]*?)$/;
	my $testname = $1.".zip";
	if ($batchmode){
		$zipname = $testname;
	}else{
		my $savefilename = $servlistbox->getSaveFile(-initialdir => getpwd());
		$zipname = $savefilename;
		return unless $savefilename;
	}
	my @filelist = $ftpbatchbox->get(0,'end');
	unless (length ($filelist[0])){
		ftplogger("\nNo files to zip. Add files to the local list first.\nOK.\n");
		return;
	}
	open (FILE, ">$zipname");
	close FILE;
	my $zipfile = Archive::Zip->new();
	foreach $filepath(@filelist){
		$count++;
		ftplogger("|");
		$ftpbatchbox->delete('0');
		$zip = Archive::Zip->new();
		$filepath =~ /([^\\\/]*?)$/;
		$file = $1;
		$member = $zip->addFile( $filepath ,$file );
		$member->desiredCompressionLevel( 9 );
		$zipfile->addMember( $member );
	}
	ftplogger("\n$count files added. Writing $zipname to $thisdir directory. Please wait...");
	$status = $zipfile->writeToFileNamed( $zipname );
	@filestats = stat("$zipname");
	$size = int($filestats[7]/1024);
	if ($status){
		ftplogger("\nThere was a problem creating the zip file $zipname.\nOK.\n");
	}else{
		ftplogger("\nZip file $zipname created succesfully.  ($size"."KB written.)\nOK.\n");
	}
	$archivename = $zipname;
	$ftpbatchbox->insert('end',$archivename);
}

sub ftpaddfile{
	my (@uniq, $item, $file, @ftpfileadd);
	if (($Tk::version lt 8.4)and($^O =~/Win/)){
		@ftpfileadd = $addfilebutton->getOpenFile();
	}else{
		@ftpfileadd = $addfilebutton->getOpenFile(-multiple=>1);
	}
	if (@ftpfileadd){
		for $file(@ftpfileadd){
			$file =~ s/\//$separator/g;
			$ftpbatchbox->insert('end',$file);
		}
		my @filelist = $ftpbatchbox->get(0,'end');
		$ftpbatchbox->delete(0,'end');
		my %seen = ();
		foreach $item (@filelist) {
    			push(@uniq, $item) unless $seen{$item}++;
    		}
		$ftpbatchbox->insert('end',(sort @uniq));
		$ftpbatchbox->update;
		$ftpbatchbox->yviewMoveto('1.'); # Scroll if necessary
	}
}

sub ftpclearbatch{
	$ftpbatchbox->delete('0','end');
	@ftpbatch = ();
	ftplogger("Clearing Local List...\nOK.\n");
}

sub ftpbatchremove{
	my ($file, $thisfile, @filelist);
	my @selectionlist = $ftpbatchbox->curselection;
	if (@selectionlist){
		foreach $file(@selectionlist){
			$thisfile = $ftpbatchbox->get($file);
			push @filelist,"$thisfile\n";
		}
		my $response = $main->messageBox(
				-icon => 'question',
				-message => "Remove selected from batch list?\n\n @filelist",
				-title => 'Confirm Delete',
				-type => 'YesNo',
			);
		if ($response =~ /yes/i){
			my $first = $selectionlist[0];
			my $last = pop @selectionlist;
			$ftpbatchbox->delete($first,$last);
			$ftpbatchbox->update;
		}
	}
}

sub ftpclearlog{
	$ftplog->delete('1.0','end');
}

sub ftpsavelog{
	my $logfile = $ftplog->get('1.0','end');
	open (FTPLOG, ">>ftp.log");
	my $time = localtime();
	print FTPLOG "\n$time\n\n";
	print FTPLOG $logfile;
	close FTPLOG;
}

sub ftpconnect{
	ftpdisconnect();
	$ftpusername = $p7user->get;
	$ftppassword = $p7pass->get;
	$ftphome = $p7home->get;
	save();
	my ($debug);
	ftpstatus("Connecting...");
	ftplogger("Connecting to $ftphostname...  Please wait.\n");
	if ($ftp = Net::FTP->new($ftphostname, Timeout => 120, $debug => 0)){
		ftplogger("OK.\n");
		ftpstatus("Logging on...");
		ftplogger("Logging on to $ftphostname...  Please wait.\n");
	}else{
		ftpstatusnc();
		ftplogger("Could not connect to $ftphostname.\nOK\n");
	}
	if ($ftp){
		if ($ftp->login($ftpusername, $ftppassword)){
			ftplogger("OK.\n");
			ftpstatus("Connected...");
			ftplogger("Connected to $ftphostname.\n".
			"The initial directory listing may take 30 - 60 seconds, especially on dial-up.\n");
			$ftppwd->insert('end',"\/");
			$ftppwd->update;
			$ftp->pasv();
			if ($ftphome){
				ftplogger("Moving to $ftphome directory.\nOk.\n");
				unless($ftp->cwd("$ftphome")){
					ftplogger("Could not change to $ftphome directory. Insufficient permissions\nOk.\n");
				}
			}
			ftpgetdir();
		}else{
			ftplogger("Could not log on to $ftphostname.\n");
			ftpstatusnc();
			$ftp = 0;
			ftplogger("OK.\n");
		}
	}
}

sub ftpcdup{
	if ($ftp){
		my (@matching, $index, $thisdir);
		if (($thisdir = $ftp->pwd)eq "/"){
			ftplogger("Already in root directory. Can't go up any higher.\nOK.\n");
		}else{
			ftplogger("Going up one level...  Please wait.\n");
			$ftp->cdup();
			$ftppwd->delete('1.0','end');
			$ftppwd->insert('end',$thisdir);
			$ftppwd->update;
			ftpgetdir();
		}
	}else{
		ftpstatusnc();
		$ftp = 0;
		$servlistbox->delete('0','end');
	}
}

sub ftpchdir{
	if ($ftp){
		my @selarray = $servlistbox->curselection;
		my $changeto = shift @selarray;
		if ($ftpdirlist[$changeto] =~ /^D/){
			ftplogger("Changing to ".(substr $ftpdirlist[$changeto],8)." directory...  Please wait.\n");
			my $ftpchangtodir = substr $ftpdirlist[$changeto],8;
			if ($ftp->cwd("$ftpchangtodir")){
				ftpgetdir();
			}else{
				ftplogger("Could not change to $ftpchangtodir directory. Insufficient permissions\nOk.\n");
			}

		}elsif($ftpdirlist[$changeto] eq ".."){
			ftpcdup();
		}else{
			ftpdownload();
		}
	}else{
		ftpstatusnc();
		$ftp = 0;
		$servlistbox->delete('0','end');
	}
}

sub ftpgetdir{
	if ($ftp){
		my (@matching, $entity, $entityname, $index, $thisftpdir, $dentries, $fentries, $filesize);
		$dentries = $fentries = 0;
		ftplogger("Getting directory listing...  Please wait.");
		if ($thisftpdir = $ftp->pwd()){
			$ftppwd->delete('1.0','end');
			$ftppwd->insert('end',"$thisftpdir");
			$ftppwd->update;
		}else{
			ftpstatusnc();
			$ftp = 0;
		}
		if (defined(@{$ftpdircache{$thisftpdir}})){
    			@ftpdirlist = @{$ftpdircache{$thisftpdir}}; #Set directory listing equal to cached listing
			$fentries = pop @ftpdirlist; #Extract number of files in directory from end of list
    			$dentries = pop @ftpdirlist; #Extract number of directories in directory from end of list
		}else{
			my @ftpdirlisting = $ftp->dir;
			@ftpdirlist=();
			foreach (@ftpdirlisting) {
				@matching = split/\s+/,$_;
    				$matching[0] =~ s/(^-)/FILE - /;
    				$matching[0] =~ s/(^d)/DIR  - /;
    				$matching[0] =~ s/(^.......).+/$1/;
    				$entity = 9;
				$entityname =$matching[8];
				while ($matching[$entity]){
					$entityname = $entityname .' '. $matching[$entity];
					$entity++;
				}
    				if ($matching[0] =~ /(^F)/){
    					if ($matching[4]/1024 > .99){
    						$filesize = sprintf("%.1f %s", $matching[4]/1024," KB")
    					}else{
    						$filesize = sprintf("%u %s", $matching[4]," B")
    					}
    					$entity = $matching[0]." ".$entityname." \/\/ ".$filesize;
    					push @ftpdirlist,$entity;
    					$fentries++
    				}elsif ($matching[0] =~ /(^D)/){
    					$entity = $matching[0]." ".$entityname;
    					push @ftpdirlist,$entity;
    					$dentries++
    				};
    			}
    			unless ($thisftpdir eq '/'){ unshift @ftpdirlist, ".."}
    			@{$ftpdircache{$thisftpdir}} = @ftpdirlist;  #Save directory listing to cache
    			push @{$ftpdircache{$thisftpdir}},$dentries; #Save number of directories in directory at end of list cache
    			push @{$ftpdircache{$thisftpdir}},$fentries; #Save number of files in directory at end of list cache
    		}
    		$servlistbox->delete('0','end');
		$servlistbox->insert('end', sort {lc($a) cmp lc($b) } @ftpdirlist);
		$servlistbox->yview('scroll',1,'units');
		$servlistbox->update;
		$servlistbox->yview('scroll',-1,'units');
		ftplogger("\n$dentries directories and $fentries files in current directory.\nOK.\n");
	}else{
		ftpstatusnc();
		$ftp = 0;
		$servlistbox->delete('0','end');
	}
}

sub ftpmkdir{
	my ($ftpcheck, $thisftpdir);
	if ($ftp){
		$ftpmkdirentry = $ftpmkdir->get;
		$ftpmkdirentry =~ s/[\r\t\n]//g; 				# don't allow stupid directory names
		$ftplog->insert('end',"Creating $ftpmkdirentry directory...\n");
		$ftplog->update;
		$ftplog->yviewMoveto('1.'); # Scroll if necessary
		if ($ftp->mkdir($ftpmkdirentry)){
			ftplogger("OK.\n");
			if ($ftp->quot( 'chmod', (oct('0777')), $ftpmkdirentry)){
				ftplogger("Changed permissions on $ftpmkdirentry directory to 0777...\nOK.\n");
			}else{
				ftplogger("Could not change permissions directory...\nOK.\n");
			};
		}else{
			ftplogger("Could not create directory...\nOK.\n");
		}
		unless ($thisftpdir = $ftp->pwd()){
			ftpstatusnc();
			$ftp = 0;
		}
		undef (@{$ftpdircache{$thisftpdir}}); 	#Directory listing has changed, clear cache for that directory then
		ftpgetdir();				#get new directory listing
	}else{
		ftplogger("Can't create new directory unless connected...\nOK.\n");
		ftpstatusnc();
		$servlistbox->delete('0','end');
	}
}

sub ftpdisconnect{
	if ($ftp){
		$ftp->quit();
		ftpstatusnc();
		ftplogger("Ending connection to $ftphostname...\nOK.\n");
		$servlistbox->delete('0','end');
		$ftppwd->delete('1.0','end');
		undef $ftp;
		%ftpdircache = ();
	}
}

sub ftpupload{
	my ($upfile, $thisftpdir, $sentfile, $size, $howmany);
	$ftpinterrupt = 0;
	$howmany = 0;
	if ($ftp){
		$thisftpdir = $ftp->pwd();
		if ($thisftpdir eq '/'){
			my $ftpuploadcheck = $main->messageBox(
				-icon => 'question',
				-message => "Are you sure you want to upload to the root directory?",
				-title => 'Upload to root?',
				-type => 'YesNo',
			);
			return unless ($ftpuploadcheck =~ /yes/i);
		}
		$ftp->binary; # binary mode
		ftpstatus("Sending Files In Bin Mode...");
		my $senddir = $ftppwd->get('1.0','end');
		chop $senddir;
		$servlistbox->delete('0','end');
		while ($upfile = $ftpbatchbox->get('0')){
			$ftpbatchbox->delete('0');
			ftplogger("Sending $upfile to $ftphostname$senddir.... \n");
			($sentfile,$size) = ftpput($ftp,"stor",$upfile);
			ftplogger(" - Sent $size bytes.\nOK.\n");
			$servlistbox->insert('0',$sentfile);
			$servlistbox->update;
			$howmany++;
			last if $ftpinterrupt;
		}
		if ($ftpinterrupt){
			ftplogger("Batch Upload interrupted.\nOK.\n");
			$ftpinterrupt = 0;
		}
		ftpstatus("Connected...");
		ftplogger("Uploaded $howmany files to $ftphostname$senddir.\nOK.\n");
		$ftp->ascii;
		unless ($thisftpdir = $ftp->pwd()){
			ftpstatusnc();
			$ftp = 0;
		}
		undef @{$ftpdircache{$thisftpdir}};
		ftpgetdir();
	}else{
		ftpstatusnc();
		$servlistbox->delete('0','end');
		ftplogger("Can't upload files unless connected...\nOK.\n");
	}
}

sub ftpdownload{
	if ($ftp){
		$ftpmkdnldbutton->configure(-state=>'disabled');
		$ftpmkdirbutton->configure(-state=>'disabled');
		$ftpchdirbutton->configure(-state=>'disabled');
		$ftpcdubutton->configure(-state=>'disabled');
		$ftprenbutton->configure(-state=>'disabled');
		$ftpdelbutton->configure(-state=>'disabled');
		$ftpuplbutton->configure(-state=>'disabled');
		my ($size,$local);
		$ftpinterrupt = 0;
		my $thisftpdir = $ftp->pwd();
		my @selarray = $servlistbox->curselection;
		my $ftpdownload = shift @selarray;
		my $ftpdownloadname = (substr $ftpdirlist[$ftpdownload],8);
		$ftpdownloadname =~ s/( \/\/.*)$//;
		if ($ftpdirlist[$ftpdownload] =~ /^F/){
			$ftp->binary; # binary mode
			my $savefilename;
			$savefilename = $servlistbox->getSaveFile(-initialfile => $ftpdownloadname, -initialdir =>$ftpdownloaddir);
			$savefilename=~ s/\//$separator/g;
			if ($savefilename ne ''){
				ftpstatus("Downloading File...");
				ftplogger("Downloading $ftpdownloadname from $thisftpdir...\n");
				($size) = ftpget($ftp,$ftpdownloadname,$savefilename);
				ftplogger(" - Received $size bytes\nOK.\n");
				$ftpbatchbox->insert('end',$savefilename);
				$savefilename =~ s/$ftpdownloadname$//;
				$savefilename =~ s/(\/$|\\$)//;
				$ftpdownloaddir = $savefilename;
				save();
			}
			$ftp->ascii;
		}else{
			my $ftpdownloadcheck = $main->messageBox(
				-icon => 'question',
				-message => "Are you sure you want to download all of the files in the directory $ftpdownloadname ?",
				-title => 'Download All Files In Directory?',
				-type => 'YesNo',
			);
			if ($ftpdownloadcheck eq 'yes'){
				my ($ftpgetnextname, $savefilename);
				my $separatorline = "----------------------------------------------------------------------------";
				my $thisdir = getpwd();
				chdir $ftpdownloaddir if ($ftpdownloaddir ne '');
				my $savedirname;
				my $getdirnamedlg = $main->DialogBox(
					-title => "Select location to download $ftpdownloadname.",
					-buttons => ["OK", "Cancel"],
					);
				my $getdirname = $getdirnamedlg->add('ScrlListbox',
					-scrollbars => 		'oe',
					-width =>		'35',
					-height =>		'25',
					-background =>		'white',
					-selectmode =>		'single'
				)->pack();
				my $dnldpathname = $getdirnamedlg->add('Entry',
					-width =>	'40',
					-background =>	'white',
					-relief => 'sunken',
					-font => 	$helv,
				)->pack();
				my $patlabel = $getdirnamedlg->add('Label',
					-width => '30',
					-text => 'File Match Pattern',
				)->pack(-pady => '5');
				my $dnldpattern = $getdirnamedlg->add('Entry',
					-width =>	'30',
					-background =>	'white',
					-relief => 'sunken',
					-font => 	$helv,
				)->pack();
				$dnldpathname->insert(0, ($ftpdownloaddir)||".");
				my @savedrvlist = ();
				@savedrvlist = getdrives() if ($^O =~ /Win/);
				my @ftpgetdirlist = @savedrvlist;
				push @ftpgetdirlist, $separatorline if ($^O =~ /Win/);
				push @ftpgetdirlist, getdirs();
				$getdirname->insert('end', @ftpgetdirlist);
				$getdirname->eventAdd('<<Changeto>>' =>  '<Double-Button-1>');
				$getdirname->bind('<<Changeto>>', sub {
					my $selarray = $getdirname->curselection;
					my $changeto = $selarray[0];
					chdir $ftpgetdirlist[$changeto] unless ($ftpgetdirlist[$changeto] eq $separatorline);
					@ftpgetdirlist = @savedrvlist;
					push @ftpgetdirlist, $separatorline;
					push @ftpgetdirlist, getdirs();
					$getdirname->delete('0', 'end');
					$getdirname->insert('end', @ftpgetdirlist);
					$dnldpathname->delete(0,'end');
					$dnldpathname->insert(0, getpwd());
				});
				my $returnbutton = $getdirnamedlg->Show;
				$ftpdownloaddir =  $dnldpathname->get;
				my $filepattern = $dnldpattern->get || ".";
				if ($returnbutton eq 'OK'){
					$savedirname = $ftpdownloaddir;
					$savedirname =~ s/$ftpdownloadname$//; # strip file name off end of string
					$savedirname =~ s/(\/$|\\$)//;		#strip slashes off end of string
					$ftpdownloaddir = $savedirname;
					chdir $ftpdownloaddir;
					unless(opendir(DIR,"$ftpdownloadname")){
						mkdir ($ftpdownloadname,0777)
					};
					closedir DIR;
					save();
				}else{
					$savedirname = '';
				}
				if ($savedirname ne ''){
					$ftp->cwd($ftpdownloadname);
					ftplogger("Changing to ".$ftpdownloadname." directory...  Please wait.\n");
					ftpgetdir();
					my $dwnldftpdir = $ftp->pwd();
					unless (defined(@{$ftpdircache{$dwnldftpdir}})){
						$ftplog->insert('end',"This directory is not cached...\n");
						$ftplog->update;
						$ftplog->yviewMoveto('1.'); # Scroll if necessary
					}
					$ftp->binary; # binary mode
					my @ftpdownloadlist = @{$ftpdircache{$dwnldftpdir}};
					my $filecount;
					pop @ftpdownloadlist;
					pop @ftpdownloadlist;
					ftpstatus("Downloading files...");
					$servlistbox->delete('0','end');
					foreach $ftpgetnextname(@ftpdownloadlist){
						if (($ftpgetnextname =~ /^F/)&&($ftpgetnextname =~ /$filepattern/)){
							 $servlistbox->insert('end', $ftpgetnextname);
							 $filecount++;
						}
					}
					foreach $ftpgetnextname(@ftpdownloadlist){
						if (($ftpgetnextname =~ /^F/)&&($ftpgetnextname =~ /$filepattern/)){
							$filecount--;
							$ftpgetnextname = (substr $ftpgetnextname,8);
							$ftpgetnextname =~ s/( \/\/.*)$//;	# strip file size off end of string
							$savefilename = $savedirname.$separator.$ftpdownloadname.$separator.$ftpgetnextname;
							$savefilename =~ s/\//$separator/g;
							ftplogger("Downloading $ftpgetnextname from $dwnldftpdir to ".$savedirname.$separator.$ftpdownloadname." - $filecount files remaining.\n");
							$servlistbox->delete('0');
							($size) = ftpget($ftp,$ftpgetnextname,$savefilename);
							ftplogger(" - Received $size bytes\nOK.\n");
							$ftpbatchbox->insert('0',$savefilename);
							last if $ftpinterrupt;
						}
					}
					$ftp->ascii;
					if ($ftpinterrupt){
						ftplogger("Batch Download interrupted.\nOK.\n");
						$ftpinterrupt = 0;
					}
					$ftp->cdup();
				}
			my @filelist = $ftpbatchbox->get(0,'end');
			my (@uniq,$item);
			my %seen = ();
			foreach $item (@filelist) {
    				push(@uniq, $item) unless $seen{$item}++;
    			}
    			$ftpbatchbox->delete(0,'end');
			$ftpbatchbox->insert('end',(sort @uniq));
			$ftpbatchbox->update;
			ftpgetdir();
			chdir $thisdir;
			}
		}
		$ftpmkdnldbutton->configure(-state=>'normal');
		$ftpmkdirbutton->configure(-state=>'normal');
		$ftpchdirbutton->configure(-state=>'normal');
		$ftpcdubutton->configure(-state=>'normal');
		$ftprenbutton->configure(-state=>'normal');
		$ftpdelbutton->configure(-state=>'normal');
		$ftpuplbutton->configure(-state=>'normal');
		ftpstatus("Connected...");
	}
}

sub ftpstatusnc{
	ftpstatus("No Connection...");
	$ftp = 0;
}

sub ftprename{
	if ($ftp){
		my ($newname,$newnameentry, $thisftpdir);
		my @selarray = $servlistbox->curselection;
		my $rename = $selarray[0];
		my $oldname = (substr $ftpdirlist[$rename],8);
		$oldname =~ s/( \/\/.*)$//;			# strip file size off end of string
		my $ftpnewname = $main->DialogBox(-title => "Rename", -buttons => ["OK", "Cancel"]);
		$ftpnewname->add('Label',-text =>"     What do you what to rename $oldname to ?     ")->pack(-side => 'top', -anchor => 'n');
		$newnameentry = $ftpnewname->add('Entry', -relief => 'sunken', -background => 'white' )->pack(-side => 'top', -anchor => 'n');
		$newnameentry->insert(0, $oldname);
		my $getnewname = $ftpnewname->Show;
		if ($getnewname eq 'OK'){
			$newname = $newnameentry->get;
			$ftp->rename($oldname,$newname);
			ftplogger("$oldname has been changed to $newname.\nOK.\n");
			unless ($thisftpdir = $ftp->pwd()){
				ftpstatusnc();
				$ftp = 0;
			}
			undef @{$ftpdircache{$thisftpdir}};
			ftpgetdir();
		}
	}
}

sub ftpremove{
	my ($thisftpdir, $deletemessage);
	if ($ftp){
		my @selarray = $servlistbox->curselection;
		my $remove = $selarray[0];
		my $removeentity = (substr $ftpdirlist[$remove],8);
		$removeentity =~ s/( \/\/.*)$//;
		if ($ftpdirlist[$remove] =~ /^F/){
			$deletemessage = "Are you sure you want to delete the file $removeentity?";
		}else{
			$deletemessage = "Are you sure you want to remove the directory $removeentity?\n(Deleting a directory will delete everything inside it.)";
		}
		my $removecheck = $main->messageBox(
				-icon => 'question',
				-message => "$deletemessage",
				-title => 'Are You Sure?',
				-type => 'YesNo',
		);
		if($removecheck =~ /yes/i){
			if ($ftpdirlist[$remove] =~ /^F/){
				ftplogger("Deleting file $removeentity... \nOK.\n");
				$ftp->delete($removeentity);
				unless ($thisftpdir = $ftp->pwd()){
					ftpstatusnc();
					$ftp = 0;
				}
				undef @{$ftpdircache{$thisftpdir}};
				ftpgetdir();
			}elsif($ftpdirlist[$remove] =~ /^D/){
				$main->Busy;
				ftplogger("Removing directory $removeentity. Please wait, may take a while for directories with lots of files inside.\n");
				my $recursive = 1;
				if (ftprmdir($ftp,$removeentity,$recursive)){
					ftplogger("OK.\n");
					unless ($thisftpdir = $ftp->pwd()){
						ftpstatusnc();
						$ftp = 0;
					}
					undef (@{$ftpdircache{$thisftpdir}});
					ftpgetdir();
				}else{
					ftplogger("Could not remove directory. \nOK.\n");
				}
				$main->Unbusy;
				ftpstatus("Connected...");
			}
		}
	}else{
		ftpstatusnc();
		$servlistbox->delete('0','end');
	}
}

sub ftphelp{
	my $ftphelpbox = $main->messageBox(-title => "Help with FTP client", -type => "OK", -icon => 'question',
	-message => "A simple minimal featured FTP client. Suitable for uploading to DP and minor maintenance. \n\n".
	"From left to right in rows....\n\n".
	"Host name (Text Entry) - Defaults to pgdp01.archive.org\n".
	"User name (Text Entry) - Get it from the Project Managers page. Will be saved from session to session if Save Username & Password is checked.\n".
	"Password (Text Entry) - Get it from the Project Managers page. Will be saved from session to session if Save Username & Password is checked.\n".
	"Home Directory (Text Entry) - Preferred directory on the FTP server.\n\n".
	"Connect To Host (Push Button) - Initiate FTP connection. Will fail if you have no internet connection. May take a while on a slow connection.\n".
	"Disconnect (Push Button) - Break FTP connection.\n".
	"Save Log File (Push Button) - Save a session log to a file.\n".
	"Clear Log (Push Button) - Clear Session log.\n".
	"? (Push Button) - This window. :-)\n".
	"Save User & Password (Checkbox) - Option to save Username and Password.\n\n".
	"Session Log (Text Readout) - Commands and feedback issued during session.\n\n".
	"Status Box (Text Readout) - Connection monitor.\n\n".
	"Build Upload Batch (Push Button) - Make a standard batch. Adds all the .txt files in the text directory and all the .png files in the $imagesdir directory.\n".
	"Add File To Batch (Push Button) - Mostly to upload a few files instead of a standard batch. Adds a filename to the batch.\n".
	"Clear File List (Push Button) - Cancel batch before it is sent and clear batch list.\n".
	"Send Files (Push Button) - Transfer all of the files in the batch list to the ftp host in binary mode.\n".
	"Stop Transfer(Push Button) - Stop any batch transfers in progress.\n\n".
	"Make New Directory (Push Button) - Make a directory on the remote host in the current directory using the directory name from the Directory Name text entry.\n".
	"Directory Name (Text Entry) - Name to use when making a new directory on the remote server.\n".
	"Chdir Sel (Push Button) - Select a directory on the remote server and press Change to to change to it. Alternate - double left click.\n".
	"Chdir Up (Push Button) - Change directory on the remote server up one level.\n".
	"Download (Push Button) - Select a file on the remote server and press Download to download it. Alternate - double left click.\n".
	"Rename (Push Button) - Select a file or directory on the remote server then push Rename to rename it.\n".
	"Delete (Push Button) - Select a file or directory on the remote server then push Delete to delete it.\n\n".
	"Present Directory (Text Readout) - The directory you are currently browsing / working in on the remote host.\n\n".
	"Upload File List (Text Readout) - List of files that will be uploaded when Send Files is pressed.\n".
	"Remote Directory Listing (Text Readout) - A listing of all of the files and directories in the current directory on the remote host.\n\n".
	"The remote directory listing shows files prefixed by 'FILE - ' with the byte size after. Directories are prefixed by 'DIR -  '. \n\n".
	"When deleting directories, they do not need to be empty to be deleted.\nBE SURE YOU WANT TO DO THIS. It will ask for confirmation.\n\n".
	"You can view files in the local list (if they are text or image files) by double left clicking on them.\n".
	"You can remove one or several files from the local list by highlighting the file name(s) then double right clicking.\n\n".
	"For files in the local list, double click on a file name to view it (if it is a text or image file).\n".
	"Select one or more file names and double right click to remove the names from the list."
	);
}

##########################################################################################################################
#### Modified $ftp->get and $ftp->put routines to be non blocking in TK  #################################################
#### Heavily based on the Net::FTP module distributed with perl.  From the Net::FTP.pm header :  #########################
#
# Net::FTP.pm
# Copyright (c) 1995-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##########################################################################################################################
sub ftprmdir{
	my ($ftp, $dir, $recurse) = @_ ;
	my $ok;
	return $ok if $ok = $ftp->_RMD( $dir ) or !$recurse;
	my $filelist = $ftp->ls($dir);
	return undef unless $filelist && @$filelist; # failed, it is probably not a directory
	my $file;
	foreach $file (map { m,/, ? $_ : "$dir/$_" } @$filelist){
		if ($ftp->delete($file)){ftpstatus("Deleting file $file..."); next};
		unless ($ok = $ftp->rmdir($file, 1)){ftpstatus("Removing Subdirectory $file..."); return $ok};
	}
	return $ftp->_RMD($dir) ;
}

sub ftpget{

	use Fcntl qw(O_WRONLY O_RDONLY O_APPEND O_CREAT O_TRUNC);	# Comments? We ain' got no comments...  We don' need no stinkin' comments!!
	my($ftp,$remote,$local,$where) = @_;
	my $filesize = $ftp->size($remote);
	ftpstatus("0% - Received 0 of $filesize bytes in Bin mode.");
	my($loc,$len,$buf,$resp,$data);
	local *FD;
	my $localfd = ref($local) || ref(\$local) eq "GLOB";
	($local = $remote) =~ s#^.*/## unless(defined $local);
 	croak("Bad remote filename '$remote'\n") if $remote =~ /[\r\n]/s;
 	${*$ftp}{'net_ftp_rest'} = $where if ($where);
 	delete ${*$ftp}{'net_ftp_port'};
	delete ${*$ftp}{'net_ftp_pasv'};
	$data = $ftp->retr($remote) or return undef;
	if($localfd){
		$loc = $local;
	}else{
		$loc = \*FD;
		unless(sysopen($loc, $local, O_CREAT | O_WRONLY | ($where ? O_APPEND : O_TRUNC))){
			$data->abort;
			return undef;
		}
 	}
	if($ftp->type eq 'I' && !binmode($loc)){
		$data->abort;
		close($loc) unless $localfd;
		return undef;
	}
	$buf = '';
	my($count,$size,$ind);
	my @indicator = ('|','/','-','\\');
	my $blksize = ${*$ftp}{'net_ftp_blksize'};
	my ($rate,$running, $tr);
	my (@time, @lasttime, $elapse);
	my @starttime = @lasttime = gettimeofday();
	$running = 1;
	while(1){
		last unless $len = $data->read($buf,$blksize);
		$ind = ++$ind % 4;
		$count += $len;
		$size += $len;
		@time = gettimeofday();
		$elapse = tv_interval( \@lasttime , \@time );
		$rate = ($len/$elapse/$ftpscale) if $elapse;
		$running =(($rate + $running * 9)/10);
		@lasttime = @time;
		$tr = (tv_interval( \@starttime , \@time ));
		$tr = ($tr/$size*$filesize)-$tr;
		ftpstatus((int($size/$filesize*100))."% - Received $size of $filesize bytes at ".(sprintf("%.1f",$running)).($ftpscale == 128?" Kbps":" KBps")." - ".(sprintf("%.1f",$tr))." seconds left");
		$ftplog->delete('end -2c','end -1c');
		$ftplog->insert('end',$indicator[$ind]);
		$count %= $blksize;
		my $written = syswrite($loc,$buf,$len);
		unless(defined($written) && $written == $len){
			$data->abort;
			close($loc) unless $localfd;
			return undef;
		}
	}
	$elapse = tv_interval( \@starttime , \@time );
	$rate = ($size/$elapse/$ftpscale) if $elapse;
	ftplogger(" - ".(sprintf("%.2f",$elapse))." seconds @ ".(sprintf("%.2f",$rate))."Avg. ".($ftpscale == 128?" Kilobits per second":" KiloBytes per second"));
	unless ($localfd){
		unless (close($loc)){
			return undef;
		}
	}
	unless ($data->close()){# implied $ftp->response
		return undef;
	}
	return ($size);
}

sub ftpput{
	my($ftp,$cmd,$local,$remote) = @_;			# $cmd must be one of 'stor' - store, or 'stou' - store unique.
	my $filesize = (-s $local);
	ftpstatus("0% - Sent 0 of $filesize bytes in Bin Mode.");
	my($loc,$sock,$len,$buf);				# there other options in the standard module but I'm not supporting them here
	local *FD;
	my $localfd = ref($local) || ref(\$local) eq "GLOB";
	unless(defined $remote){
		require File::Basename;
		$remote = File::Basename::basename($local);
	}
	if($localfd){
		$loc = $local;
	}else{
		$loc = \*FD;
		unless(sysopen($loc, $local, O_RDONLY)){
			return undef;
		}
	}
	if($ftp->type eq 'I' && !binmode($loc)){
		return undef;
	}
	delete ${*$ftp}{'net_ftp_port'};
	delete ${*$ftp}{'net_ftp_pasv'};
	$sock = $ftp->_data_cmd($cmd, $remote) or return undef;
	my $blksize = 2048; #${*$ftp}{'net_ftp_blksize'};
	my($count,$size,$delay) = (0);
	my @indicator = ('|','/','-','\\');
	my $ind;
	my ($rate,$running, $tr);
	my (@time, @lasttime, $elapse);
	my @starttime = @lasttime = gettimeofday();
	$running = 1;
	while(1){
		last unless $len = sysread($loc,$buf="",$blksize);
		$ind = ++$ind % 4;
		$count += $len;
		$size += $len;
		$delay++;
		@time = gettimeofday();
		$elapse = tv_interval( \@lasttime , \@time );
		$rate = ($len/$elapse/$ftpscale) if $elapse;
		$rate = 1 unless $delay > 2; 			# delay tracking until the rate has stabilized a bit
		$running = ($rate/5 + $running * .8);
		$running = $rate if ($delay == 2);		# give the running average a decent starting point
		@lasttime = @time;
		$tr = (tv_interval( \@starttime , \@time ));
		$tr = ($tr/$size*$filesize)-$tr;
		ftpstatus((int($size/$filesize*100))."% - Sent $size of $filesize bytes at ".(sprintf("%.1f",$running))." ".($ftpscale == 128?" Kbps":" KBps")." - ".(sprintf("%.1f",$tr))." seconds left");
		$ftplog->delete('end -2c','end -1c');
		$ftplog->insert('end',$indicator[$ind]);
		$count %= $blksize;
		my $wlen;
		unless(defined($wlen = $sock->write($buf,$len)) && $wlen == $len){
			$sock->abort;
			close($loc) unless $localfd;
			return undef;
		}
	}
	$elapse = tv_interval( \@starttime , \@time );
	$rate = ($size/$elapse/$ftpscale) if $elapse;
	ftplogger(" - ".(sprintf("%.2f",$elapse))." seconds @".(sprintf("%.2f",$rate))."Avg. ".($ftpscale == 128?" Kilobits per second":" KiloBytes per second"));
	close($loc) unless $localfd;
	$sock->close() or return undef;
	if ('STOU' eq uc $cmd and $ftp->message =~ m/unique\s+file\s*name\s*:\s*(.*)\)|"(.*)"/){
		require File::Basename;
		$remote = File::Basename::basename($+)
	}
	return ($remote,$size);
}

#######################################################################################################################
#
### Sub routines used by the Search & Replace Tab #####################################################################
#
sub search{
	my ($searchterm,  $endindex, $count);
	$searchterm = $searchentry->get; 				# get the search term
	$displaybox->focus;						# put the cursor in the text box
	if (($searchterm eq $thissearch)&&($thissearch ne '')){
		if ($searchstartindex ne ''){
			unless (searchtext($searchterm)){		# There was no successful search in Tk text
				$foundfile = searchfiles();
				searchtext($searchterm)
			}
		}elsif ($foundfile = searchfiles()){			# There was a successful search in tk text
			$searchendindex = '0.0';
			searchtext($searchterm);
		}
	}else{
		$search = 0;						# Must be a new search, initialize variables
		$thissearch = $searchterm;
		if ($foundfile = searchfiles()){			# Found a file with the search text?
				$searchendindex = '0.0';
		}
		searchtext($searchterm);				# Do a Tk text search on the file
	}
	if($foundfile eq 'END'){
		$displaybox->tagRemove('highlight','1.0','end');
		$displaybox->markSet('insert','1.0');
		$searchstartindex = '';
	}
	return $foundfile;						# Return the file name.
}

sub searchsave{
		# Save the text from the text box to the last opened file
		open (SAVE, ">text/$searchfilelist[$filesearchindex]");
		if ($displaybox->index('end') > 2.0){
			while ($displaybox->get('end -2c') =~ /[\s\n]/){last if ($displaybox->index('end') < 2.0);$displaybox->delete('end -2c'); };
			$displaybox->insert('end',"\n");
		}
		my $file = $displaybox->get('1.0','end -1c');
		utf8::encode $file;
		print SAVE $file;
		close SAVE;
		$displaybox->ResetUndo;

}
sub searchclear{
	$displaybox->delete('1.0','end');
	$searchfile->delete('1.0','end');
	$search = 0;
	$searchstartindex = '';
	$thissearch = '';
}

sub searchtext{
	my $searchterm = shift;
	my $tempindex;
	my $exactsearch = $searchterm;
	$exactsearch =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;	# escape meta characters for whole word matching
	if (($opt[62]) && ($opt[51])){							# use the appropriate search.
		$searchstartindex = $displaybox->search('-nocase', '-regexp','--', '(?<=\b)'.$exactsearch.'(?=\b)', $searchendindex, 'end');
	}elsif(($opt[62]) && !($opt[51])){
		$searchstartindex = $displaybox->search('-regexp','--','(?<=\b)'.$exactsearch.'(?=\b)', $searchendindex, 'end');
	}elsif(!($opt[62]) && ($opt[51])){
		$searchstartindex = $displaybox->search('-nocase','--', $searchterm, $searchendindex, 'end');
	}elsif(!($opt[62]) && !($opt[51])){
		$searchstartindex = $displaybox->search('--', $searchterm, $searchendindex, 'end');
	}
	$tempindex = $searchstartindex;
	$tempindex =~ s/(?<=\.)(\d\b)/00$1/;
	$tempindex =~ s/(?<=\.)(\d\d\b)/0$1/;				# fix up index variables, can't have leading zeros in decimal portion. (char position)
	$searchendindex = sprintf("%.3f", (length($searchterm)/1000 + $tempindex));		# Arrg. Took me HOURS to track THAT one down....
	$searchendindex =~ s/(?<=\.)0+(\d+)/$1/;
	$displaybox->markSet('insert',$searchstartindex) if $searchstartindex;	# position the cursor at the index
	$displaybox->tagAdd('highlight',$searchstartindex,$searchendindex)if $searchstartindex;	# highlight the text
	$displaybox->see($searchstartindex)if $searchstartindex;				# scroll text box, if necessary, to make found text visible
	return $searchstartindex;								# return index of where found text started
}

sub searchfiles{
	my ($filenumber, $lineindex, $charindex, $file, $lcfile, $wordsearchterm);

	my $searchterm = $searchentry->get;				# get search term
	$filesearchindex++;
	$displaybox->delete('1.0','end');				# clean out text box
	$searchfile->delete('1.0','end');				# and file name
	$searchterm =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;	# escape any meta characters in search term
	$searchterm = lc($searchterm) if $opt[51];			# make search term lower case if case insensitive
	if ($searchterm ne ''){						# if not a new search
		if (chdir"text"){
			$filenumber = scalar @searchfilelist;		# get the number of files
			chdir"..";
			unless ($search){
				$search = 1;				# search in progress
				$filesearchindex = 0;			# reset file index
			}
		}else{
			$main->messageBox(
				-icon => 'error',
				-message => "Can not find text directory.",
				-title => 'Text files not found.',
				-type => 'Ok',
			);
		}
	}

	while ($filesearchindex < $filenumber){				# while there are still files remaining
		$lineindex = 0;
		{
			local(*INFILE, $/);				# slurp file in
			open (INFILE, "<text/$searchfilelist[$filesearchindex]");
			$file = <INFILE>;
			close INFILE;
		}
		if ($opt[51]){						# lower case copy of whole file if case insensitive
			$lcfile = lc($file);
		}else{
			$lcfile = $file;
		}
		$wordsearchterm = $searchterm;
		$wordsearchterm = ('\b'.$searchterm.'\b') if $opt[62];	# build a search pattern for whole word searching
		if (((!$opt[62])&&($lcfile =~ /$wordsearchterm/))||(($opt[62])&&($lcfile =~ /$wordsearchterm/))){ # if a word is found matching an option set
			utf8::decode($file);							# convert unicode
			$displaybox->insert('end',$file);			# dump the file into the textbox
			$displaybox->yview('scroll',1,'units');
			$displaybox->update;
			$displaybox->yview('scroll',-1,'units');
			$filesearchindex1 = ($filesearchindex+1);
			$searchfile->insert('end',"File - ".@searchfilelist[$filesearchindex].": $filesearchindex1 of $filenumber");	#display the file name
			$searchfile->update;
			return ($searchfilelist[$filesearchindex]); 	# return the file name of the file you just loaded into the textbox
		}
		$filesearchindex++;					# term not found, increment file index and try again
	}								# all out of files

	$main->messageBox(
		-icon => 'error', 					# Let user know
		-message => "No more occurances of text string \"".$searchentry->get."\" found.",
		-title => 'Text not found.',
		-type => 'Ok',
	);
	$search = 0;							#reset variables
	$searchstartindex = '';
	$filesearchindex1 = 1;
	searchincdec();
	return 'END';							# return with a message
}

sub replace{
	my $replaceterm = shift;						# get replacement text
	$displaybox->delete($searchstartindex,$searchendindex)if $searchstartindex;	# delete found text
	$displaybox->insert($searchstartindex,$replaceterm)if $searchstartindex;	# insert replacement text
	searchsave();
}

sub replaceall{
	my $file;
	$search = 0;
	$thissearch = '';
	while (($file = search()) ne 'END'){					# keep calling search() and replace() until you run out of files
		replace($replaceentry1->get);
	}
}

sub searchincdec{
	&searchsave if ($displaybox->numberChanges >1);
	$filesearchindex = ($filesearchindex1 - 1);
	my ($filenumber, $file, $index);
	if (chdir"text"){
		unless ($filenumber = scalar @searchfilelist){@searchfilelist = glob"*.txt"};		# get a list of files
		$filenumber = scalar @searchfilelist;							# and the number of files
		chdir"..";
	}else{
		$main->messageBox(
			-icon => 'error',
			-message => "Can not find text directory.",
			-title => 'Text files not found.',
			-type => 'Ok',
		);
	}
	unless ($filenumber){
		$main->messageBox(
			-icon => 'error',
			-message => "No text files found in text directory.",
			-title => 'Text files not found.',
			-type => 'Ok',
		);
	$searchfileslist->delete('0',"end");
	$filenumber = 0;
	return 0;
	}
	if ($filesearchindex < 0){$filesearchindex = 0}
	if ($filesearchindex >= $filenumber){$filesearchindex--};
	$searchfileslist->delete('0',"end");
	if ($filenumber){foreach $index(1..$filenumber) {$searchfileslist->insert("end", $index)}};
	{
		local(*INFILE, $/);						# slurp file in
		open (INFILE, "<text/$searchfilelist[$filesearchindex]");
		$file = <INFILE>;
		close INFILE;
	}
	$filesearchindex1 = ($filesearchindex+1);
	$displaybox->delete('1.0','end');					# clean out text box
	$searchfile->delete('1.0','end');					# and file name
	utf8::decode($file);							# convert unicode
	$displaybox->insert('end',$file);			# dump the file into the textbox
	$displaybox->update;
	$searchfile->insert('end',"File - ".@searchfilelist[$filesearchindex].": $filesearchindex1 of $filenumber");	#display the file name
	$searchfile->update;
	return 0;
}

sub BindMouseWheel{
	my($w) = @_;
	if ($^O eq 'MSWin32'){
		$w->bind('<MouseWheel>' =>
		[ sub { $_[0]->yview('scroll', -($_[1] / 120) * 3, 'units') },
		Ev('D') ]);
	}else{
		$w->bind('<4>' => sub {
			$_[0]->yview('scroll', -3, 'units') unless $Tk::strictMotif;
			});
	$w->bind('<5>' => sub {
		$_[0]->yview('scroll', +3, 'units') unless $Tk::strictMotif;
		});
	}
} # end BindMouseWheel

sub runner{
	my $args;
	$args = join ' ', @_;
	if ($^O =~ /Win/) {
		$args = '"'.$args.'"';
	}else{
		$args .= ' &';
	}
	system "perl spawn.pl $args";
}

sub fromgreektr{
	my $phrase = shift;
	$phrase =~ s/\x{03C2}(\W)/s$1/g;
	$phrase =~ s/\x{03B8}/th/g;
	$phrase =~ s/\x{03B3}\x{03B3}/ng/g;
	$phrase =~ s/\x{03B3}\x{03BA}/nk/g;
	$phrase =~ s/\x{03B3}\x{03BE}/nx/g;
	$phrase =~ s/\x{1FE5}/rh/g;
	$phrase =~ s/\x{03C6}/ph/g;
	$phrase =~ s/\x{03B3}\x{03C7}/nch/g;
	$phrase =~ s/\x{03C7}/ch/g;
	$phrase =~ s/\x{03C8}/ps/g;
	$phrase =~ s/\x{1F01}/ha/g;
	$phrase =~ s/\x{1F11}/he/g;
	$phrase =~ s/\x{1F21}/hъ/g;
	$phrase =~ s/\x{1F31}/hi/g;
	$phrase =~ s/\x{1F41}/ho/g;
	$phrase =~ s/\x{1F51}/hy/g;
	$phrase =~ s/\x{1F61}/hє/g;
	$phrase =~ s/\x{03A7}/Ch/g;
	$phrase =~ s/\x{0398}/Th/g;
	$phrase =~ s/\x{03A6}/Ph/g;
	$phrase =~ s/\x{03A8}/Ps/g;
	$phrase =~ s/\x{1F09}/Ha/g;
	$phrase =~ s/\x{1F19}/He/g;
	$phrase =~ s/\x{1F29}/Hъ/g;
	$phrase =~ s/\x{1F39}/Hi/g;
	$phrase =~ s/\x{1F49}/Ho/g;
	$phrase =~ s/\x{1F59}/Hy/g;
	$phrase =~ s/\x{1F69}/Hє/g;
	$phrase =~ s/\x{0391}/A/g;
	$phrase =~ s/\x{03B1}/a/g;
	$phrase =~ s/\x{0392}/B/g;
	$phrase =~ s/\x{03B2}/b/g;
	$phrase =~ s/\x{0393}/G/g;
	$phrase =~ s/\x{03B3}/g/g;
	$phrase =~ s/\x{0394}/D/g;
	$phrase =~ s/\x{03B4}/d/g;
	$phrase =~ s/\x{0395}/E/g;
	$phrase =~ s/\x{03B5}/e/g;
	$phrase =~ s/\x{0396}/Z/g;
	$phrase =~ s/\x{03B6}/z/g;
	$phrase =~ s/\x{0397}/Ъ/g;
	$phrase =~ s/\x{03B7}/ъ/g;
	$phrase =~ s/\x{0399}/I/g;
	$phrase =~ s/\x{03B9}/i/g;
	$phrase =~ s/\x{039A}/K/g;
	$phrase =~ s/\x{03BA}/k/g;
	$phrase =~ s/\x{039B}/L/g;
	$phrase =~ s/\x{03BB}/l/g;
	$phrase =~ s/\x{039C}/M/g;
	$phrase =~ s/\x{03BC}/m/g;
	$phrase =~ s/\x{039D}/N/g;
	$phrase =~ s/\x{03BD}/n/g;
	$phrase =~ s/\x{039E}/X/g;
	$phrase =~ s/\x{03BE}/x/g;
	$phrase =~ s/\x{039F}/O/g;
	$phrase =~ s/\x{03BF}/o/g;
	$phrase =~ s/\x{03A0}/P/g;
	$phrase =~ s/\x{03C0}/p/g;
	$phrase =~ s/\x{03A1}/R/g;
	$phrase =~ s/\x{03C1}/r/g;
	$phrase =~ s/\x{03A3}/S/g;
	$phrase =~ s/\x{03C3}/s/g;
	$phrase =~ s/\x{03A4}/T/g;
	$phrase =~ s/\x{03C4}/t/g;
	$phrase =~ s/\x{03A9}/д/g;
	$phrase =~ s/\x{03C9}/є/g;
	$phrase =~ s/\x{03A5}(?=\W)/Y/g;
	$phrase =~ s/\x{03C5}(?=\W)/y/g;
	$phrase =~ s/(?<=\W)\x{03A5}/U/g;
	$phrase =~ s/(?<=\W)\x{03C5}/u/g;
	$phrase =~ s/(?<=[AEIOU])\x{03A5}/U/g;
	$phrase =~ s/(?<=[aeiou])\x{03C5}/u/g;
	$phrase =~ s/\x{03A5}/Y/g;
	$phrase =~ s/\x{03C5}/y/g;
	$phrase =~ s/(\p{Upper}\p{Lower}\p{Upper})/\U$1\E/g;
	return $phrase;
}

sub betagreek{
	my $phrase = shift;

	my %grkbeta1 = (
		"\x{1F00}" => 'a)',
		"\x{1F01}" => 'a(',
		"\x{1F08}" => 'A)',
		"\x{1F09}" => 'A(',
		"\x{1FF8}" => 'O\\',
		"\x{1FF9}" => 'O/',
		"\x{1FFA}" => 'д\\',
		"\x{1FFB}" => 'д/',
		"\x{1FFC}" => 'д|',
		"\x{1F10}" => 'e)',
		"\x{1F11}" => 'e(',
		"\x{1F18}" => 'E)',
		"\x{1F19}" => 'E(',
		"\x{1F20}" => 'ъ)',
		"\x{1F21}" => 'ъ(',
		"\x{1F28}" => 'Ъ)',
		"\x{1F29}" => 'Ъ(',
		"\x{1F30}" => 'i)',
		"\x{1F31}" => 'i(',
		"\x{1F38}" => 'I)',
		"\x{1F39}" => 'I(',
		"\x{1F40}" => 'o)',
		"\x{1F41}" => 'o(',
		"\x{1F48}" => 'O)',
		"\x{1F49}" => 'O(',
		"\x{1F50}" => 'y)',
		"\x{1F51}" => 'y(',
		"\x{1F59}" => 'Y(',
		"\x{1F60}" => 'є)',
		"\x{1F61}" => 'є(',
		"\x{1F68}" => 'д)',
		"\x{1F69}" => 'д(',
		"\x{1F70}" => 'a\\',
		"\x{1F71}" => 'a/',
		"\x{1F72}" => 'e\\',
		"\x{1F73}" => 'e/',
		"\x{1F74}" => 'ъ\\',
		"\x{1F75}" => 'ъ/',
		"\x{1F76}" => 'i\\',
		"\x{1F77}" => 'i/',
		"\x{1F78}" => 'o\\',
		"\x{1F79}" => 'o/',
		"\x{1F7A}" => 'y\\',
		"\x{1F7B}" => 'y/',
		"\x{1F7C}" => 'є\\',
		"\x{1F7D}" => 'є/',
		"\x{1FB0}" => 'a=',
		"\x{1FB1}" => 'a_',
		"\x{1FB3}" => 'a|',
		"\x{1FB6}" => 'a~',
		"\x{1FB8}" => 'A=',
		"\x{1FB9}" => 'A_',
		"\x{1FBA}" => 'A\\',
		"\x{1FBB}" => 'A/',
		"\x{1FBC}" => 'A|',
		"\x{1FC3}" => 'ъ|',
		"\x{1FC6}" => 'ъ~',
		"\x{1FC8}" => 'E\\',
		"\x{1FC9}" => 'E/',
		"\x{1FCA}" => 'Ъ\\',
		"\x{1FCB}" => 'Ъ/',
		"\x{1FCC}" => 'Ъ|',
		"\x{1FD0}" => 'i=',
		"\x{1FD1}" => 'i_',
		"\x{1FD6}" => 'i~',
		"\x{1FD8}" => 'I=',
		"\x{1FD9}" => 'I_',
		"\x{1FDA}" => 'I\\',
		"\x{1FDB}" => 'I/',
		"\x{1FE0}" => 'y=',
		"\x{1FE1}" => 'y_',
		"\x{1FE4}" => 'r)',
		"\x{1FE5}" => 'r(',
		"\x{1FE6}" => 'y~',
		"\x{1FE8}" => 'Y=',
		"\x{1FE9}" => 'Y_',
		"\x{1FEA}" => 'Y\\',
		"\x{1FEB}" => 'Y/',
		"\x{1FEC}" => 'R(',
		"\x{1FF6}" => 'є~',
		"\x{1FF3}" => 'є|',
		"\x{03AA}" => 'I+',
		"\x{03AB}" => 'Y+',
		"\x{03CA}" => 'i+',
		"\x{03CB}" => 'y+',
	);

	my %grkbeta2 = (
		"\x{1F02}" => 'a)\\',
		"\x{1F03}" => 'a(\\',
		"\x{1F04}" => 'a)/',
		"\x{1F05}" => 'a(/',
		"\x{1F06}" => 'a~)',
		"\x{1F07}" => 'a~(',
		"\x{1F0A}" => 'A)\\',
		"\x{1F0B}" => 'A(\\',
		"\x{1F0C}" => 'A)/',
		"\x{1F0D}" => 'A(/',
		"\x{1F0E}" => 'A~)',
		"\x{1F0F}" => 'A~(',
		"\x{1F12}" => 'e)\\',
		"\x{1F13}" => 'e(\\',
		"\x{1F14}" => 'e)/',
		"\x{1F15}" => 'e(/',
		"\x{1F1A}" => 'E)\\',
		"\x{1F1B}" => 'E(\\',
		"\x{1F1C}" => 'E)/',
		"\x{1F1D}" => 'E(/',
		"\x{1F22}" => 'ъ)\\',
		"\x{1F23}" => 'ъ(\\',
		"\x{1F24}" => 'ъ)/',
		"\x{1F25}" => 'ъ(/',
		"\x{1F26}" => 'ъ~)',
		"\x{1F27}" => 'ъ~(',
		"\x{1F2A}" => 'Ъ)\\',
		"\x{1F2B}" => 'Ъ(\\',
		"\x{1F2C}" => 'Ъ)/',
		"\x{1F2D}" => 'Ъ(/',
		"\x{1F2E}" => 'Ъ~)',
		"\x{1F2F}" => 'Ъ~(',
		"\x{1F32}" => 'i)\\',
		"\x{1F33}" => 'i(\\',
		"\x{1F34}" => 'i)/',
		"\x{1F35}" => 'i(/',
		"\x{1F36}" => 'i~)',
		"\x{1F37}" => 'i~(',
		"\x{1F3A}" => 'I)\\',
		"\x{1F3B}" => 'I(\\',
		"\x{1F3C}" => 'I)/',
		"\x{1F3D}" => 'I(/',
		"\x{1F3E}" => 'I~)',
		"\x{1F3F}" => 'I~(',
		"\x{1F42}" => 'o)\\',
		"\x{1F43}" => 'o(\\',
		"\x{1F44}" => 'o)/',
		"\x{1F45}" => 'o(/',
		"\x{1F4A}" => 'O)\\',
		"\x{1F4B}" => 'O(\\',
		"\x{1F4C}" => 'O)/',
		"\x{1F4D}" => 'O(/',
		"\x{1F52}" => 'y)\\',
		"\x{1F53}" => 'y(\\',
		"\x{1F54}" => 'y)/',
		"\x{1F55}" => 'y(/',
		"\x{1F56}" => 'y~)',
		"\x{1F57}" => 'y~(',
		"\x{1F5B}" => 'Y(\\',
		"\x{1F5D}" => 'Y(/',
		"\x{1F5F}" => 'Y~(',
		"\x{1F62}" => 'є)\\',
		"\x{1F63}" => 'є(\\',
		"\x{1F64}" => 'є)/',
		"\x{1F65}" => 'є(/',
		"\x{1F66}" => 'є~)',
		"\x{1F67}" => 'є~(',
		"\x{1F6A}" => 'д)\\',
		"\x{1F6B}" => 'д(\\',
		"\x{1F6C}" => 'д)/',
		"\x{1F6D}" => 'д(/',
		"\x{1F6E}" => 'д~)',
		"\x{1F6F}" => 'д~(',
		"\x{1F80}" => 'a)|',
		"\x{1F81}" => 'a(|',
		"\x{1F88}" => 'A)|',
		"\x{1F89}" => 'A(|',
		"\x{1F90}" => 'ъ)|',
		"\x{1F91}" => 'ъ(|',
		"\x{1F98}" => 'Ъ)|',
		"\x{1F99}" => 'Ъ(|',
		"\x{1FA0}" => 'є)|',
		"\x{1FA1}" => 'є(|',
		"\x{1FA8}" => 'д)|',
		"\x{1FA9}" => 'д(|',
		"\x{1FB2}" => 'a\|',
		"\x{1FB4}" => 'a/|',
		"\x{1FB7}" => 'a~|',
		"\x{1FC2}" => 'ъ\|',
		"\x{1FC4}" => 'ъ/|',
		"\x{1FC7}" => 'ъ~|',
		"\x{1FD2}" => 'i\+',
		"\x{1FD3}" => 'i/+',
		"\x{1FD7}" => 'i~+',
		"\x{1FE2}" => 'y\+',
		"\x{1FE3}" => 'y/+',
		"\x{1FE7}" => 'y~+',
		"\x{1FF2}" => 'є\|',
		"\x{1FF4}" => 'є/|',
		"\x{1FF7}" => 'є~|',
		"\x{0390}" => 'i/+',
		"\x{03B0}" => 'y/+',
	);

	my %grkbeta3 = (
		"\x{1F82}" => 'a)\|',
		"\x{1F83}" => 'a(\|',
		"\x{1F84}" => 'a)/|',
		"\x{1F85}" => 'a(/|',
		"\x{1F86}" => 'a~)|',
		"\x{1F87}" => 'a~(|',
		"\x{1F8A}" => 'A)\|',
		"\x{1F8B}" => 'A(\|',
		"\x{1F8C}" => 'A)/|',
		"\x{1F8D}" => 'A(/|',
		"\x{1F8E}" => 'A~)|',
		"\x{1F8F}" => 'A~(|',
		"\x{1F92}" => 'ъ)\|',
		"\x{1F93}" => 'ъ(\|',
		"\x{1F94}" => 'ъ)/|',
		"\x{1F95}" => 'ъ(/|',
		"\x{1F96}" => 'ъ~)|',
		"\x{1F97}" => 'ъ~(|',
		"\x{1F9A}" => 'Ъ)\|',
		"\x{1F9B}" => 'Ъ(\|',
		"\x{1F9C}" => 'Ъ)/|',
		"\x{1F9D}" => 'Ъ(/|',
		"\x{1F9E}" => 'Ъ~)|',
		"\x{1F9F}" => 'Ъ~(|',
		"\x{1FA2}" => 'є)\|',
		"\x{1FA3}" => 'є(\|',
		"\x{1FA4}" => 'є)/|',
		"\x{1FA5}" => 'є(/|',
		"\x{1FA6}" => 'є~)|',
		"\x{1FA7}" => 'є~(|',
		"\x{1FAA}" => 'д)\|',
		"\x{1FAB}" => 'д(\|',
		"\x{1FAC}" => 'д)/|',
		"\x{1FAD}" => 'д(/|',
		"\x{1FAE}" => 'д~)|',
		"\x{1FAF}" => 'д~(|',
	);

	for (keys %grkbeta1){
		$phrase =~ s/$_/$grkbeta1{$_}/g;
	}
	for (keys %grkbeta2){
		$phrase =~ s/$_/$grkbeta2{$_}/g;
	}
	for (keys %grkbeta3){
		$phrase =~ s/$_/$grkbeta3{$_}/g;
	}
	$phrase =~ s/\x{0386}/A\//g;
	$phrase =~ s/\x{0388}/E\//g;
	$phrase =~ s/\x{0389}/Ъ\//g;
	$phrase =~ s/\x{038C}/O\//g;
	$phrase =~ s/\x{038E}/Y\//g;
	$phrase =~ s/\x{038F}/д\//g;
	$phrase =~ s/\x{03AC}/a\//g;
	$phrase =~ s/\x{03AD}/e\//g;
	$phrase =~ s/\x{03AE}/ъ\//g;
	$phrase =~ s/\x{03AF}/i\//g;
	$phrase =~ s/\x{03CC}/o\//g;
	$phrase =~ s/\x{03CE}/є\//g;
	$phrase =~ s/\x{03CD}/y\//g;
	return fromgreektr($phrase)
}

