package MIDI::Tab;

use Data::Dumper;
use strict;
use MIDI::Simple;
use Exporter;
use vars qw(@EXPORT @ISA $VERSION);
$VERSION = 0.01;
@ISA = qw(Exporter);
@EXPORT = qw(from_guitar_tab from_drum_tab from_piano_tab);

=head1 NAME

MIDI::Tab - generate MIDI music from ascii tablature

=head1 TO DO

Document each function properly
Explain about first parameter to functions
Maybe simple test suite

Try to make it so that from_guitar_tab etc can be called as a
  normal method or function call (instead of passing object
  as first parameter)

=head1 SYNOPSIS

  use MIDI::Tab;
  use MIDI::Simple;

  new_score;  # From MIDI::Simple

  my $drums = <<"EOF";

  CYM: 8-------------------------------
  BD:  8-4---8-2-8-----8-4---8-2-8-----
  SD:  ----8-------8-------8-------8---
  HH:  66--6-6-66--6-6-66--6-6-66--6-6-
  OHH: --6-------6-------6-------6-----

  EOF

  my $bass = <<"EOF";
  G3: --------------------------------
  D3: --------------------------------
  A2: 5--53-4-5--53-1-----------------
  E2: ----------------3--31-2-3--23-4-

  EOF

  for(1..4){
      synch(  # From MIDI::Simple
	  sub {
              from_drum_tab($_[0], $drums, 'sn');
	  },
          sub {
	      from_guitar_tab($_[0], $bass, 'sn');
          },
      )
  }

  write_score('demo.mid');  # From MIDI::Simple

=head1 DESCRIPTION

MIDI::Tab allows you to create MIDI files from ascii tablature.  It is
designed to work alongside Sean M Burke's MIDI::Simple.  There are
currently three types of tablature supported:

Drum Tab

Each horizontal line represents a different drum, and time runs from
left to right.  Minus or plus characters represent rest intervals.  As
many or as few drums as required can be specified, each drum having a two
or three letter code.  Currently supported are: BD - Bass Drum,
SD - Snare Drum, HH - Hi-Hat, OHH - Open Hi-Hat, CYM - Crash Cymbal.  More
can be added by writing to the hash %MIDI::Tab::drum_notes (see source
for example).  The numbers on the tablature represents
the volume of the drum hit (from 1 to 9, where 9 is the loudest).
Any parameters to from_drum_tab specified after the tablature string
are passed to a call to 'noop' at the start of the tab rendering, so
for example the length of each unit of time can be specified by passing
a standard MIDI::Simple duration value (eg 'sn').  The channel that is
used to play the drum notes can be changed by altering $MIDI::Tab::drum_channel
(defaults to 'c9').

Guitar Tab

Notes here are specified on an ascii representation of a guitar with
each horizontal line of ascii characters representing one string on
the guitar (as if the guitar were laid face-up in front of you).
Time runs from left to right.  You can 'tune' the guitar by specifying
different root notes for the strings.  These should be specified as a
MIDI::Simple alphanumeric absolute note value (eg 'A2'). The numbers
in the tablature represent the fret at which the note is played.
Any parameters to from_guitar_tab specified after the tablature string
are passed to a call to 'noop' at the start of the tab rendering, so
for example the length of each unit of time can be specified by passing
a standard MIDI::Simple duration value (eg 'sn') and the instrument
can be selected (eg 'c3').

Piano Tab

Here, each horizonal line represents a different note on the piano
and time runs from left to right.

=cut

my %drum_notes = (
    'BD'  => 'n36',
    'SD'  => 'n38',
    'HH'  => 'n42',
    'OHH' => 'n46',
    'CYM' => 'n49',
    'RID' => 'n51',
    'SS'  => 'n37',  # Side Stick
);

my $drum_channel = 'c9';

#my $string_1_root = 28;
#my $string_2_root = 33;
#my $string_3_root = 38;
#my $string_4_root = 43;
#my $string_5_root = 47;
#my $string_6_root = 52;

=head1 USAGE

=head2 from_guitar_tab

=head2 from_piano_tab

=head2 from_drum_tab

Each of these routines generates a set of MIDI::Simple notes on the object
passed as the first parameter.  The parameters are:

 MIDI:Simple object
 Tab Notes (as ascii text)
 Noop Arguments (for changing channels etc)

See synopsis for examples.

=head1 EXAMPLES

Examples can be found in the 'examples' directory.

=head1 AUTHOR

	Robert J. Symes
	rob@robsymes.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<MIDI::Simple>, perl(1).

=cut

sub from_guitar_tab {
    my ($s, $tab, @noop_args) = @_;

    $s->noop(@noop_args);

    my $tab2 = $tab;
    my %lines;
    while($tab2 =~ /^\s*([A-Za-z0-9]+)\:\s*([0-9+-]+)\s+(.*)$/sg) {
        my $base_note = $1;
	my $line = $2;
	my $rest_of_tab = $3;
	$tab2 = $rest_of_tab;

	$lines{$base_note} = $line;
    }

    my @guitar_subs;
    foreach my $base_note(keys %lines) {
	my ($base_note_number) = is_absolute_note_spec($base_note);
	die "Invalid base note: $base_note"
	    unless $base_note_number;
	my $guitar_sub = sub {
	    my $s = shift;
	    #die "Invalid note: $note"
	    #    unless ???;

	    my @notes = map {
		(
		    $_ =~ /^([0-9])$/
                  ? 'n' . ($base_note_number + $_)
	          : undef
		 )
	    } split('', $lines{$base_note});

	    foreach my $note(@notes) {
		if (defined($note)) {
		    $s->n($note);  # $note contains the volume
		} else {
		    $s->r;
		}
	    }
	};
	push @guitar_subs, $guitar_sub;
    }

    $s->synch(@guitar_subs);

}

sub from_drum_tab {
    my ($s, $tab, @noop_args) = @_;

    $s->noop($drum_channel, @noop_args);

    my $tab2 = $tab;
    my %drums;
    while($tab2 =~ /^\s*([A-Z]{2,3})\:\s*([0-9+-]+)\s+(.*)$/sg) {
        my $drum = $1;
	my $drumline = $2;
	my $rest_of_tab = $3;
	$tab2 = $rest_of_tab;

	$drums{$drum} = $drumline;
    }

    my @drum_subs;
    foreach my $drum_type(keys %drums) {
	my $drum_sub = sub {
	    my $s = shift;
	    die "Invalid drum type: $drum_type"
		unless $drum_notes{$drum_type};
            my $drum_note = $drum_notes{$drum_type};

	    my @notes = map {
		(
		    $_ =~ /^([0-9])$/
                  ? ('V' . $_ * 12 )
	          : undef
		 )
	    } split('', $drums{$drum_type});

	    foreach my $note(@notes) {
		if (defined($note)) {
		    $s->n($drum_channel, $drum_note, $note);  # $note contains the volume
		} else {
		    $s->r;
		}
	    }
	};
	push @drum_subs, $drum_sub;
    }

    $s->synch(@drum_subs);

}

sub from_piano_tab {
    my ($s, $tab, @noop_args) = @_;

    $s->noop(@noop_args);

    my $tab2 = $tab;
    my %lines;
    while($tab2 =~ /^\s*([A-Za-z0-9]+)\:\s*([0-9+-]+)\s+(.*)$/sg) {
        my $note = $1;
	my $line = $2;
	my $rest_of_tab = $3;
	$tab2 = $rest_of_tab;

	$lines{$note} = $line;
    }

    my @piano_subs;
    foreach my $note(keys %lines) {
	my $piano_sub = sub {
	    my $s = shift;
	    #die "Invalid note: $note"
	    #    unless ???;

	    my @notes = map {
		(
		    $_ =~ /^([0-9])$/
                  ? ('V' . $_ * 12 )
	          : undef
		 )
	    } split('', $lines{$note});

	    foreach my $volume(@notes) {
		if (defined($volume)) {
		    $s->n($note, $volume);  # $note contains the volume
		} else {
		    $s->r;
		}
	    }
	};
	push @piano_subs, $piano_sub;
    }

    $s->synch(@piano_subs);

}

1;
