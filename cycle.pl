#!/usr/bin/env perl
use v5.28.1;
use warnings;
use strict;
#use diagnostics;

use JSON;
use Class::Date qw(:errors date);

my $input = decode_json(join('', <STDIN> ));
my @issues = @{$input->{issues}};

my $number_of_tickets = 0;
my $total_cycle_time;

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

  # check for weekends
  my $weekendCount = 0;
  my $day = $startTime;
  my $lastDay = $doneTime->ymd;
  while ($day->ymd ne $lastDay) {
    $day = $day+'1D';
    my $wday = $day->wday;

    if ($wday == 1 or $wday == 7) { # Sunday or Saturday;
      $doneTime = $doneTime-'1D';
      $weekendCount++;
    }
  }
  my $cycleTime = $doneTime - $startTime;

  # print all for manual eyeballing
  print "$key\n";
  print ' ' x 5 . "Start: " . $startTime->ymd . ' ' . $startTime->hms . "\n";
  print ' ' x 5 . "  End: " . $doneTimeReal->ymd . ' ' . $doneTimeReal->hms . "\n";
  print ' ' x 5 . "There are $weekendCount off-days in this range.\n";
  print ' ' x 5 . "Cycle: " . $cycleTime->hour . "\n";

  $total_cycle_time += $cycleTime->hour;
  $number_of_tickets++;
}

my $avg_cycle_time = sprintf("%.3f", $total_cycle_time / $number_of_tickets);

print "# of tickets:   $number_of_tickets\n";
print "avg cycle time: $avg_cycle_time\n";
