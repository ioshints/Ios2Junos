use strict;
use Data::Dumper;
use XML::LibXML;

sub xlate($$) {
  my ($cfg,$rules) = @_ ;
  my ($xml,$ctx,$root);

  sub xQuote($) { my $txt = shift; $txt =~ s!/!\N{U+BC}!g; return $txt; }

  sub xNodeCreateOrSet($$) {

    my $debugNode = 0;
  
    my ($path,$value) = @_;
    my $node = $ctx || $root;
    $path = eval('"'.$path.'"');	# Evaluate path to extrapolate variables
    $value =~ s!/!\N{U+BC}!g;		# Stupid XPath parsing bug - replace slash in values
    $path =~ s/(\'.*?\')/xQuote($1)/ge; # Have to do the same thing with PATH but only quoted parts
    print "path = $path\n" if $debugNode;
    my @pList = split(/\//,$path);
    print "CreateOrSet: $path $value\n" if $debugNode;
    for (my $tn = 0; $tn < $#pList + (defined $value ? 1:0); $tn++) {
      my $tag = $pList[$tn];
      print " inspect $tag\n" if $debugNode;
      ($node = $root, next) unless $tag;
      my @cNodes = $node->findnodes($tag);
      if ($cNodes[0]) { $node = $cNodes[0]; }
        else { $node = $node->addChild($xml->createElement($tag)); }
    }
    if (defined $value) {
      $node->removeChildNodes();
      $node->addChild($xml->createTextNode($value));
      print "set $path to $value\n" if $debugNode;
    } else {
      $node = $node->addChild($xml->createElement($pList[$#pList]));
    }
    return $node;
  }

  sub xNodeCreate($) { return xNodeCreateOrSet(shift,undef); }
  sub xNodeSet($$) {   return xNodeCreateOrSet($_[0],eval($_[1]) || ""); }

  sub xNodeDelete($) {
    my ($path) = shift;

    $path = eval('"'.$path.'"');	# Evaluate path to extrapolate variables
    $path =~ s/(\'.*?\')/xQuote($1)/ge; # Workaround for the stupid XPath bug

    my $start = $ctx;
    if ($path =~ m!^/(.*)$!) { $start = $root; $path = $1; }

    my @cNodes = $start->findnodes($path);
    for my $node (@cNodes) {
      $node->parentNode()->removeChild($node);
    }
  }

  sub xActions($) {
    my $stm = shift;
    my $newctx = $ctx;

    for my $act (@{$stm->{'action(s)'}}) {
      if ($act->{set}) {
        xNodeSet($act->{set}->{path},$act->{set}->{expr});
      } elsif ($act->{add}) {
        xNodeSet($act->{add}->{path},'');
      } elsif ($act->{create}) {
        $ctx = xNodeCreate($act->{create}->{path}); 
        $newctx = $ctx if $act->{create}->{context};
      } elsif ($act->{delete}) {
	xNodeDelete($act->{delete}->{path});
      }
    }
    $ctx = $newctx;
  }

  sub xParse($$) {
    my ($txt,$ctx) = @_;

    sub xParseStatement($$$) {
      my ($rule,$txt,$ctx) = @_ ;
      my $stm;

      $ctx ||= "";
      if (($stm = $rule->{match}) || (($stm = $rule->{first}) && !$rule->{"cnt_$ctx"})) {
        my $pat = $stm->{pattern};

        @Q::RESULT = ($txt =~ /^$pat/);
        return unless ($#Q::RESULT >= 0);
        $rule->{"cnt_$ctx"}++;
        xActions($stm);

      } elsif (($stm = $rule->{section}) && $ctx) {
        my $pat = $stm->{pattern};

        @Q::SECTION = ($ctx =~ /$pat/);
        return unless ($#Q::SECTION >= 0);
        xParseStatement($stm->{match_or_first},$txt,$ctx);
      }
    }

    for my $rule (@{$rules->{'statement(s)'}}) {
      xParseStatement($rule,$txt,$ctx);
    }
  }

  sub xlateConfig($$) {
    my ($cfg,$ctx) = @_ ;
    for (my $i = 0; $i <= $#{$cfg}; $i++) {
      my $line = ${$cfg}[$i];
      if (ref($line) eq 'HASH') {
        xParse($line->{hdg},$ctx);
        xlateConfig($line->{body},($ctx ? "$ctx " : "") . $line->{hdg});
      } elsif (!ref($line)) {
        xParse($line,$ctx);
      }
    }
  }

  $xml = XML::LibXML::Document->createDocument();
  $root = $xml->createElement('configuration');
  $xml->setDocumentElement($root);
  xlateConfig($cfg,undef);
  return $xml;
}

1;
