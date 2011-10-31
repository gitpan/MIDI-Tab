package MIDI::Tab;
# ABSTRACT: Generate MIDI from ASCII tablature

use strict;
use warnings;

use MIDI::Simple;

use base 'Exporter';
our @ISA = qw(Exporter);
our @EXPORT = qw(from_guitar_tab from_drum_tab from_piano_tab);

our $VERSION = 0.02;

=head1 NAME

MIDI::Tab - Generate MIDI from ASCII tablature

=head1 SYNOPSIS

  use MIDI::Tab;
  use MIDI::Simple;

  new_score;

  my $drums = <<'EOF';
  CYM: 8-------------------------------
  BD:  8-4---8-2-8-----8-4---8-2-8-----
  SD:  ----8-------8-------8-------8---
  HH:  66--6-6-66--6-6-66--6-6-66--6-6-
  OHH: --6-------6-------6-------6-----
  EOF

  my $bass = <<'EOF';
  G3: --------------------------------
  D3: --------------------------------
  A2: 5--53-4-5--53-1-----------------
  E2: ----------------3--31-2-3--23-4-
  EOF

  for(1 .. 4){
      synch(
          sub {
              from_drum_tab($_[0], $drums, 'sn');
          },
          sub {
              from_guitar_tab($_[0], $bass, 'sn');
          },
      );
  }

  write_score('demo.mid');

=head1 DESCRIPTION

C<MIDI::Tab> allows you to create MIDI files from ASCII tablature.  It
is designed to work alongside Sean M. Burke's C<MIDI::Simple>.

Currently, there are three types of tablature supported: drum, guitar
and piano tab.

=cut

# TODO Make a mutator method for this list:
our %drum_notes = (
    ABD => 35,  # Acoustic Bass Drum
    BD  => 36,  # Bass Drum 1
    CA  => 69,  # Cabasa
    CB  => 56,  # Cowbell
    CC  => 52,  # Chinese Cymbal
    CL  => 75,  # Claves
    CY2 => 57,  # Crash Cymbal 2
    CYM => 49,  # Crash Cymbal 1
    CYS => 55,  # Splash Cymbal
    ESD => 40,  # Electric Snare
    HA  => 67,  # High Agogo
    HB  => 60,  # Hi Bongo
    HC  => 39,  # Hand Clap
    HFT => 43,  # High Floor Tom
    HH  => 42,  # Closed Hi-Hat
    HMT => 48,  # Hi-Mid Tom
    HT  => 50,  # High Tom
    HTI => 65,  # High Timbale
    HWB => 76,  # Hi Wood Block
    LA  => 68,  # Low Agogo
    LB  => 61,  # Low Bongo
    LC  => 64,  # Low Conga
    LFT => 41,  # Low Floor Tom
    LG  => 74,  # Long Guiro
    LMT => 47,  # Low-Mid Tom
    LT  => 45,  # Low Tom
    LTI => 66,  # Low Timbale
    LW  => 72,  # Long Whistle
    LWB => 77,  # Low Wood Block
    MA  => 70,  # Maracas
    MC  => 78,  # Mute Cuica
    MHC => 62,  # Mute Hi Conga
    MT  => 80,  # Mute Triangle
    OC  => 79,  # Open Cuica
    OHC => 63,  # Open Hi Conga
    OHH => 46,  # Open Hi-Hat
    OT  => 81,  # Open Triangle
    PH  => 44,  # Pedal Hi-Hat
    RB  => 53,  # Ride Bell
    RI2 => 59,  # Ride Cymbal 2
    RID => 51,  # Ride Cymbal 1
    SD  => 38,  # Acoustic Snare
    SG  => 73,  # Short Guiro
    SS  => 37,  # Side Stick
    SW  => 71,  # Short Whistle
    TAM => 54,  # Tambourine
    VS  => 58,  # Vibraslap
);
%drum_notes = map { $_ => 'n' . $drum_notes{$_} } keys %drum_notes;

# TODO Make this a default attribute:
our $drum_channel = 'c9';

=head1 METHODS

Each of these routines generates a set of MIDI::Simple notes on the object
passed as the first parameter.  The parameters are:

 MIDI:Simple object
 Tab Notes (as ASCII text)
 Noop Arguments (for changing channels etc)

Parameters to the C<from_*_tab()> routines, that are specified after
the tablature string, are passed as C<MIDI::Simple::noop> calls at the
start of the tab rendering.  For example, the length of each unit
of time can be specified by passing a C<MIDI::Simple> duration value
(eg 'sn').

=head2 from_guitar_tab()

  from_guitar_tab($object, $tab_text, @noops)

Notes are specified by an ASCII representation of a guitar with each
horizontal line of ASCII characters representing a guitar string (as
if the guitar were laid face-up in front of you).

Time runs from left to right.  You can 'tune' the guitar by specifying
different root notes for the strings.  These should be specified as a
C<MIDI::Simple> alphanumeric absolute note value (eg 'A2').  The
numbers of the tablature represent the fret at which the note is
played.

=cut

sub from_guitar_tab {
    my ($score, $tab, @noop) = @_;

    $score->noop(@noop);

    my %lines = _parse_tab($tab);

    my @subs;

    for my $note (keys %lines) {
        my ($base_note_number) = is_absolute_note_spec($note);
        die "Invalid base note: $note " unless $base_note_number;

        my $_sub = sub {
            my $score = shift;
            #die "Invalid note: $note" unless ???;

            my @notes = _split_lines(\%lines, $note, $base_note_number);

            for my $n (@notes) {
                if (defined $n) {
                    $score->n($n);  # $note contains the volume
                }
                else {
                    $score->r;
                }
            }
        };

        push @subs, $_sub;
    }

    $score->synch(@subs);
}

=head2 from_drum_tab()

  from_drum_tab($object, $tab_text, @noops)

Each horizontal line represents a different drum part and time runs
from left to right.  Minus or plus characters represent rest intervals.
As many or as few drums as required can be specified, each drum having
a two or three letter code, such as C<BD> for the General MIDI "Bass
Drum 1" or C<SD> for the "Acoustic Snare."  These are all listed in
C<%MIDI::Tab::drum_notes>, which can be viewed or altered by your code.

The numbers on the tablature represent the volume of the drum hit,
from 1 to 9, where 9 is the loudest.

If desired, the MIDI channel that is used for drums (default 9) can be
changed by altering C<$MIDI::Tab::drum_channel>.

=cut

sub from_drum_tab {
    my ($score, $tab, @noop) = @_;

    $score->noop($drum_channel, @noop);

    my %lines = _parse_tab($tab, 'drum');

    my @subs;

    for my $note (keys %lines) {
        my $_sub = sub {
            my $score = shift;
            die "Invalid drum type: $note" unless $drum_notes{$note};
            my $drum = $drum_notes{$note};

            my @notes = _split_lines(\%lines, $note);

            for my $n (@notes) {
                if (defined $n) {
                    $score->n($drum_channel, $drum, $n);  # The note contains the volume
                }
                else {
                    $score->r;
                }
            }
        };

        push @subs, $_sub;
    }

    $score->synch(@subs);
}

=head2 from_piano_tab()

  from_piano_tab($object, $tab_text, @noops)

Each horizonal line represents a different note on the piano and time
runs from left to right.

=cut

sub from_piano_tab {
    my ($score, $tab, @noop) = @_;

    $score->noop(@noop);

    my %lines = _parse_tab($tab);

    my @subs;

    for my $note (keys %lines) {
        my $_sub = sub {
            my $score = shift;
            #die "Invalid note: $note" unless ???;

            my @notes = _split_lines(\%lines, $note);

            for my $volume (@notes) {
                if (defined $volume) {
                    $score->n($note, $volume);  # $note contains the volume
                }
                else {
                    $score->r;
                }
            }
        };

        push @subs, $_sub;
    }

    $score->synch(@subs);
}

sub _parse_tab {
    my($tab, $type) = @_;

    my %lines;

    my $re = qr/^\s*([A-Za-z0-9]+)\:\s*([0-9+-]+)\s+(.*)$/s;
    $re = qr/^\s*([A-Z]{2,3})\:\s*([0-9+-]+)\s+(.*)$/s if $type && $type eq 'drum';

    while($tab =~ /$re/g) {
        my ($base, $line, $rest) = ($1, $2, $3);
        $lines{$base} = $line;
        $tab = $rest;
    }

    return %lines;
}

sub _split_lines {
    my($lines, $note, $base) = @_;
    
    my @notes = map {(
        $_ =~ /^[0-9]$/ ? ($base ? 'n' . ($base + $_) : ('V' . $_ * 12)) : undef
    )} split '', $lines->{$note};

    return @notes;
}

1;
__END__

=head1 SEE ALSO

* The code in the C<eg/> and C<t/> directories.

* L<MIDI::Simple>

=cut
