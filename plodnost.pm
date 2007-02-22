# Modul s funkcemi umožňujícími využít při parsingu model n-tic vedle sebe ležících slov.
package plodnost;
use utf8;
use vystupy;



#------------------------------------------------------------------------------
# Učení plodnosti. Projde větu, zjistí počet dětí jednotlivých uzlů, vygeneruje
# příslušné události a zapíše je do centrální evidence.
#------------------------------------------------------------------------------
sub ucit
{
    my $anot = shift; # odkaz na pole hashů s anotacemi slov
    my @n_deti;# = map{0}(0..$#{$anot});
    # Zjistit, kolik má který uzel dětí.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        my $rodic = $anot->[$i]{rodic_vzor};
        if($rodic>=0) # může to být i -1
        {
            $n_deti[$rodic]++;
        }
    }
    # Projít nasčítané počty dětí a uložit výskyt každého případu.
    for(my $i = 0; $i<=$#n_deti; $i++)
    {
        my $udalost = "ZPL ".$anot->[$i]{uznacka}." ".$n_deti[$i];
        # Kontrola podezřelých událostí.
        if($udalost eq "ZPL Z?K 1")
        {
            print(join(" ", map{$_->{slovo}."/".$_->{uznacka}."/".$_->{rodic_vzor}}(@{$anot})), "\n");
            print(join(" ", @n_deti), "\n");
            die;
        }
        # Zavolat ud() v hlavním modulu, předpokládáme, že je to train.pl.
        # Nemůžeme přistupovat přímo do hashe, protože {uznacka} by ve skutečnosti
        # mohl být seznam značek ud() to vyřeší. Lepší by bylo přesunout ud()
        # do samostatného modulu, ale pozor, trénovací ud() není totéž co ud()
        # pro parsing!
        main::ud($udalost);
    }
}



#------------------------------------------------------------------------------
# Načte naučené plodnosti značek. Vzhledem k tomu, že učení probíhalo v rámci
# standardního tréninku, mohli bychom k plodnostem přistupovat do standardní
# statistiky, ale tady je máme trochu předžvýkané a jsou v nich zahrnuty pouze
# značky, které dávají přednost určitému počtu dětí alespoň v 50 %.
#------------------------------------------------------------------------------
sub cist
{
    open(PLODNOST, "plodnost.txt") or die("Nelze otevrit plodnost: $!\n");
    binmode(PLODNOST, ":encoding(iso-8859-2)");
    while(<PLODNOST>)
    {
        if(m/^(\S+) (\d+) (\S+)/ && $3>0.5)
        {
            $plodnost{$1}{nd} = $2;
            $plodnost{$1}{p} = $3;
        }
    }
    close(PLODNOST);
}



#------------------------------------------------------------------------------
# Projde všechny události typu ZPL v centrální statistice. Sestaví z nich
# tabulku, která pro každou m-značku a daný počet dětí řekne, jaká je pravdě-
# podobnost, že uzel, který má tuto m-značku a byl mu již dán dotyčný počet
# dětí, dostane ještě další dítě.
#------------------------------------------------------------------------------
sub pripravit_ffm
{
    my $stat = shift; # odkaz na hash s centrální statistikou
    # Najít v centrální evidenci příslušné události.
    my %plodnost;
    while(my ($udalost, $pocet) = each(%{$stat}))
    {
        if($udalost =~ m/^ZPL (\S+) (\d+)/)
        {
            my $znacka = $1;
            my $ndeti = $2;
            $ndeti = 3 if($ndeti>3);
            $plodnost{$znacka}[$ndeti] += $pocet;
        }
    }
    # Projít jednotlivé značky a sestavit si pro ně tabulky.
    while(my ($znacka, $plodnost) = each(%plodnost))
    {
        # Zjistit celkový počet výskytů značky.
        my $n_vyskytu;
        for(my $i = 0; $i<=$#{$plodnost}; $i++)
        {
            $n_vyskytu += $plodnost->[$i];
        }
        # Vypočítat pravděpodobnost pro každé zvýšení počtu dětí.
        for(my $i = 0; $i<=3; $i++)
        {
            # Zjistit četnosti vyššího než aktuálního počtu dětí.
            my $n_vyssi;
            for(my $j = $i+1; $j<=3; $j++)
            {
                $n_vyssi += $plodnost->[$j];
            }
            my $jmenovatel = $n_vyssi+$plodnost->[$i];
            $xxx{$znacka}[$i] = $jmenovatel ? $n_vyssi/$jmenovatel : 0.5;
        }
    }
}



#------------------------------------------------------------------------------
# Ohodnotí pravděpodobnost, že uzel, který má nyní n dětí jich má mít více než
# n. Výsledek je číslo z uzavřeného intervalu <0;1>.
#------------------------------------------------------------------------------
sub ohodnotit
{
    my $znacka = shift;
    my $dosn = shift; # dosavadní počet dětí
    my $konfig = \%main::konfig;
    if($konfig->{plodnost_model} eq "ffm")
    {
        if($dosn>=3)
        {
            return 0.5;
        }
        else
        {
            return $xxx{$znacka}[$dosn];
        }
    }
    else # tfm nebo qfm
    {
        # Jestliže značka nedává jasnou přednost určitému počtu dětí, vrátit 0.5.
        if($plodnost{$znacka}{p}<0.8)
        {
            if($konfig->{plodnost_model} eq "tfm")
            {
                return 0.5;
            }
            else # qfm
            {
                return 1;
            }
        }
        # Jestliže už byl dosažen nebo překročen upřednostňovaný počet, vrátit 0.
        if($dosn>=$plodnost{$znacka}{nd})
        {
            return 0;
        }
        # Jestliže upřednostňovaný počet ještě nebyl dosažen, vrátit 1.
        # (Nikdy není takto silně (80%) upřednostňován počet 3 nebo vyšší, takže
        # nemusíme mít strach, že nějakému uzlu schválíme neomezený počet dětí.)
        return 1;
    }
}



1;
