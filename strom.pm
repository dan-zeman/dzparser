#!/usr/bin/perl
# Funkce pro práci se závislostním stromem.
# (c) 2007 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
package strom;



#------------------------------------------------------------------------------
# Postaví strom podle vybraného zdroje anotací. Z vybraného zdroje si přečte
# číselné odkazy na rodiče a do cílových atributů uloží perlové odkazy
# (reference) na rodiče a děti.
#------------------------------------------------------------------------------
sub postavit
{
    my $anot = shift; # odkaz na větu (pole hashů s atributy slov)
    my $zdroj = shift;
    my $rodic = shift;
    my $deti = shift;
    # Zdroj je klíč, pod kterým se skrývá číselný index rodiče uzlu.
    if($zdroj eq "")
    {
        $zdroj = "rodic_vzor";
    }
    # Rodic je klíč, pod kterým má být uložen odkaz na hash s atributy rodiče.
    if($rodic eq "")
    {
        $rodic = "parent";
    }
    # Deti je klíč, pod kterým má být uložen odkaz na pole odkazů na hashe s atributy dětí.
    # Pole se má udržovat uspořádané vzestupně podle pořadí dětí ve větě.
    if($deti eq "")
    {
        $deti = "children";
    }
    # Projít větu zleva doprava.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        $anot->[$i]{$rodic} = $anot->[$anot->[$i]{$zdroj}];
        push(@{$anot->[$i]{$rodic}{$deti}}, $anot->[$i]);
    }
    return $anot;
}



1;
