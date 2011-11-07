use strict;

use Parse::RecDescent;
use File::Slurp;
use Data::Dumper;

my $grammar = q{
<autotree>

rules: statement(s)
statement: match | first | section

section: 'section' <commit> pattern ( match | first ) ';'
first:   'first' <commit> pattern action(s) ';'
match:   'match' <commit> pattern action(s) ';'

action:  set | create
set:     'set' <commit> path '=' expr
create:  'create' <commit> context(?) path
context: 'context' <commit>

path:    /[A-Za-z0-9.\/-]+/  { $item[1] }
string:  /(\".*?\")|\w+/     { ::rr_RemoveQuotes($item[1]) }
pattern: /\".*?\"|\w+/       { ::rr_MakePattern($item[1]) }
expr:    /[A-Za-z0-9.\$-]+/  { ::rr_MakeExpression($item[1]) }
};

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
  my $rules  = read_file($fname) || die "Cannot read fules file $fname: $!\n";
  my $tree = $parser->rules(\$rules) || die "Cannot parse rule file: $!\n";
#  print Dumper($tree);
  $rules =~ s/\s+$//g;
  die "Parsing error, first offending rule:\n  ".substr($rules,0,70)."\n" if $rules;
  return $tree;
}

1;
