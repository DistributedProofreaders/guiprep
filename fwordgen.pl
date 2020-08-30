use Storable;
my (%words,%fwords,@multi,$word,$hold,$last,$wt,$ws,$mv,$mmv,$hold1);


open (WLIST, "<2of4brif.txt");


while ($word = <WLIST>){
	chomp $word;
	$words{$word}='';
	$wt++;
}
close WLIST;
open (OUT, ">dup.txt");
foreach $word (keys %words){
	$hold = $word;		
	$last = chop $word;
	if ($word =~ s/s/f/g){
		$ws++;
		if (exists $words{$word.$last}){
			print OUT $hold,"\n";
			$hold1 = $hold;
			$last = chop $hold;
			$hold =~ s/s/*/g;
			$hold .= $last;
			$mv++;
		}
		if (exists $fwords{$word.$last}){
			push @multi, $word.$last;
			print OUT $hold,"\n";
		}
		$fwords{$word.$last} = $hold;
	}
}
foreach $word(@multi){
	$hold = $word;
	$last = chop $hold;
	$hold =~ s/f/*/g;
	$hold .= $last;
	$fwords{$word} = $hold;
	$mmv++;
}
print "$wt total words checked, $ws fcanno words, $mv words where fcanno is a regular word, $mmv words with more than 1 variation.";
store \%fwords, 'fcannos.bin';
