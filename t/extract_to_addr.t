use strict;
use warnings;
use autodie;
use utf8;
use open qw/:std :encoding(UTF-8)/;
use Test::More;
use FindBin qw($RealBin);
use File::Spec::Functions qw(updir catfile devnull);
use IPC::Open3;
use JSON::PP;

my $base_dir = catfile($RealBin, updir());
my $tokenizer = catfile($base_dir, 'tokenizer.awk');

sub tokenize {
    my ($mbox) = @_;

    open my $fh_mbox, '<', catfile($RealBin, updir(), 'sample', $mbox);

    my ($fh_in, $fh_out);
    my $pid = open3($fh_in, $fh_out, devnull(),
        '/usr/bin/awk', -f => $tokenizer);

    print {$fh_in} $_ while <$fh_mbox>;
    close $fh_in;
    close $fh_mbox;

    waitpid $pid, 0;
    my $status = $? >> 8;

    my $token = do { local $/; <$fh_out> };
    close $fh_out;

    open my $fh, '-|', '/bin/sh',
        -c => q{eval "set -- $1";}
            . qq{$^X -MJSON::PP -le }
            . q{'print encode_json([@ARGV]);' -- "$@";},
        '--', $token;

    my $json = do { local $/; <$fh> };
    return $status, decode_json($json);
}

my %tests = (
    'rfc5322_appendix_a_1_1.mbox' => [qw(
        mary@example.net
    )],
    'rfc5322_appendix_a_1_2.mbox' => [qw(
        mary@x.test
        jdoe@example.org
        one@y.test
    )],
    'rfc5322_appendix_a_1_3.mbox' => [qw(
        c@a.test
        joe@where.test
        jdoe@one.test
    )],
    'rfc5322_appendix_a_2.mbox' => [qw(
        smith@home.example
    )],
    'rfc5322_appendix_a_3.mbox' => [qw(
        mary@example.net
    )],
    'rfc5322_appendix_a_4.mbox' => [qw(
        mary@example.net
    )],
    'rfc5322_appendix_a_5.mbox' => [qw(
        c@public.example
        joe@example.org
        jdoe@one.test
    )],
    'rfc5322_appendix_a_6_1.mbox' => undef(),
    'rfc5322_appendix_a_6_2.mbox' => undef(),
    'rfc5322_appendix_a_6_3.mbox' => undef(),
);

for my $file (keys %tests) {
    subtest $file => sub {
        my $expect = shift;
        my ($status, $token) = tokenize($file);

        my @tok = @{$token};
        my @addrs;
        my $header = q{};
        while (@tok) {
            my $k = shift @tok;
            my $v = shift @tok;

            if ($k eq 'field-name') {
                $header = $v;
                next;
            }

            if ($header eq 'To') {
                if ($k eq 'addr-spec') {
                    push @addrs, $v;
                }
            }
        }

        is $status, (defined $expect ? 0 : 1), "$file status";
        if (defined $expect) {
            is_deeply \@addrs, $expect, "$file to addrs";
        }
    }, $tests{$file};
}

done_testing;
