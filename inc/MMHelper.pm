package MMHelper;

use Devel::CallChecker;

my $callchecker_h = 'callchecker0.h';

sub mm_args {
    return (
        clean => { FILES => join q{ } => $callchecker_h },
        OBJECT => join(q{ },
                       '$(BASEEXT)$(OBJ_EXT)',
                       Devel::CallChecker::callchecker_linkable),
    );
}

sub header_generator {
    return <<"EOC";
use Devel::CallChecker;
use IO::File;

write_header('${callchecker_h}', Devel::CallChecker::callchecker0_h);

sub write_header {
    my (\$header, \$content) = \@_;
    my \$fh = IO::File->new(\$header, 'w') or die \$!;
    \$fh->print(\$content) or die \$!;
    \$fh->close or die \$!;
}

1;
EOC
}
