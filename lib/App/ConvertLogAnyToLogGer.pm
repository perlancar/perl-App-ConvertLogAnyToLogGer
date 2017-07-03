package App::ConvertLogAnyToLogGer;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use PPI;

our %SPEC;

my %log_statements = (
    trace => "trace",
    debug => "debug",
    info => "info",
    warn => "warn",
    warning => "warn",
    error => "error",
    fatal => "fatal",
);

$SPEC{convert_log_any_to_log_ger} = {
    v => 1.1,
    summary => 'Convert code that uses Log::Any to use Log::ger',
    description => <<'_',

This is a tool to help converting code that uses <pm:Log::Any> to use
<pm:Log::ger>. It converts:

    use Log::Any;
    use Log::Any '$log';

to:

    use Log::ger;

It converts:

    $log->warn("blah");
    $log->warn("blah", "more blah");

to:

    log_warn("blah");
    log_warn("blah", "more blah"); # XXX this does not work and needs to be converted to e.g. log_warn(join(" ", "blah", "more blah"));

It converts:

    $log->warnf("blah %s", $arg);

to:

    log_warn("blah %s", $arg);

It converts:

    $log->is_warn

to:

    log_is_warn()

_
    args => {
        input => {
            schema => 'str*',
            req => 1,
            pos => 0,
            cmdline_src => 'stdin_or_files',
        },
    },
};
sub convert_log_any_to_log_ger {
    my %args = @_;

    my $doc = PPI::Document->new(\$args{input});
    my $res = $doc->find(
        sub {
            my ($top, $el) = @_;

            my $match;
            if ($el->isa('PPI::Statement::Include')) {
                # matching 'use Log::Any' or "use Log::Any '$log'"
                my $c0 = $el->child(0);
                if ($c0->content eq 'use') {
                    my $c1 = $c0->next_sibling;
                    if ($c1->content eq ' ') {
                        my $c2 = $c1->next_sibling;
                        if ($c2->content =~ /\A(Log::Any::IfLOG|Log::Any)\z/) {
                            $c2->insert_before(PPI::Token::Word->new("Log::ger"));
                            my $remove_cs;
                            my $cs = $c2;
                            while (1) {
                                $cs = $cs->next_sibling;
                                $remove_cs->remove if $remove_cs;
                                last unless $cs;
                                last if $cs->isa("PPI::Token::Structure") && $cs->content eq ';';
                                $remove_cs = $cs;
                            }
                            $c2->remove;
                        }
                    }
                }
            }

            if ($el->isa('PPI::Statement')) {
                # matching '$log->trace(...);' or '$log->tracef(...);'
                my $c0 = $el->child(0);
                if ($c0->content eq '$log') {
                    my $c1 = $c0->snext_sibling;
                    if ($c1->content eq '->') {
                        my $c2 = $c1->snext_sibling;
                        my $c2c = $c2->content;
                        if (grep { $c2c eq $_ } keys %log_statements) {
                            my $func = "log_".$log_statements{$c2c};
                            # insert "log_trace"
                            $c0->insert_after(PPI::Token::Word->new($func));
                            $c0->remove(); # remove $log
                            $c1->remove; # remove '->'
                            $c2->remove; # remove 'trace'
                        } elsif (grep { $c2c eq "${_}f" } keys %log_statements) {
                            (my $key = $c2c) =~ s/f$//;
                            my $func = "log_".$log_statements{$key};
                            # insert "log_trace"
                            $c0->insert_after(PPI::Token::Word->new($func));
                            $c0->remove(); # remove $log
                            $c1->remove; # remove '->'
                            $c2->remove; # remove 'tracef'
                        } else {
                            warn "Unreplaced: \$log->$c2c in line ".
                                $el->line_number."\n";
                        }
                    }
                }
            }

            if ($el->isa('PPI::Statement::Compound')) {
                # matching 'if ($log->is_trace) { ... }'
                my $c0 = $el->child(0);
                if ($c0->content eq 'if') {
                    my $cond = $c0->snext_sibling;
                    if ($cond->isa('PPI::Structure::Condition')) {
                        my $expr = $cond->child(0);
                        if ($expr->isa('PPI::Statement::Expression')) {
                            my $c0 = $expr->child(0);
                            if ($c0->content eq '$log') {
                                my $c1 = $c0->snext_sibling;
                                if ($c1->content eq '->') {
                                    my $c2 = $c1->snext_sibling;
                                    my $c2c = $c2->content;
                                    if (grep { $c2c eq "is_$_" } keys %log_statements) {
                                        (my $key = $c2c) =~ s/^is_//;
                                        my $func = "log_is_".$log_statements{$key};
                                        # insert "log_is_trace"
                                        $c0->insert_after(PPI::Token::Word->new($func));
                                        $c0->remove(); # remove $log
                                        $c1->remove; # remove '->'
                                        $c2->remove; # remove 'is_trace'
                                    }
                                }
                            }
                        }
                    }
                }
            }

            0;
        }
    );
    die "BUG: find() dies: $@!" unless defined($res);

    [200, "OK", $doc->serialize];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

See the included script L<convert-log-any-to-log-ger>.


=head1 SEE ALSO

L<Log::ger>

L<Log::Any>

=cut
