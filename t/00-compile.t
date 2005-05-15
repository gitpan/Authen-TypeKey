# $Id: 00-compile.t 27 2004-06-20 12:09:33Z btrott $

my $loaded;
BEGIN { print "1..1\n" }
use Authen::TypeKey;
$loaded++;
print "ok 1\n";
END { print "not ok 1\n" unless $loaded }
