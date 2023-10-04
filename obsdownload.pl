#!/usr/bin/perl

use LWP::Simple;
use Time::Local;

my $BASEDIR = "/Users/yamauekazuhiro/tmp";
our $tblfile="/Users/yamauekazuhiro/tmp/amedas.tbl";

for (my$d=0; $d>=0; $d--) {
  my($l_sec,$l_min,$l_hour,$l_day,$l_mon,$l_year,$l_wday,$l_yday,$l_isdst)
    = gmtime(time);
  my $time = timegm(0,0,$l_hour,$l_day,$l_mon,$l_year);

  # 1日前
  my $da=$d+1;
  my $day1ago_time = $time - 3600*24*$da;
  my($d1_sec,$d1_min,$d1_hour,$d1_day,$d1_mon,$d1_year,$d1_wday,$d1_yday,$d1_isdst)
    = gmtime($day1ago_time);
  my $year1d = sprintf("%04d",$d1_year+1900);
  my $mon1d = sprintf("%02d",$d1_mon+1);
  my $day1d = sprintf("%02d",$d1_day);
  print "BASETIME:$year1d$mon1d$day1d\n";

  my $TMPDIR = sprintf("$BASEDIR/data/tmp");
  my $DATADIR = sprintf("$BASEDIR/data");
  system("mkdir -p $TMPDIR");
  #system("mkdir -p $DATADIR");

  my %ids = pointFilter();

  #地点ごとにデータダウンロード
  my $file;
  foreach my$i(keys %ids){
    my $id = $ids{$i};
    my $obs_link = "http://stored1.wni.co.jp/amedas_tsuuho.1hour/nph-data.cgi?station=$id&period_s=$year1d/$mon1d/$day1d-00:00:00&period_e=$year1d/$mon1d/$day1d-23:00:00&element=Precipitation,Temperature";

    my $file = sprintf("$TMPDIR/%s",$id);
    my $status = getstore($obs_link, $file);
    print "$file\n";
    if (!is_success($status)) {
      print "\nError $status on $file!";
      print "$file\n";
    }
  }


  # 処理しやすいように整形する
  my $outfile =sprintf("$DATADIR/%04d%02d%02d.csv",$year1d, $mon1d, $day1d);
  print "$outfile\n";
  open($OUT,'>', $outfile);

  print $OUT "HEAD:ID,DATE(UTC),precip,temp\n";

  if(open(my $TBL, '<', $tblfile)){
   while (my $tblrow = <$TBL>){
    chomp $tblrow;
    next if($tblrow =~ /#/);
    my @tbl = split /,/, $tblrow;
    my $asmid = $tbl[0];
    my $amedasid = $tbl[4];

    my $file = sprintf("$TMPDIR/%s",$amedasid);
    if (open(my $ff, '<', $file)){
      while (my $row = <$ff>) {
        chomp $row;
        next if($row=~/#/);
        my @elements = split /\s/, $row;
        $elements[1] =~ /(\d{4})\/(\d{2})\/(\d{2})-(\d{2}):(\d{2}):(\d{2})/; #観測時刻
        my $prec = $elements[2] / 10;
	my $temp = $elements[3] / 10;
        print $OUT "$amedasid,$1$2$3$4,$prec,$temp\n";
      }
    } #if (open(my $ff, '<', $file))
   }
  }
  close($TBL);
  close($OUT);
} # for (my$d=0; $d>=0; $d--)


sub pointFilter{
  my %points;
  if (open(my $fh, '<:encoding(UTF-8)', $tblfile)) {
    while (my $row = <$fh>) {
      chomp $row;
      next if($row !~ /AMEDAS/);
      my @elements = split /,/, $row;
      if($elements[1] eq "AMEDAS"){
        $points{$elements[0]} = $elements[4];
      }
    }
  }
  else {
    warn "Could not open file '$tblfile' $!";
  }
  return %points;
}
