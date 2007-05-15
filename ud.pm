#!/usr/bin/perl
# Nízkoúrovňové funkce pro ukládání událostí s alternativami.
# (c) 2007 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

package ud;



#------------------------------------------------------------------------------
# Převede událost s alternativami na pole událostí bez alternativ. Pole
# obsahuje všechny kombinace alternativ. V původní události mají zvláštný
# význam znaky " " (mezera - odděluje části události, které mohou mít
# alternativy) a "|" (svislítko - odděluje alternativy uvnitř části).
#------------------------------------------------------------------------------
sub alt
{
    my $ud = shift; # událost s alternativami
    my @alt; # seznam alternativních událostí
    # Jestliže je zpracování alternativ v konfiguraci vypnuté, pouze vrátit událost.
    unless($main::konfig{alternativy})
    {
        push(@alt, $ud);
        return \@alt;
    }
    # Rozdělit alternativy do samostatných událostí.
    # Rozdělit událost na části, které mohou být každá zvlášť rozdělené na alternativy.
    # Části jsou oddělené mezerami. Pozor, tentokrát nemůžeme za oddělovač považovat
    # posloupnost mezer nebo tabulátor, protože po opětovném slepení by nám vyšla jiná
    # událost, která by se v hashi nenašla.
    my @casti = split(/ /, $ud);
    my @dilky;
    for(my $i = 0; $i<=$#casti; $i++)
    {
        # Rozdělit část na alternativy.
        my @altcasti = split(/\|/, $casti[$i]);
        # Nechceme prázdné pole. I prádzná část má jednu prázdnou alternativu.
        if(!scalar(@altcasti))
        {
            $altcasti[0] = "";
        }
        for(my $j = 0; $j<=$#altcasti; $j++)
        {
            $dilky[$i][$j] = $altcasti[$j];
        }
    }
    # Sestavit z dílků všechny kombinace.
    my @cesty = (""); # Pole má jeden prvek, a tím je prázdná cesta.
    for(my $i = 0; $i<=$#dilky; $i++)
    {
        my @nove_cesty;
        for(my $j = 0; $j<=$#{$dilky[$i]}; $j++)
        {
            for(my $k = 0; $k<=$#cesty; $k++)
            {
                my @kopie_cesty = @{$cesty[$k]};
                push(@kopie_cesty, $dilky[$i][$j]);
                push(@nove_cesty, \@kopie_cesty);
            }
        }
        @cesty = @nove_cesty;
    }
    # Poslepovat cesty do alternativních událostí.
    foreach my $cesta (@cesty)
    {
        push(@alt, join(" ", @{$cesta}));
    }
    return \@alt;
}



#------------------------------------------------------------------------------
# Zjistí četnost události.
#------------------------------------------------------------------------------
sub zjistit
{
    my $ud = shift; # událost, jejíž četnost chceme znát
    my $statref = shift; # odkaz na hash, v němž se má hledat
    # Jestliže volající nedodal statistický model, použít globální proměnnou.
    if(!$statref)
    {
        $statref = \%main::stat;
    }
    # Rozdělit událost na alternativy.
    my $alts = alt($ud);
    # Sečíst výskyty jednotlivých dílčích událostí.
    my $n;
    foreach my $alt (@{$alts})
    {
        $n += $statref->{$alt};
    }
    return $n;
}



#------------------------------------------------------------------------------
# Uloží výskyt události.
#------------------------------------------------------------------------------
sub ulozit
{
    my $ud = shift; # událost, jejíž četnost chceme zvýšit
    my $n = shift; # počet výskytů, o který chceme zvýšit četnost
    my $statref = shift; # odkaz na hash, do nějž se četnosti ukládají
    # Jestliže volající nedodal statistický model, použít globální proměnnou.
    if(!$statref)
    {
        $statref = \%main::stat;
    }
    $n = 1 if($n eq "");
    # Rozdělit událost na alternativy.
    my $alts = alt($ud);
    # Každé dílčí události započítat poměrnou část výskytu.
    my $dil = $n/scalar(@{$alts});
    foreach my $alt (@{$alts})
    {
        $statref->{$alt} += $dil;
    }
}



1;
