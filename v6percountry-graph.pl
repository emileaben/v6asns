#!/usr/bin/env perl
# $Id: v6percountry-graph.pl 41740 2012-10-29 08:09:48Z eaben $
use strict;
use warnings;
use lib qw(/home/inrdb/perl /opt/local/lib/perl5/site_perl/5.8.9/ /home/inrdb/perl5/lib/perl5);
use CGI;
use JSON qw(to_json from_json);
use FindBin qw($RealBin);

#my $BASE_URL = "http://localhost/v6asnpercountry";
#my $BASE_URL = '/demo-area/v6asn';
my $BASE_URL = '';
my $DATASETS_FILE = "/var/www/html/v6asns/$BASE_URL/datasets.js";
my $EXTDATA_FILE = "/var/www/html/v6asns/$BASE_URL/extdata.js";
my $LABEL2LABEL_FILE = "/var/www/html/v6asns/$BASE_URL/label2label.js";

my $cgi = CGI->new();

# get from params what I need
my $par = {'selected' => []};
if ( $cgi->param('s') ) { # s=selected labels
   @{ $par->{'selected'} } = grep { $_ =~ /^[A-Z_]+$/ } map { split(/,/, $_) } $cgi->param('s');
   #@{ $par->{'selected'} } = map { split(/,/, $_) } $cgi->param('s');
} else {
   @{ $par->{'selected'} } = ('_ALL');
}

my $mode = $cgi->param('m');
$mode ||= 'g';

if ( $mode eq 'g' ) { #mode = graph
   do_graph($cgi, $par);
} elsif ( $mode eq 'c' ) { # mode = csv
   do_csv($cgi, $par);
} else {
   warn "unknown mode (cgi param 'm')\n";
   do_graph($cgi, $par);
}

sub do_csv {
   my ($cgi, $par) = @_;
   #print $cgi->header('text/csv');
   print $cgi->header('text/csv');
   if (! open(F,$DATASETS_FILE) ) {
      print "Couldn't load data $DATASETS_FILE\n";
      die;
   }
   my $filedata = do { local $/ = undef; <F> };
   close F;
   my $dataset = from_json($filedata);
   my $csv;
   foreach my $co (@{$par->{selected}}) {
      if ( $dataset->{$co} && $dataset->{$co}{data} ) {
         foreach my $kv (@{ $dataset->{$co}{data} } ) {
            my ($date,$val) = (@$kv);
            my (undef,undef,undef,undef,$mo,$yr) = gmtime($date/1000);
            my $date_key;
            if ( $mo == 0 ) {
               $date_key = $yr+1900;   
            } else {
               $date_key = sprintf("%04d-%02d",$yr+1900,$mo+1);
            }
            $csv->{$date_key}{$co} = $val;
         }
      }
   }
   # header
   print join(',','Date', @{$par->{selected}}) . "\n";
   foreach my $date_str (sort keys %$csv) {
      my @fields = ($date_str);
      foreach my $co (@{$par->{selected}} ) {
         push @fields, $csv->{$date_str}{$co} ? $csv->{$date_str}{$co} : 'NaN';
      }
      print join(',',@fields) . "\n";
   }
}

sub do_graph {
   my ($cgi, $par) = @_;
   print $cgi->header('text/html; charset=UTF-8');
   print graph_html($par);
}

sub graph_html {
   my ($par) = @_;

   if (! open(F,$EXTDATA_FILE) ) {
      print "Couldn't load data $EXTDATA_FILE\n"; die;
   }
   my $extdata = do { local $/ = undef; <F> };
   close F;

   if (! open(F,$LABEL2LABEL_FILE) ) {
      print "Couldn't load data $LABEL2LABEL_FILE\n"; die;
   }
   my $label2label = do { local $/ = undef; <F> };
   close F;


   my $selected_json = to_json( $par->{selected} );
   my $self_url = ($cgi->https() ? 'https://' : 'http://' ) . join('',$cgi->virtual_host,$cgi->script_name());
   return <<"EOF";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
 <head>
   <title>IPv6 Enabled Networks</title>
   <meta http-equiv="Content-Type" content="text/html"; charset='UTF-8'>

   <!--[if IE]><script language="javascript" type="text/javascript" src="$BASE_URL/js/excanvas.min.js"></script><![endif]-->


   <script language="javascript" type="text/javascript" src="$BASE_URL/js/jquery.js"></script>
   <script language="javascript" type="text/javascript" src="$BASE_URL/js/jquery.flot.js"></script>
   <script language="javascript" type="text/javascript" src="$BASE_URL/js/jquery.flot.selection.js"></script>

   <link rel="stylesheet" type="text/css" href="$BASE_URL/js/ext/resources/css/ext-all.css" />
   <script type='text/javascript' src='$BASE_URL/js/ext/adapter/ext/ext-base.js'></script> <!-- DEBUG -->
   <!-- <script type='text/javascript' src='$BASE_URL/js/ext/ext-all.js'></script>  -->
   <script type='text/javascript' src='$BASE_URL/js/ext/ext-all-debug.js'></script> 

    <link href="http://www.ripe.net/includes/tpl/layout.css" rel="stylesheet" type="text/css" />
<style type="text/css">
.remove_button {
   background-image: url(/media/button_minus.png) !important;
}
</style>

 </head>
 <body>
    <h1>IPv6 Enabled Networks</h1>

    <div id='error'></div>
    <div id='perma_container'>
      <span>permalink: </span>
      <span id='permaurl_inner'></span>
    </div>
    <div id='combo_container'>
    </div>
    <p>This graph shows the percentage of networks (ASes) that announce an IPv6 prefix for a specified list of countries or groups of countries</p>

    <div style="float:left">
     <div id="placeholder" style="width:800px;height:600px"></div>
    </div>
    <p id="overviewLegend" style="margin-left:10px"></p>
    <h2>Methodology</h2>
<p>
For every date we sampled, we took all BGP table dumps from the Routing
Information Service (RIS) and counted the percentage of ASes that announced an
IPv6 prefix, relative to the total number of ASes in this routing table. 
We removed routes that were visible in less then 10 RIS BGP feeds [1].
We mapped the ASes to country using the RIR stats files. To assess the accuracy of
that mapping we compared it to geolocating all announced IPv4 space for an AS.
Geolocation was done with the MaxMind geolocation database. We found that in
89% of ASes all IPv4 address space geolocated to the same country as RIR stats.
An extra 5% of ASes geolocated to multiple countries, but the largest fraction
of address space geolocated to the same country as RIR stats. Some countries do
not show up in this graph, either because there are no ASes in the RIR stats
for that country, or the ASes listed for the country are not announcing any
address space.
</p>
<div style="height:2em"></div>
<p>
[1] This change was made August 2017 and we reran the full dataset with this filter.
Previous to this change the percentage of IPv6 enabled networks was slightly larger, by
at most a few tenths of percents.
</p>

<script id="source" language="javascript" type="text/javascript">

Ext.onReady(function() {
   // our cache of selected items;
   var selected = ( $selected_json );

   // convert between short and long labels
   var l2l = ( $label2label );


   // graph colors
   var graph_colors = [
        "rgb(255, 206, 0)",
        "rgb(205, 32, 44)",
        "rgb(0, 151, 255)",
        "rgb(255, 100, 25)",
        "rgb(204, 51, 255)",
        "rgb(114, 184, 180)",
        "rgb(255, 255, 255)",
        "rgb(225, 135, 255)"
   ];
   var graph_colors_len = graph_colors.length;

   var store = new Ext.data.ArrayStore({
      fields: ['name', 'abbr', 'series'],
      idIndex: 0,
      data : $extdata
   });

   var combopanel = new Ext.Window({
      applyTo: 'combo_container',
      closable: false
   });

   function styledComboContainer(comboVal, combo_idx) {
         var cnt = new Ext.Container({
         cls: 'combo_container_el',
         items: [ 
            new Ext.form.Label({
               html: '<div style="width: 1em; height: 1em; border: 1px solid black; background: ' + graph_colors[combo_idx] + '; overflow: hidden;"></div>'
            }),
            new Ext.form.ComboBox({
               store: store,
               displayField:'name',
               typeAhead: true,
               mode: 'local',
               triggerAction: 'all',
               emptyText:'Add country/grouping..',
               selectOnFocus:true,
               listeners: {
                  'select': function() {
                     plotAccordingToChoices();
                  }
               },
               value: comboVal
            }),
            new Ext.Button({
               iconCls: 'remove_button',
               hideMode: 'visibility',
               listeners: {
                  'click': function(e,t) {
                     this.findParentByType('container').destroy();
                     plotAccordingToChoices();
                     fillComboPanel();
                     combopanel.doLayout();
                  }
               }
            })
         ],
         layout: 'column'
      });
      return cnt;
   }
 
   fillComboPanel(); 
   combopanel.doLayout();
   combopanel.show();
   function fillComboPanel() {
      removeContainers = combopanel.findByType('container');
      for (var ridx=0,len = removeContainers.length; ridx < len ; ridx ++ ) {
         removeContainers[ridx].destroy();
      }
      for (var combo_idx=0,len = selected.length; combo_idx < len; combo_idx++) {
         var comboVal = l2l.s2l[ selected[combo_idx] ];
         var comboContainer = styledComboContainer(comboVal, combo_idx)
         combopanel.add(comboContainer);
      }
      // new 'empty combobox comes last
      var emptyComboContainer = null;
      addEmptyComboBox();
      combopanel.alignTo( Ext.get("placeholder"), 'tl-tl', [40,30] );
      function addEmptyComboBox() {
         if ( emptyComboContainer ) {
            // remove addition function from last combobox
            emptyComboButtonList = emptyComboContainer.findByType('button');
            emptyComboButtonList[0].show();
            emptyComboList = emptyComboContainer.findByType('combo');
            emptyComboList[0].removeListener('select',addEmptyComboBox);
            emptyComboContainer.doLayout();
         }
         if( combopanel.findByType('container').length < graph_colors_len ) {
            emptyComboContainer = styledComboContainer(null, selected.length );
            emptyComboList = emptyComboContainer.findByType('combo');
            emptyComboBox = emptyComboList[0];
            emptyComboBox.addListener('select',plotAccordingToChoices);
            emptyComboBox.addListener('select',addEmptyComboBox);
            emptyComboButtonList = emptyComboContainer.findByType('button');
            emptyComboButtonList[0].hide();
            combopanel.add( emptyComboContainer );
         }
         combopanel.doLayout();
      }
   }
  
   function permaURL() {
      var purl = '$self_url?';
      var slist = [];
      for (var idx=0,len=selected.length;idx < len; idx++) {
         slist.push('s='+selected[idx]);
      }
      purl += slist.join(';');
      \$('#permaurl_inner').html(
         '<input type="text" size="80" value="' + purl + '">'
      );
   }

   // generate permaurl
   permaURL();

   function showTooltip(x, y, contents) {
        \$('<div id="tooltip">' + contents + '</div>').css( {
            position: 'absolute',
            display: 'none',
            top: y + 5,
            left: x + 5,
            border: '1px solid #fdd',
            padding: '2px',
            'background-color': '#fee',
            opacity: 0.80
        }).appendTo("body").fadeIn(200);
   };

   
   function plotAccordingToChoices() {
      var data = [];
      selected = [];
     
      var cboxes = combopanel.findByType('combo'); 
      for(var idx=0,len=cboxes.length; idx < len; idx++) {
         var cbox_val = cboxes[idx].getValue();
         if (cbox_val) {
            selected.push( l2l.l2s[ cbox_val ] );
            var rec = store.getById(cbox_val);
            data.push({ 
               label: cbox_val, 
               data: rec.get('series'),
               color: graph_colors[idx]
            });
         }
      }

      // generate permaURL (after selected)
      permaURL();

      if (data.length > 0) {
         \$.plot(\$("#placeholder"), data, {
            yaxis: { position: 'left', min: 0, tickFormatter: function (v, axis) { return v.toFixed(axis.tickDecimals) + "%" }},
            xaxis: { mode: "time" },
            grid: { 
               hoverable: 'yes',
               backgroundColor: 'rgb(162,162,162)'
            },
            selection: { mode: "xy" },
            legend: { show: false, container: \$("#overviewLegend") }
         });
            /*
            var overview = \$.plot(\$("#overview"), data, {
               legend: { show: false },
               series: {
                  lines: { show: true, lineWidth: 1 },
                  shadowSize: 0
               },
               xaxis: { ticks: 4 },
               yaxis: { ticks: 3, min: -2, max: 2 },
               grid: { 
                  color: 'rgb(200,10,400)', // #999",
                  backgroundColor: 'rgb(60,60,160)'
               },
               selection: { mode: "xy" }
            });
            */
            \$("#placeholder").bind("plotselected", function (event, ranges) {
               // clamp the zooming to prevent eternal zoom
               if (ranges.xaxis.to - ranges.xaxis.from < 0.00001)
                  ranges.xaxis.to = ranges.xaxis.from + 0.00001;
               if (ranges.yaxis.to - ranges.yaxis.from < 0.00001)
                  ranges.yaxis.to = ranges.yaxis.from + 0.00001;
        
               // do the zooming
/* disable zooming for now
               plot = \$.plot(\$("#placeholder"), getData(ranges.xaxis.from, ranges.xaxis.to),
                      \$.extend(true, {}, options, {
                          xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                          yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
                      }));
*/
        
            });

            var previousPoint = null;
            \$("#placeholder").bind("plothover", function (event, pos, item) {
               \$("#x").text(pos.x.toFixed(2));
               \$("#y").text(pos.y.toFixed(2));

               if (item) {
                   if (previousPoint != item.datapoint) {
                       previousPoint = item.datapoint;
                       
                       \$("#tooltip").remove();
                       var x = item.datapoint[0].toFixed(2),
                           y = item.datapoint[1].toFixed(2);
                       // convoluted way to get to the additional data below ....
                       var thisdata = item.series.data;
                       var v6_as = '-', tot_as = '-';
                       for (this_idx in thisdata) {
                           if ( thisdata[this_idx][0] == x ) {
                              v6_as = thisdata[this_idx][2];
                              tot_as = thisdata[this_idx][3];
                           }
                       }
                      
                       var dobj = new Date(parseInt(x));
                       var mon = parseInt(dobj.getMonth())+1;
                       var dom = parseInt(dobj.getDate());
                       if (dom < 10) { dom = "0"+dom }
                       if (mon < 10) { mon = "0"+mon }
                       var tiplabel = 
                           item.series.label + ":<br/>" + 
                           y + "% (" + v6_as + " out of " + tot_as + " ASes)<br/>" +
                           //y + "%<br/>" +
                           "on " + dobj.getFullYear() + "-" + mon + "-" + dom;
                       showTooltip(item.pageX, item.pageY, tiplabel );
                   }
               }
               else {
                   \$("#tooltip").remove();
                   previousPoint = null;            
               }
            });
      };
   };

   plotAccordingToChoices();
});
</script>

 </body>
</html>
EOF
}

