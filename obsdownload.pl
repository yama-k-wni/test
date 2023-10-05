#!/usr/bin/perl

use LWP::Simple;
use Time::Local;

my $BASEDIR = "/Users/yamauekazuhiro/tmp";
our $tblfile="/Users/yamauekazuhiro/tmp/amedas.tbl";

my $start=$ARGV[0];
my $end=$ARGV[1];

if ( $#ARGV < 1 ) {
  print STDERR "Usage : $myname$suffix <startdate> <enddate>\n";
  exit 1;
}


#時刻をエポック秒に変換
my $syear=substr($start,0,4);
my $smon=substr($start,4,2);
my $sday=substr($start,6,2);
my $stime = timegm(0,0,0,$sday,$smon-1,$syear-1900);

my $eyear=substr($end,0,4);
my $emon=substr($end,4,2);
my $eday=substr($end,6,2);
my $etime = timegm(0,0,0,$eday,$emon-1,$eyear-1900);


for (my$ntime=$stime; $ntime<=$etime; $ntime+=86400) {
  my($d1_sec,$d1_min,$d1_hour,$d1_day,$d1_mon,$d1_year,$d1_wday,$d1_yday,$d1_isdst)
    = gmtime($ntime);
  my $year = sprintf("%04d",$d1_year+1900);
  my $mon = sprintf("%02d",$d1_mon+1);
  my $day = sprintf("%02d",$d1_day);
  print "BASETIME:$year$mon$day\n";

  my $TMPDIR = sprintf("$BASEDIR/data/tmp");
  my $DATADIR = sprintf("$BASEDIR/data");
  system("mkdir -p $TMPDIR");
  #system("mkdir -p $DATADIR");

  my %ids = pointFilter();

  #地点ごとにデータダウンロード
  my $file;
  foreach my$i(keys %ids){
    my $id = $ids{$i};
    my $obs_link = "http://stored1.wni.co.jp/amedas_tsuuho.1hour/nph-data.cgi?station=$id&period_s=$year/$mon/$day-00:00:00&period_e=$year/$mon/$day-23:00:00&element=Precipitation,Temperature";

    my $file = sprintf("$TMPDIR/%s",$id);
    my $status = getstore($obs_link, $file);
    print "$file\n";
    if (!is_success($status)) {
      print "\nError $status on $file!";
      print "$file\n";
    }
  }


  # 処理しやすいように整形する
  my $outfile =sprintf("$DATADIR/%04d%02d%02d.csv",$year, $mon, $day);
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
