#!/usr/bin/perl

# $Id: cecao_parser.pl,v 1.5 2004/02/28 00:42:57 raymond Exp $

# cecao_parser.pl sends .ace format to STDOUT for GO_term objects.
# It requires a directory containing following files:
#    GO.defs     GO definitions
#    *.ontology  One or more ontology files

my $dir = shift || '.';
"usage: cecao_parser.pl <directory>\n" if $dir =~ /^-/;
my $godefs = "$dir/WORManat1.def";

die "No WORManat1.def found in $dir.\n" unless -e $godefs;

opendir (D,$dir) or die "Can't open directory $dir: $!\n";
my @ontologies = map {"$dir/$_"} grep {/WORManat1$/} readdir(D);
closedir D;

die "No WORManat1 file found in $dir.\n" unless @ontologies;

my (%goids,%terms);

read_definitions("$godefs",\%goids,\%terms);

for my $gofile (@ontologies) {

  open (ONT, "$gofile") or die "Couldn't open $gofile";
  my $type;

  #parse all the ontology files as t.tmp
  my @open = ();
  while(<ONT>){
    next if /^!/;	#skip the comments

    s/^(\s*?)(\S)(.+?) ; WBdag:(\d+)(.*)//;
    #1 depth spaces
    #2 relat
    #3 handle
    #4 goid
    #5 other goid
    my $spacer = $1;
    my $goid   = $4;
    my $depth = length($1);
    $open[$depth] = "WBbt:$4";

#    $type ||= $3 unless $2 eq "\$";

    my $record = qq(Anatomy_term : "WBbt:$4"\n);
    $record .= qq(Definition "$goids{$4}"\n) if $goids{$4};
    (my $term = $3) =~ s/\"/\\"/; #"
    $record .= qq(Term "$term"\n);
#    $record .= qq($type\n) if $type;

    if($2 eq '<'){$record .= qq(PART_OF_p "$open[$depth-1]"\n) ;
#RL: Ancestral relationship coding, consider one level at a time
		  $record .= qq(Ancestor "$open[$depth-2]"\n) ;}
    if($2 eq '%'){$record .= qq(IS_A_p "$open[$depth-1]"\n);
		  $record .= qq(Ancestor "$open[$depth-2]"\n) ;}
    if($2 eq '~'){$record .= qq(DEVELOPS_FROM_p "$open[$depth-1]"\n);}
    if($2 eq '@'){$record .= qq(DESCENDENT_OF_p "$open[$depth-1]"\n);}
    if($2 eq '^'){$record .= qq(DESC_IN_HERM_p "$open[$depth-1]"\n);}
    if($2 eq '#'){$record .= qq(DESC_IN_MALE_p "$open[$depth-1]"\n);}

    my $other_terms = $5;

    # synonym
    while ($other_terms =~ /; synonym:(.*?)( [%<>~@\#].*)?$/g) {
         my $synonym = $1;
	 @list=split(/ ; synonym:/, $synonym);
	 foreach my $list_element (@list) {
         next unless length($_)>0;
	     if ($list_element =~ m/^lineage name\\: (.*?)$/) {
		 my $lineage_values = $1;
		 my @each_lineage_value = split(/\\, /, $lineage_values);
		 foreach (@each_lineage_value) {
		     $record .= qq(Remark "lineage name\: $_"\n);
		 }
            } else {
                   $record .= qq(Synonym "$list_element"\n);
             }
	 }
    }


# RL: the following loop seems to be generating redundant acedb commands, DAG-Edit flat file codes the same information twice?

#    while($other_terms =~ /([%<>~@\#]).+?(WBdag:(\d+))/g){
#      if($1 eq '<'){$record .= qq(PART_OF_p "WBbt:$3"\n) ;}
#      if($1 eq '%'){$record .= qq(IS_A_p "WBbt:$3"\n);}
#      if($1 eq '~'){$record .= qq(DEVELOPS_FROM_p "WBbt:$3"\n);}
#      if($1 eq '@'){$record .= qq(DESCENDENT_OF_p "WBbt:$3"\n);}
#      if($1 eq '^'){$record .= qq(DESC_IN_HERM_p "WBbt:$3"\n);}
#      if($1 eq '#'){$record .= qq(DESC_IN_MALE_p "WBbt:$3"\n);}
#    }


#    $record .= "Ancestor $_\n" foreach @open[0..@open-2];

#    $record .= "\n";
#    print $record;

    # synonym terms
    while ($other_terms =~ /, (WBdag:(\d+))/g) {
         my $synonym = $2;
#        $record =~ s/^Anatomy_term : .+$/Anatomy_term : "WBbt:$synonym"/m;
#        print $record;
# RL: instead of copying the information to the subsumed term, remove the subsumed term and making it a synonym of the main term
	 $record .= qq(Synonym "WBbt:$synonym"\n);
     }
    $record .= "\n";
    print $record;
  }

  close(ONT);
}

sub read_definitions {
  my ($deffile,$goids,$terms) = @_;
  local $/ = "\n\n";	#change the input field separator

  open (F,$deffile) or die "Can't open $deffile: $!";
  while(<F>){
    s/^!.*\n//mg;
    my %h = /^([^:]+):\s+(.+)$/mg;
    my $goid = $h{goid};
    my $term = $h{term};
    my $def  = $h{definition};
    $def     =~ s/"/\\"/g;
    $goid =~ s/WBdag://;
    $goids->{$goid} = $def ;
    $terms->{$goid} = $term;
  }
  close F;
}

