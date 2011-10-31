#!perl -T
use strict;
use warnings;
use Test::More 'no_plan';

BEGIN {
    use_ok('MIDI::Tab');
    use_ok('MIDI::Simple');
}

new_score;
patch_change 1, 34;
my $drums = <<'EOF';
CYM: 8-------------------------------
BD:  8-4---8-2-8-----8-4---8-2-8-----
SD:  ----8-------8-------8-------8---
HH:  66--6-6-66--6-6-66--6-6-66--6-6-
OHH: --6-------6-------6-------6-----
EOF
synch( sub { from_drum_tab($_[0], $drums, 'sn') } );
my $file = 't/drums.mid';
write_score($file);
ok -s $file, 'drums';

new_score;
patch_change 2, 24;
my $guitar = <<'EOF';
E5: +---0-------0---+---0-----------
B4: --------3-------1-------0-------
G4: --------------------------0---0-
D4: --2---2---2---2---2---2-----2---
A3: 3-------------------------------
E3: --------------------------------
EOF
synch( sub { from_guitar_tab($_[0], $guitar, 'sn', 'c2') } );
$file = 't/guitar.mid';
write_score($file);
ok -s $file, 'guitar';

# XXX This is *way* too quiet. Figure out what is up!
new_score;
my $piano = <<'EOF';
C5: 11
C3: 11
EOF
synch( sub { from_piano_tab($_[0], $piano, 'wn', 'c3', 'V100') } );
$file = 't/piano.mid';
write_score($file);
ok -s $file, 'piano';
