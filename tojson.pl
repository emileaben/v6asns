#!/usr/bin/env perl
use strict;
use warnings;
use YAML::Syck qw(LoadFile);
use JSON qw(to_json);
use Date::Parse qw(str2time);
use Encode qw(decode);

my $divisions = LoadFile("divisions.yaml");

$ENV{TZ} = 'UTC';

### global vars:

my $OUTDIR = "./html";
system("mkdir -p $OUTDIR");

my $label2label = {};
open (C,'<','iso3166_2letter.txt') or die;
while (<C>) {
   chomp();
   if (/^(\w\w)\s+(.*)/) {
      my ($cc,$name) = ($1,$2);
      $cc = uc($cc);
      $name = decode("iso-8859-1",$name);
      # s2l = short to long
      $label2label->{s2l}{$cc} = $name;
      $label2label->{l2s}{$name} = $cc;
   }
}
foreach my $sh_label (keys %$divisions) {
   my $long_label = $divisions->{$sh_label}{label};
   $sh_label = '_' . $sh_label;
   $label2label->{s2l}{$sh_label} = $long_label;
   $label2label->{l2s}{$long_label} = $sh_label;
   my $sh_not = $sh_label . '_NOT';
   my $ln_not = 'All except ' . $long_label;
   $label2label->{s2l}{$sh_not} = $ln_not;
   $label2label->{l2s}{$ln_not} = $sh_not;
}

my $a_short = '_ALL';
my $a_long = 'All Countries';
$label2label->{s2l}{$a_short} = $a_long;
$label2label->{l2s}{$a_long} = $a_short;


### MAIN

my $c = {};

## foreach my $f (glob("./data/v6percountry.*-01.txt")) {
foreach my $f (glob("./data/v6percountry.*.txt")) {
# v6percountry.2004-01.txt 
   my ($date) = ($f =~ /v6percountry\.(.*)\.txt/ );
   my $js_ts = str2time($date)*1000;
   next if (! $js_ts);
   open (F,'<',$f) or die;
   while (<F>) {
      my $l = $_;
      chomp($l);
      my ($label,$pct,$v4as,$v6as,$totalas) = split(/\s+/,$l);
      next if (! defined $pct);
      next if ($label !~ /^\w\w$/ && $label !~ /^_/);
      next if ($label =~ /^\d/);
      $c->{$label}{$js_ts} = [ $pct, $v6as, $totalas ] ;
      #$c->{$label}{$js_ts} = $pct;
   }
}

my $j;
foreach my $label (sort keys %$c) {
   $j->{$label} = { 'label' => $label2label->{s2l}{$label}, 'data' => [] };
   foreach my $ts (sort keys %{$c->{$label}} ) {
      # so values are: ts, pct, v6as, totalas
      push @{$j->{$label}{data}}, [$ts+0, @{ $c->{$label}{$ts} } ];
   }
}

my $extjs = [];
## first do _ALL
my @longlabels_co = sort { $a cmp $b } map { $label2label->{s2l}{$_} } grep { $_ !~ /^_/ } keys %$c;
my @longlabels_rg = map { $label2label->{s2l}{$_} } sort { $a cmp $b } grep { $_ =~ /^_/ } keys %$c;
foreach my $longlabel ( @longlabels_co, @longlabels_rg ) {
   my $label = $label2label->{l2s}{$longlabel};
   if (! $label ){
      warn "no label for $longlabel\n";
      next;
   }
   my $entry = [$longlabel, $label, []];
   foreach my $ts (sort keys %{$c->{$label}} ) {
      # so values are: ts, pct, v6as, totalas
      push @{ $entry->[2] }, [$ts+0, @{ $c->{$label}{$ts} } ];
   }
   push @$extjs, $entry;
}


my $groups = LoadFile("country_groups.yaml");

open (DTA,'>',"$OUTDIR/datasets.js") or die;
#print DTA to_json($j, { ascii => 1, pretty => 1, canonical=>1 });
print DTA to_json($j, { ascii => 1, canonical=>1 });
close DTA;

open (EXT,'>',"$OUTDIR/extdata.js") or die;
print EXT to_json($extjs, { ascii => 1, canonical=>1});
close EXT;

open (CCN,'>',"$OUTDIR/label2label.js") or die;
print CCN to_json( $label2label , { canonical=> 1});
close CCN;

open (GR,'>',"$OUTDIR/groups.js") or die;
print GR to_json( $groups , { ascii => 1, canonical=>1 });
close GR;
