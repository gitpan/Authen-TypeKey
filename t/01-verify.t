# $Id: 01-verify.t 30 2004-07-29 16:09:29Z btrott $

use Test;
use Authen::TypeKey;

BEGIN { plan tests => 19 }

my $q = My::Query->new({
    ts => '1091163746',
    email => 'bentwo@stupidfool.org',
    name => 'Melody',
    nick => 'foobar baz',
    sig => 'GWwAIXbkb2xNrQO2e/r2LDl14ek=:U5+tDsPM0+EXeKzFWsosizG7+VU=',
});

my $tk = Authen::TypeKey->new;
ok($tk);

ok($tk->version, 1.1);

$tk->token('foo');
ok($tk->token, 'foo');

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
