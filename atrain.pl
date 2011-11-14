#!/usr/bin/perl
# Čte CSTS a učí se vztah mezi morfologickými značkami rodiče a dítěte a syntaktickou značkou.
# (c) 2007 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use csts;

csts::projit_data("-", \%konfig, \&zpracovat_vetu);
# U každé dvojice nahradit pole možností s četnostmi tou nejčetnější možností.
my @klice = sort(keys(%stat));
foreach my $klic (@klice)
{
    my @klice2 = sort{$stat{$klic}{$b}<=>$stat{$klic}{$a}}(keys(%{$stat{$klic}}));
    my $odpoved = $klice2[0];
    # Kvůli uložení nahradit v klíči i v odpovědi všechny tabulátory něčím jiným.
    $klic =~ s/[\t\r\n]+/ /sg;
    $odpoved =~ s/[\t\r\n]+/ /sg;
    # Uložit statistiku.
    print("$klic\t$odpoved\n");
}



#------------------------------------------------------------------------------
# Zpracuje poslední přečtenou větu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a větě
    my $anot = shift; # pole hashů o jednotlivých slovech
    # Projít větu po slovech.
    foreach my $slovo (@{$anot})
    {
        # Zjistit morfologickou značku slova, morfologickou značku jeho rodiče a syntaktickou značku slova.
        my $klic = "$slovo->{znacka} $anot->[$slovo->{rodic_vzor}]{znacka}";
        my $klic2 = $slovo->{afun};
        $stat{$klic}{$klic2}++;
        $stat{$slovo->{znacka}}{$klic2}++;
        $stat{""}{$klic2}++;
    }
}
