#!/usr/bin/env perl
use v5.28.1;
use warnings;
use strict;
#use diagnostics;

use JSON;
use Class::Date qw(:errors date);

# put all holidays into a hash
my $holidays;
for my $h (
           qw(2020/01/01 2020/01/06 2020/04/10 2020/04/13 2020/05/01 2020/05/21
              2020/06/19 2020/12/24 2020/12/25 2020/12/31

              2021/01/01 2021/01/06 2021/04/02 2021/04/05 2021/05/13 2021/06/25
              2021/12/24 2021/12/31 )
          ) {
  $holidays->{$h} = 1;
}

# --------------------------------------------------
# Start here
my $input = decode_json(join('', <STDIN> ));
my @issues = @{$input->{issues}};

my $number_of_tickets = 0;
my $total_cycle_time;


# loop through each jira issue
for my $issue (@issues) {

  my $key = $issue->{key};
  my @history=@{$issue->{changelog}->{histories}};

  my ($start_s, $done_s, $backlog_s);

  for my $event (@history) {
    my @items = @{$event->{items}};

    for my $item (@items) {
      next unless ($item->{field} eq 'status');

      if ($item->{toString}   eq 'In Progress') { $start_s   = $event->{created}; }
      if ($item->{toString}   eq 'Done')        { $done_s    = $event->{created}; }
      if ($item->{fromString} eq 'Backlog')     { $backlog_s = $event->{created}; }
    }
  }

  # if a card was dragged from backlog straight to done:
  $start_s = $backlog_s unless (defined $start_s);

  # calculate cycletime for ticket
  my $startTime = date $start_s;
  my $doneTimeReal = date $done_s;
  my $doneTime = date($doneTimeReal);

  # check for weekends and holidays
  my $weekendCount = 0;
  my $holidayCount = 0;
  my $day = $startTime;
  my $lastDay = $doneTime->ymd;
  while ($day->ymd ne $lastDay) {
    $day = $day+'1D';
    my $wday = $day->wday;

    # skip if Sunday(1) or Saturday(7)
    if ($wday == 1 or $wday == 7) {
      $doneTime = $doneTime-'1D';
      $weekendCount++;
    }

    # skip if this is a holiday
    if (exists $holidays->{$day->ymd}) {
      $doneTime = $doneTime-'1D';
      $holidayCount++;
    }

  }
  my $cycleTime = $doneTime - $startTime;

  # print all for manual eyeballing
  print "$key\n";
  print ' ' x 5 . "Start: " . $startTime->ymd . ' ' . $startTime->hms . "\n";
  print ' ' x 5 . "  End: " . $doneTimeReal->ymd . ' ' . $doneTimeReal->hms . "\n";
  print ' ' x 5 . "There are $weekendCount off-days in this range.\n";
  print ' ' x 5 . "There are $holidayCount holidays in this range.\n";
  print ' ' x 5 . "Cycle: " . $cycleTime->hour . "\n";

  $total_cycle_time += $cycleTime->hour;
  $number_of_tickets++;
}

my $avg_cycle_time = sprintf("%.3f", $total_cycle_time / $number_of_tickets);

print "# of tickets:   $number_of_tickets\n";
print "avg cycle time: $avg_cycle_time\n";
