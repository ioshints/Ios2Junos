#!/usr/bin/perl

use strict;
use Data::Dumper;
use NetAddr::IP;
use XML::LibXML;
use File::Basename;
use Getopt::Long;

BEGIN { $::scriptDir = dirname($0); push @INC,$::scriptDir; }

use readRules;
use readConfig;
use xlateConfig;

our ($ifmap,$rules);

GetOptions('verbose'  => \$::opt_verbose,
           'debug'    => \$::opt_debug,
           'xDebug'   => \$::opt_xDebug,
           'naming=s' => \$::opt_ifname,
           'config=s' => \$::opt_config);

$ifmap = readInterfaceMap(findConfigFile($::opt_ifname || 'toJunosIfname.cfg'));
$rules = readRules(findConfigFile($::opt_config || 'toJunosXlate.cfg'));

while(my $fn = shift @ARGV) {
  my $cfg = readConfig($fn);
  fixIPAddress($cfg);
  fixIfNames($cfg,$ifmap);
  my $xml = xlate($cfg,$rules);
  my $txt = $xml->toString(1); $txt =~ s!&#xBC;!/!g; # Fix stupid XPath bug
  print $txt;
}
