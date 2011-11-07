use strict;

use Parse::RecDescent;
use File::Slurp;
use Data::Dumper;

my $grammar = q{
<autotree>

rules: statement(s)
statement: match | first | section

section: 'section' <commit> pattern match_or_first
match_or_first: match | first

first:   'first' <commit> pattern action(s) ';'
match:   'match' <commit> pattern action(s) ';'

action:  set | add | delete | create
set:     'set' <commit> path '=' expr
add:	 'add' <commit> path
delete:  'delete' <commit> path
create:  'create' <commit> context path
context: ('context' <commit>)(?)  { $return = ::rr_IsPresent($item[1]); }

path:    /[A-Za-z0-9.\/\[\]\$'=-]+/  { ::rr_MakeExpression($item[1]) }
string:  /(\".*?\")|\w+/     { ::rr_RemoveQuotes($item[1]) }
pattern: /\".*?\"|\w+/       { ::rr_MakePattern($item[1]) }
expr:    /[A-Za-z0-9.\$\[\]-]+/  { ::rr_MakeExpression($item[1]) }
};

sub rr_IsPresent($) {
  my $val = shift;
  return "" unless $val;
  return $val unless ref $val;
  return "wtf" unless ref $val eq "ARRAY";
  return $#{$val} >= 0 ? "yes" : "";
}

sub rr_RemoveQuotes($) {
  my $txt = shift;
  $txt =~ s/^"|"$//g;
  return $txt;
}

sub rr_MakePattern($) {
  my $txt = rr_RemoveQuotes(shift); 
  $txt =~ s/\Q{id}\E/([A-Za-z0-9:.-])/gi;
  $txt =~ s/\Q{string}\E/(\\S+)/gi;
  $txt =~ s/\Q{line}\E/(.*)\$/gi;
  return $txt;
}

sub rr_MakeExpression($) {
  my $txt = rr_RemoveQuotes(shift);
  $txt =~ s/\$([A-Za-z][A-Za-z0-9_]*)/\$Q::$1/g;
  $txt =~ s!\$([0-9]+)!'$Q::RESULT['.($1-1).']'!ge;
  return $txt;
}

sub readRules($) {
  my $fname = shift;

#  $::RD_TRACE = 1;
  my $parser = new Parse::RecDescent($grammar) || die "Bad grammar";
  print STDERR "Reading configuration scraping rules from $fname\n" if $::opt_verbose;

  my $rules  = read_file($fname) || die "Cannot read fules file $fname: $!\n";
  my $tree = $parser->rules(\$rules) || die "Cannot parse rule file: $!\n";
  print Dumper($tree) if $::opt_xDebug;
  $rules =~ s/\s+$//g;
  die "Parsing error, first offending rule:\n  ".substr($rules,0,70)."\n" if $rules;
  return $tree;
}

my $mapGrammar = q{
  { my $MG_hashTable = {}; }
  config: line(s) { $return = $MG_hashTable; }
  line:    comment | map

  comment: '#' <commit> restOfLine(?)
  restOfLine: ...!map /\n|(.*?\n)/ 

  map:     ifname '=>' <commit> ifname { $MG_hashTable->{$item[1]} = $item[4]; }
  ifname:  /[A-Za-z0-9.\/-]+/
};

sub readInterfaceMap($) {
  my $fname = shift;

#  $::RD_TRACE = 1;
  my $parser = new Parse::RecDescent($mapGrammar) || die "Bad grammar";
  print STDERR "Reading interface name mapping from $fname\n" if $::opt_verbose;

  my $ifmap  = read_file($fname) || die "Cannot read interface mapping file $fname: $!\n";
  my $tree = $parser->config(\$ifmap) || die "Cannot parse interface mapping file: $!\n";
  print Dumper($tree) if $::opt_xDebug;

  $ifmap =~ s/\s+$//g;
  die "Parsing error, first offending interface map:\n  ".substr($ifmap,0,70)."\n" if $ifmap;
  return $tree;
}

sub findConfigFile($) {
  my $fname = shift;
  return $fname if (-e $fname);
  return "$::scriptDir/$fname" if (-e "$::scriptDir/$fname");
  die "Cannot file $fname in current or script directory\n";
}

1;
