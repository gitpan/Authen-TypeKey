# $Id: 01-verify.t,v 1.3 2004/06/20 12:09:33 btrott Exp $

use Test;
use Authen::TypeKey;

BEGIN { plan tests => 17 }

my $q = My::Query->new({
    ts => '1087419162',
    email => 'bentwo@stupidfool.org',
    name => 'Melody',
    nick => 'foobar baz',
    sig => 'BoNGFN8Bi9t9GEYVbZ2PKWg6iqI=:X9MAGdqWtTrKT5OGMiM8TWoaQfo=',
});

my $tk = Authen::TypeKey->new;
ok($tk);

my $res = $tk->verify($q);
ok(!$res);
ok($tk->errstr =~ /expired/);

$tk->skip_expiry_check(1);
$res = $tk->verify($q);
ok($res);
ok($res->{ts}, $q->param('ts'));
ok($res->{email}, $q->param('email'));
ok($res->{name}, $q->param('name'));
ok($res->{nick}, $q->param('nick'));

$tk->skip_expiry_check(0);
$tk->expires(-1);
$res = $tk->verify($q);
ok(!$res);
ok($tk->errstr =~ /expired/);

$tk->expires(time);
$res = $tk->verify($q);
ok($res);
ok($res->{ts}, $q->param('ts'));
ok($res->{email}, $q->param('email'));
ok($res->{name}, $q->param('name'));
ok($res->{nick}, $q->param('nick'));

$tk->key_url('http://www.example.com/nothing-there');
$res = $tk->verify($q);
ok(!$res);
ok($tk->errstr =~ /failed to fetch key/i);

package My::Query;
sub new { bless $_[1], $_[0] }
sub param { $_[0]{$_[1]} }
