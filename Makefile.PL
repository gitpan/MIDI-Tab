use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'MIDI::Tab',
    VERSION_FROM => 'lib/MIDI/Tab.pm', # finds $VERSION
    AUTHOR       => 'Robert J. Symes (rob@robsymes.com)',
    ABSTRACT     => '',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
