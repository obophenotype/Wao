#!/usr/bin/perl -w
# Script finds anatomy terms in wormatlas *.htm* files and ranks them
use strict;

my $excludedterms = "Cell|Time|Function|Anatomy|left-right|Lineage|Nucleus|axis|hermaphrodite-specific\
|male-specific|organ|anterior-posterior|neuron|neurone";

my $excludedfiles = "Neuroframeset.html";

my $base_dir = "./wormatlas/";
#my $base_dir = "./wormatlastest/";
my $anatomy_file = "./anatomy_terms.txt";

my %anatomy_terms = ();
my %anatomy_ids   = ();
load_anatomy_terms_and_ids($anatomy_file,
                           \%anatomy_terms,
                           \%anatomy_ids);

my %result;
index_pages($base_dir, \%result, \%anatomy_terms);
output_results(\%result, \%anatomy_ids);

sub index_pages {
    my $dir               = shift;
    my $result_ref        = shift;
    my $anatomy_terms_ref = shift;

    my @files;
    if (-d $dir) {
        # if dir names have spaces in them!
        if ($dir =~ / /) {
            @files = <"$dir"/*>;
        } else { 
            @files = <$dir/*>;
        }
    } else {
        @files = ($dir);
    }

    for my $file (@files) {
	# exclude specific pages
	next if ($file =~ m/$excludedfiles$/);    
        if (-d $file) { # recurse if $file is directory
            index_pages($file, $result_ref, $anatomy_terms_ref);
        }
        else {
			if ( is_frameset_file($file) ) {
                print  "file = $file\n";
				
                # the file we are looking at, $file, may not be the file that has the data.
                # it has '<frame src=' in it and refers to another mainframe html file.
                # if this is the case, then get that file, which has the data.

                my $f_data = $file; # this will be set to mainframe.htm file below
                
                open (IN, "<$file") or die ("Died: could not open $file for reading\n");
				while (my $html_line = <IN>) {
					chomp ($html_line);
					
					if ($html_line =~ /\<frame src=\"leftframe\.htm\"/) {
						next; # skip if leftframe.htm
					} 
					elsif ($html_line =~ /\<frame src=\"(.*\.html?)\"/) { # then open the mainframe file
						my $subfilename = $1;
						$f_data =~ s/(.+)\/(.+?)$/$1\/$subfilename/;
						print "f_data = $f_data\n";

						open (IN_DATA, "<$f_data") or die ("Died: could not open $f_data for reading\n");
						while (my $line = <IN_DATA>) {
							#$line = escapeChars($line);
							chomp($line);
							if ($line =~ /^\s*\<div align=\"center\"\>\<a href=\"(.+?)\" target=\"\_blank\"\>/) {
							#extract_terms_from_file( $1, $f_data, $file, $result_ref, $anatomy_terms_ref );
							next;
							}

							extract_terms_from_line( $line, $file, $anatomy_terms_ref, $result_ref );
						}
						close IN_DATA;
					} 
				}
				print  "---------------------------------------------------------------------------------\n";
			}
		}
	}
	return;

}

sub output_results {
	my $result_ref = shift;
    my $anatomy_ids_ref = shift;

    # my $outfile = "output_temp.html";
       my $outfile = "link2wormatlas.ace";
	open (OUT, ">$outfile") or die $!;
	# supplemental hard coded links <
	print OUT "Anatomy_term : WBbt:0005811\n";
	print OUT "Database WormAtlas html \"hermaphrodite\\/neuronalsupport\\/Neurosupportframeset.html\"\n\n";
	# supplemental links >

for my $term (sort keys %{$result_ref}) {
		
        my @ids = keys %{$anatomy_ids_ref->{$term}};

	for my $id(@ids)  {
		# print OUT "$term $id ";
		# print OUT "$term Anatomy_term"," ",":"," ","$id","\n";
		# print OUT "Database WormAtlas htmlpage ";

		for my $f (keys %{$result_ref->{$term}}) {
		
            # sort the output in descending order
			my $big_f = $f;
			my $big_n = $result_ref->{$term}{$f};
		
			for my $f2 (keys %{$result_ref->{$term}}) {
				if ( (defined($result_ref->{$term}{$f2}) && (defined($big_n)) && ($result_ref->{$term}{$f2} > $big_n)) ) {
					$big_f = $f2;
					$big_n = $result_ref->{$term}{$f2};
				}
			}
				
			 my @e = split(/\//, $big_f);
			 my $fn = pop @e;

### <<'To print ace';
			print OUT "Anatomy_term"," ",":"," ","$id","\n";
			print OUT "Database WormAtlas html ";
			my $html_page = $big_f;
			$html_page =~ s/^\.\/wormatlas\/\///;
			$html_page =~ s/\//\\\//g;			
			print OUT "\"$html_page\"\n\n";
			delete $result_ref->{$term}{$big_f};
### To print ace

<<To_print_html
			my $html_page = $big_f;
			$html_page =~ s/^\.\/wormatlastest\//http:\/\/www\.wormatlas\.org/;
			# $html_page =~ s/^\.\/toindex\/wormatlas\//http:\/\/www\.wormatlas\.org\//;
			# $html_page =~ s/\/\//\//g;
			# $html_page =~ s/^\.\/toindex\//http:\/\/dev\.textpresso\.org\//;
	
			print OUT "\<a href=\"$html_page\"\>$fn\<\/a\>\(" . $big_n ."\)\t";
	
			# delete $result_ref->{$term}{$big_f};
		}
		print OUT "<br/>\n";
		print OUT "<br/>\n";
To_print_html

		}
		}
	}
	print OUT "\n\n";
	print OUT "Database : \"WormAtlas\"","\n";
	print OUT "Name WormAtlas","\n";
	print OUT "Description \"A C. elegans database of behavioral and structural anatomy\"","\n";
	print OUT "URL_constructor \"http:\\/\\/wormatlas.org\\/%s\"";
	print OUT "\n\n";

	print "Output printed to $outfile\n";
	return;

}

sub escapeChars {
	my $name = shift;
	$name =~ s/\./\\\./g;
	$name =~ s/\(/\\\(/g;
	$name =~ s/\)/\\\)/g;
	return $name;
}

sub getIdNumber {
    my $s = shift;
    $s =~ /\:(\d+)/;
    return $1;
}

sub extract_terms_from_file {
    my $subfilename       = shift;
    my $f_data            = shift;
    my $f                 = shift;
    my $result_ref        = shift;
    my $anatomy_terms_ref = shift;

    print "in extract_terms_from_file\n";
    my $correctfile = getCorrectFilename( $subfilename, $f_data );
    print "subfilename = $subfilename\n";
    print "f_data      = $f_data\n";
    print "correctfile = $correctfile\n";

    open (IN, "<$correctfile") or die $!;
    while (my $line = <IN>) {
        chomp($line);
        extract_terms_from_line( $line, $f, $anatomy_terms_ref, $result_ref );
    }
    close(IN);
}

sub extract_terms_from_line {
    my $line = shift;
    my $f = shift;
    my $anatomy_terms_ref = shift;
    my $result_ref = shift;

    # remove html tags
    $line =~ s/\<.+?\>//g;
    return if ($line =~ /^\s*$/);

    my $flag = 1;

    # check if the line has any anatomy terms
    for my $term (keys %{$anatomy_terms_ref}) {
        #while ($line =~ /(^|\s|\(|\[|\{|\,|\;|\'|\`|\&|\.)\Q$term\E($|\s|\)|\]|\}|\,|\;|\'|\`|\&|\.)/g) {
        while ($line =~ /\b\Q$term\Es?\b/g) {
            
            if ($flag) {
                #print "line = $line\n";
                $flag = 0;
            }

            #print "term = $term\n";
            if (defined($result_ref->{$term}{$f})) {
                $result_ref->{$term}{$f}++;
            } else {
                $result_ref->{$term}{$f} = 1;
            }
        }
    }
    #print "\n" if (!$flag);
}

sub getCorrectFilename {
    my $subfilename = shift; # eg: ../../images/abc.jpg
    my $mainfile    = shift; # eg: ./toindex/wormatlas/hermaphrodite/hypodermis/

    $subfilename =~ s/\/\//\//g;
    $mainfile =~ s/\/\//\//g;

    my $count = 1; # by default, you exclude the filename
    while ($subfilename =~ /\.\.\//g) {
        $count++;
    }

    my @entries = split(/\//, $mainfile);

    for (my $i=0; $i<$count; $i++) {
        pop @entries;
    }

    my $path = join('/', @entries);
    my $correctfilename = $path . '/' . $subfilename;

    return $correctfilename;
}

sub load_anatomy_terms_and_ids {
    my $anatomy_file      = shift;
    my $anatomy_terms_ref = shift;
    my $anatomy_ids_ref   = shift;

    open (IN, "<$anatomy_file") or die ($!);
    my $c = 0;
    while (my $line = <IN>) {
        chomp($line);
    	if ($line =~ /^(\S+)\t\"(.+?)\"/) {
            my $id = $1;
            my $name = $2;

            # exclude terms less than 3 chars
            my @letters = split(//, $name);
            next if (scalar @letters <= 2);

	    # exclude specific terms
	    next if ($name =~ m/^$excludedterms$/i);

    		$anatomy_terms_ref->{$name}    = 1;
            $anatomy_ids_ref->{$name}{$id} = 1;
            $c++;
    	}
    }
    close (IN);
    
    print "Loaded $c anatomy terms\n";
    my @names = keys %anatomy_terms;
    print "# of unique anatomy terms = " . scalar (@names) . "\n";
}

sub is_frameset_file {
    my $file = shift;

    if ($file =~ /frameset\.html?/i) {
        return 1;
    }
    return 0;
}
