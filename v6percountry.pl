#!/usr/bin/env perl
# $Id: v6percountry.pl 43645 2013-07-04 08:19:21Z eaben $
use strict;
use warnings;
use YAML qw(DumpFile Load LoadFile Dump);

## Config
## change these according to where you can access INRDB
## for public INRDB: my $host='sga.ripe.net'
my $port=5555;
#my $host='localhost';
my $host='yoda.ripe.net';
##

my %as2cc;
my $cc;

# build up AS->country mapping
my $cmd0 = "echo \"+dc RIR_STATS +xT $ARGV[0] -m AS* +T +M\" | nc $host $port";
my @out0 = `$cmd0`;
for my $l (@out0) {
   next if ($l =~ /^\s*$/);
   next if ($l =~ /^Finished:/);
   my ($start,$end);
# BLOB: apnic|SG|asn|4628|2|19950912|allocated
   if ($l =~ /BLOB:\s+\w+\|(\w+)\|asn\|(\d+|\d+\.\d+)\|(\d+)\|/) {
      my ($cc,$start,$end) = ($1,$2,$3);

      # fix up
      if ($cc eq 'UK' ) { $cc = 'GB' };

      if ($start =~ /(\d+)\.(\d+)/) { # 32bit asn, dot notation ...
         $start = $1 * (2**16) + $2;
      }
      $end += $start - 1;
      for my $i ( $start .. $end ) {
         $as2cc{ $i } = $cc;
      }
   } else {
      warn "can't parse $l\n";
   }
}

my $cmd6 = "echo \"+dc RIS_RIB_V +ds aggr +minpwr 10 +sT $ARGV[0]T0 +eT $ARGV[0]T18 AS* -M ::/0 +T +R +M +B\" | nc $host $port | egrep '^RES: AS'";
my @out6 = `$cmd6`;
warn $cmd6 . "\n";
warn "v6 entries " . scalar(@out6) . "\n";

for my $l (@out6) {
   if( $l =~ /RES: AS(\d+)/ ) {
      my $asn = $1;
      next if ($asn > 64496 && $asn < 65535); #private use, doc etc.
      next if ($asn == 23456); # AS_TRANS
      if ( $as2cc{$asn} ) {
         $cc->{ $as2cc{$asn} }{v6}{$asn}=1;
         $cc->{ $as2cc{$asn} }{total}{$asn}=1;
      } else {
#         $cc->{XX}{v6}{$asn}=1;
#         $cc->{XX}{total}{$asn}=1;
      }
      $cc->{_ALL}{v6}{$asn}=1;
      $cc->{_ALL}{total}{$asn}=1;
   }
}

my $cmd4 = "echo \"+dc RIS_RIB_V +ds aggr +minpwr 10 +sT $ARGV[0]T00 +eT $ARGV[0]T18 AS* -M 0/0 +T +R +M +B\" | nc $host $port | egrep '^RES: AS'";
my @out4 = `$cmd4`;
warn $cmd4 . "\n";
warn "v4 entries " . scalar(@out4) . "\n";

for my $l (@out4) {
   if( $l =~ /RES: AS(\d+)/ ) {
      my $asn = $1;
      next if ($asn > 64496 && $asn < 65535); #private use, doc etc.
      next if ($asn == 23456); # AS_TRANS
      if ( $as2cc{$asn} ) {
         $cc->{ $as2cc{$asn} }{v4}{$asn}=1;
         $cc->{ $as2cc{$asn} }{total}{$asn}=1;
      } else {
#         $cc->{XX}{v4}{$asn}=1;
#         $cc->{XX}{total}{$asn}=1;
      }
      $cc->{_ALL}{v4}{$asn}=1;
      $cc->{_ALL}{total}{$asn}=1;
   }
}

#open (F,"> ./debug/xx.txt") or die;
#print F Dump( $cc->{XX} );
#close F;

# divisions
my $ccdiv;
my ($div) = LoadFile("divisions.yaml");
foreach my $div_name (keys %$div) {
   foreach my $country (keys %$cc) {
      next if ($country eq '_ALL');
      my $group;
      if ($div->{$div_name}{members}{$country} ) {
         $group = '_' . $div_name;
      } else {
         $group = '_' . $div_name . "_NOT";
      }
      $ccdiv->{$group}{v4} += keys %{ $cc->{$country}{v4} };
      $ccdiv->{$group}{v6} += keys %{ $cc->{$country}{v6} };
      $ccdiv->{$group}{total} += keys %{  $cc->{$country}{total} };
   }
}

system("mkdir -p ./data");
open (F,"> ./data/v6percountry.$ARGV[0].txt") or die;
foreach my $country (sort keys %$cc) {
   my $v4 = keys %{ $cc->{$country}{v4} }; 
   my $v6 = keys %{ $cc->{$country}{v6} }; 
   my $total = keys %{ $cc->{$country}{total} }; 
   print F join(" ",$country,sprintf("%4f",100*$v6/$total),$v4,$v6,$total) . "\n";
}
foreach my $group (sort keys %$ccdiv) {
   my $v4 = $ccdiv->{$group}{v4};
   my $v6 = $ccdiv->{$group}{v6};
   my $total = $ccdiv->{$group}{total};
   next if ($total == 0 );
   print F join(" ",$group,sprintf("%4f",100*$v6/$total),$v4,$v6,$total) . "\n";
}
close F;
warn "done $ARGV[0]"
#system("mkdir -p ./dump");
#DumpFile("./dump/dump.$ARGV[0].yaml",$cc);
