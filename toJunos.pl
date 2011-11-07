#!/usr/bin/perl

use strict;
use Data::Dumper;
use NetAddr::IP;
use XML::LibXML;
use readRules;
use readConfig;

sub xlate($$) {
  my ($cfg,$rules) = @_ ;
  my ($xml,$ctx,$root);

  sub xNodeCreateOrSet($$) {
    my ($path,$value) = @_;
    my $node = $ctx || $root;
    my @pList = split(/\//,$path);
    for (my $tn = 0; $tn < $#pList + (defined $value ? 1:0); $tn++) {
      my $tag = $pList[$tn];
      ($node = $root, next) unless $tag;
      my @cNodes = $node->findnodes($tag);
      if ($cNodes[0]) { $node = $cNodes[0]; }
        else { $node = $node->addChild($xml->createElement($tag)); }
    }
    if (defined $value) {
      $node->removeChildNodes();
      $node->addChild($xml->createTextNode($value));
    } else {
      $node = $node->addChild($xml->createElement($pList[$#pList]));
    }
    return $node;
  }

  sub xNodeCreate($) { return xNodeCreateOrSet(shift,undef); }
  sub xNodeSet($$) {   return xNodeCreateOrSet($_[0],eval($_[1]) || ""); }

  sub xActions($) {
    my $stm = shift;
    for my $act (@{$stm->{'action(s)'}}) {
      if ($act->{set}) {
        xNodeSet($act->{set}->{path},$act->{set}->{expr});
      } elsif ($act->{create}) {
        $ctx = xNodeCreate($act->{create}->{path});
      }
    }
  }

  sub xParse($) {
    my $txt = shift;
    for my $rule (@{$rules->{'statement(s)'}}) {
      if ($rule->{match}) {
        my $stm = $rule->{match};
        my $pat = $stm->{pattern};
        @Q::RESULT = ($txt =~ /^$pat/);
        next unless ($#Q::RESULT >= 0);
        xActions($stm);
      }
    }
  }

  sub xlateConfig($$) {
    my ($cfg,$ctx) = @_ ;
    for (my $i = 0; $i <= $#{$cfg}; $i++) {
      my $line = ${$cfg}[$i];
      if (ref($line) eq 'HASH') {
        xParse($line->{hdg});
        xlateConfig($line->{body});
      } elsif (!ref($line)) {
        xParse($line);
      }
    }
  }

  $xml = XML::LibXML::Document->createDocument();
  $root = $xml->createElement('configuration');
  $xml->setDocumentElement($root);
  xlateConfig($cfg,undef);
  return $xml;
}

our $map = { 'Loopback0' => 'lo0',
	     'FastEthernet0/0' => 'ge-0/0/1',
	     'FastEthernet0/1' => 'ge-0/0/2',
	     'Serial1/0' => 'ge-0/0/4',
	     'Serial1/1' => 'ge-0/0/5',
	     'Serial1/2' => 'ge-0/0/5',
	     'Serial1/3' => 'ge-0/0/6' };

our $rules;

$rules = readRules('toJunosXlate.cfg');

while(my $fn = shift @ARGV) {
  my $cfg = readConfig($fn);
  fixIPAddress($cfg);
  fixIfNames($cfg,$map);
  my $xml = xlate($cfg,$rules);
  print $xml->toString();
}
