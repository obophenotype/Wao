#!/usr/bin/perl -w

# obo2ace.pl reads an obo file and sends .ace format to STDOUT for Anatomy_term objects.
# author: Raymond Lee

use strict;
use Text::Balanced qw(extract_quotelike extract_bracketed);
use Data::Dumper;
use diagnostics;

my $stanza;
my $id = "";
my $definition = "";
my @parts;
my $def_ref = "";
my $name = "";
my $synonym = "";
my @synonyms = ();
my $syn_ref = "";
my @syn_refs = ();
my $alt_id = "";
my @alt_ids = ();
my @relationships = ();
my @related_ids = ();
my $relationship = "";
my $related_id = "";
my %parent_ids = ();
my @good_ids = ();
my $comment = "";
my @comments = ();
my @gen_dbxrefs = ();



while(<>) {
    chomp;
    s/\//\\\//g; #deal with //, added 20050921
    next unless $_;
    if ((/^\[Term\]\s*(.*)/)|(/^\[Typedef\]\s*(.*)/)) {
	if ($id) {
	    $parent_ids{$id} = [@good_ids];
	    @good_ids = ();
	    printace ();
	}
    }


    elsif (/^([\w\-]+)\:\s*(.*)/) {
        my ($tag, $val) = ($1, $2);
        my $val2 = $val;
        $val2 =~ s/\\,/,/g;
	$val2 =~ s/ \!(.*)$//;    # remove dangling term name after term id
        if ($tag eq 'id') {
	    if ($val =~ /WBbt:(.*)/) {
		$id = $val;
		$id =~ s/WBbt://;
	    }
	}
	elsif ($tag eq 'name') {
	    $name = $val2;
	}
        elsif ($tag eq 'is_a') {
	    $relationship = $tag;
	    push (@relationships, $relationship);
	    $related_id = $val2;
	    $related_id =~ s/WBbt://;
	    push (@related_ids, $related_id);
	    push (@good_ids, $related_id);
	}
        elsif ($tag eq 'union_of') {
	    $relationship = $tag;
	    push (@relationships, $relationship);
	    $related_id = $val2;
	    $related_id =~ s/WBbt://;
	    push (@related_ids, $related_id);
	    push (@good_ids, $related_id);
	}	
	elsif ($tag eq 'relationship') {
	    my $rel_id;
	    ($relationship, $rel_id) = split(' ', $val2);
	    push (@relationships, $relationship);
	    $related_id = $rel_id;
	    $related_id =~ s/WBbt://;
	    push (@related_ids, $related_id);
	    if ($relationship eq "part_of") {push (@good_ids, $related_id);}
        }
	elsif ($tag eq 'def') {
	    my ($extr, $rem) = extract_quotelike($val);
	    $definition = $extr;
	    $definition =~ s/^\"//;
	    $definition =~ s/\"$//;
	    my ($extr2, $rem2) = extract_bracketed($rem, '[]');
	    $def_ref = $extr2;
	    $def_ref =~ s/^\[//;
	    $def_ref =~ s/\]$//;
	    @parts = ();
	    while ($def_ref =~ /(.*[^\\],\s*)(.*)/) {
		$def_ref = $1;
		my $part = $2;
		unshift(@parts, $part);
		$def_ref =~ s/,\s*$//;
	    }
	    unshift(@parts, $def_ref);

	}
	elsif ($tag =~ /(\w*)synonym/) {
	    my ($extr3, $rem3) = extract_quotelike($val);
	    $synonym = $extr3;
	    $synonym =~ s/^\"//;
	    $synonym =~ s/\"$//;
	    push (@synonyms, $synonym);
	    (my $syn_type, $rem3) = split(' ', $rem3);   # synonym type moved here in OBO 1.2 format
	    my ($extr4, $rem4) = extract_bracketed($rem3, '[]');
	    $syn_ref = $extr4;
	    $syn_ref =~ s/^\[//;
	    $syn_ref =~ s/\]$//;
	    push (@syn_refs, $syn_ref);
##--- added to remove "lineage name:" from synonyms----------------##
	    if ($synonym =~ /^lineage name\\: (.+)/) {
		$synonym = $1;
	    push (@synonyms, $synonym);
	    }
##-----------------------------------------------------------------##
	}
	elsif ($tag eq 'alt_id') {
	    $alt_id = $val;
	    $alt_id =~ s/WBbt://;
	    push (@alt_ids, $alt_id);
	}
	elsif ($tag eq 'xref_analog') {
	    my $gen_dbxref = $val;
	    push (@gen_dbxrefs, $gen_dbxref);
	}
	elsif ($tag eq 'comment') {
	    my $comment = $val;
	    push (@comments, $comment);
	}        
	elsif ($tag eq 'is_obsolete') {
	    $id = ""; #don't want any obsoleted terms in ace
	    $definition = "";
	    $def_ref = "";
	    $name = "";
	    $synonym = "";
	    $syn_ref = "";
	    $alt_id = "";
	    $relationship = "";
	    $related_id = "";
	    $comment = "";
	}
        else {
	    print "\/\/$tag: $val \n";
	    next;
        }
    }
}

$parent_ids{$id} = [@good_ids];
@good_ids = ();

printace ();

foreach $id (sort keys %parent_ids) {
    if ($id) {
	print "Anatomy_term :\t WBbt:$id\n";
	print "Ancestor\t WBbt:$id\n";
	my @ancestors = @{$parent_ids{$id}};
	while (@ancestors) {
	    my $a = shift @ancestors;
	    print "Ancestor\t WBbt:$a\n";
	    if (@{$parent_ids{$a}}) {
	     	push @ancestors,@{$parent_ids{$a}};
	    }
	}
	print "\n";
    }
}







sub printace {
	if ($id) {
	    print "Anatomy_term :\tWBbt:$id\n";
	    $id = "";
#	}
	    if ($definition) {
		while (@parts) {
		    print "Definition\t\"$definition\"\t";
		    $def_ref = shift(@parts);
		    if ($def_ref =~ /[ISBN|WB]:0-87969-307-X/) { #KLUGE
			print "Paper_evidence WBPaper00004052";
		    }
		    elsif ($def_ref =~ /ISBN:(\d*) \"\"/i) {
#		    print "Paper_evidence \[isbn$1\]";
		    }
		    elsif ($def_ref =~ /ISBN:(.*)/i) {
#		    print "Paper_evidence \[isbn$1\]";
		    }
		    elsif ($def_ref =~ /wb:rynl/i) {
			print "Person_evidence WBPerson363";
		    }
		    elsif ($def_ref =~ /wb:pws/i) {
			print "Person_evidence WBPerson625";
		    }
		    elsif ($def_ref =~ /wa:dh/i) {
			print "Person_evidence WBPerson233";
		    }
		    elsif ($def_ref =~ /wb:s[bd]m/i) { #KLUGE
			print "Person_evidence WBPerson1250";
		    }
		    elsif ($def_ref =~ /wb:wjc/i) {
			print "Person_evidence WBPerson101";
		    }
		    elsif ($def_ref =~ /wb:([?)cgc938(\\?)(]?)/i) {
			print "Paper_evidence WBPaper00000938";
		    } elsif ($def_ref =~ /wb:cgc938 \"\"/i) {
			print "Paper_evidence WBPaper00000938";
		    }
		    elsif ($def_ref =~ /wb:\\\[cgc3760\\\]/i) {
			print "Paper_evidence WBPaper00003760";
			
		    } elsif ($def_ref =~ /wb:Paper(.*) \"\"/i) {
			print "Paper_evidence WBPaper$1";
		    }
		    elsif ($def_ref =~ /wb:(.*) \"\"/i) {
			print "Paper_evidence [$1]";
		    } 
		    elsif ($def_ref =~ /wbpaper:(\d{8})(| \"\")/i) {   # WBPaper:00000653
			print "Paper_evidence WBPaper$1";
		    }
		    elsif ($def_ref =~ /caro:(.*)(|\"\")/i) { #KLUGE
		    }
		    elsif ($def_ref =~ /wb(:?)paper(:?)(\d{8})/i) {
			print "Paper_evidence WBPaper$3";
		    }
		    else {
			print "UNKNOWN DEF_REF: \"$def_ref\"\n";
			
			exit;
		    }
		    print "\n";
		}
		$definition = "";
		$def_ref = "";
	    }
	    if ($name) {
		print "Term\t\"$name\"\n";
		$name = "";
	    }
	    while (@synonyms) {
		$synonym = pop (@synonyms);
		$syn_ref = pop (@syn_refs);
		print "Synonym\t\"$synonym\"\t";
		if ($syn_ref) {
		    if ($syn_ref =~ /[ISBN]:0-87969-307-X/) {
			print "Paper_evidence WBPaper00004052";
		    }
		    elsif ($syn_ref =~ /ISBN:(.*) \"\"/i) {
#		    print "Paper_evidence \[isbn$1\]";
		    }
		    elsif ($syn_ref =~ /ISBN:(.*)/i) {
#		    print "Paper_evidence \[isbn$1\]";
		    }
		    elsif ($syn_ref =~ /wb:rynl/i) {
			print "Person_evidence WBPerson363";
		    }
		    elsif ($syn_ref =~ /wb:pws/i) {
			print "Person_evidence WBPerson625";
		    }
		    elsif ($syn_ref =~ /wa:dh/i) {
			print "Person_evidence WBPerson233";
		    }
		    elsif ($syn_ref =~ /wb:sdm/i) {
			print "Person_evidence WBPerson1250";
		    }
		    elsif ($syn_ref =~ /wb:wjc/i) {
			print "Person_evidence WBPerson101";
		    }
		    elsif ($syn_ref =~ /wb:\\\[cgc938\\\]/i) {
			print "Paper_evidence WBPaper00000938";
		    } elsif ($syn_ref =~ /wb:\\\[cgc3760\\\]/i) {
			print "Paper_evidence WBPaper00003760";
		    } elsif ($syn_ref =~ /wb(:?)paper(:?)(\d{8})/i) {
			print "Paper_evidence WBPaper$3";
		    } else {
			print "UNKNOWN SYN_REF: $syn_ref\n";
			exit;
		    }
		}
		print "\n";
		$synonym = "";
		$syn_ref = "";
	    }
	    
	    
	    
	    while (@relationships) {
		$relationship=pop(@relationships);
		$related_id=pop(@related_ids);
		if ($relationship eq 'is_a') {
		    print "IS_A_p WBbt:$related_id\n";
		}
		elsif ($relationship eq 'part_of') {
		    print "PART_OF_p WBbt:$related_id\n";
		}
		elsif ($relationship eq 'develops_from') {
		    print "DEVELOPS_FROM_p WBbt:$related_id\n";
		}
		elsif ($relationship eq 'DESCENDENTOF') {
		    print "DESCENDENT_OF_p WBbt:$related_id\n";
		}
		elsif ($relationship eq 'DESCINHERM') {
		    print "DESC_IN_HERM_p WBbt:$related_id\n";
		}
		elsif ($relationship eq 'DESCINMALE') {
		    print "DESC_IN_MALE_p WBbt:$related_id\n";
		} elsif ($relationship eq 'union_of') {
 		    print "XUNION_OF_p WBbt:$related_id\n";
		} else {
		    print "UNKNOWN RELATION: $def_ref\n";
		    exit;
		}
		$relationship = "";
		$related_id = "";
	    }
	    
	    while (@alt_ids) {
		$alt_id = pop (@alt_ids);
		print "Remark\t\"Secondary ID WBbt:$alt_id\"\n";
		$alt_id = "";
	    }
	    
	    while (@comments) {
		$comment = pop (@comments);
		if ($comment =~ /<(http.*)>/) {    ## special treatment for Remark "*<http*>"
		    next;   ## stop using URL tag, instead add links with link2wormweb.ace, 20100712
		    # print "URL\t\"$1\"\n";
		} else {
		    print "Remark\t\"$comment\"\n";}
		$comment = "";
	    }
	    print "\n";
	}
}
