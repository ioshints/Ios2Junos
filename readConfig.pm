use strict;

sub readConfig($) {
  my $fname = shift;
  my (@config,@stack,$slv,$clv,$hdg,$obj);

  open CONFIG,'<',$fname || die "Cannot open $fname for reading: $!\n";
  $slv = 0;
  @stack[0] = \@config;
  while (<CONFIG>) {
    s/(\n|\r)//g; s/^(\s*)//; $clv = length($1);
    next if /^!/;
    if ($slv >= $clv) {
      push @{$stack[$clv]},$_; $slv = $clv;
    } else {
      die "Unexpected jump in level from $slv to $clv\n$_\n" if ($clv > $slv + 1);
      $hdg = pop @{$stack[$slv]};
      $obj = { hdg => $hdg, body => [$_] };
      push @{$stack[$slv]},$obj;
      $stack[$clv] = $obj->{body};
      $slv = $clv;
    }
  }
  close CONFIG;
  return \@config;
}

sub fixIPAddress($) {
  my $cfg = shift;

  for (my $i = 0; $i <= $#{$cfg}; $i++) {
    my $line = ${$cfg}[$i];
    if (ref($line) eq 'HASH') {
      next unless $line->{hdg} =~ /^interface/;
      fixIPAddress($line->{body});
    } elsif (!ref($line)) {
      next unless $line =~ /^(ip address )([0-9.]+) ([0-9.]+)(.*)/;
      my ($pfx,$mask) = ($2,$3);
      my $addr = NetAddr::IP->new($pfx,$mask);
#      print "$pfx $mask ==> $addr\n";
      ${$cfg}[$i] = "ip address $addr$4";
    }
  }
}

sub fixIfNames($$) {
  my ($cfg,$map) = @_ ;

  sub replaceIfNames($) {
    my $txt = shift;
    for my $iosName (keys(%{$map})) {
      $txt =~ s/\Q$iosName\E/$$map{$iosName}/i;
    }
    return $txt;
  }

  for (my $i = 0; $i <= $#{$cfg}; $i++) {
    my $line = ${$cfg}[$i];
    if (ref($line) eq 'HASH') {
      $line->{hdg} = replaceIfNames($line->{hdg});
      fixIfNames($line->{body},$map);
    } else {
      next if (ref($line));
      ${$cfg}[$i] = replaceIfNames(${$cfg}[$i]);
    }
  }
}

1;
