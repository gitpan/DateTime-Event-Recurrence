use strict;

use ExtUtils::MakeMaker;

    WriteMakefile( NAME         => 'DateTime::Event::Recurrence',
                   VERSION_FROM => 'lib/DateTime/Event/Recurrence.pm',
                   AUTHOR       => 'Flavio S. Glock <fglock@pucrs.br>',
                   ABSTRACT     => 'DateTime base recurrences',

                   PREREQ_PM    => { 'DateTime' => 0,
                                     'DateTime::Set' => '0.02',
                                   },
                 );

