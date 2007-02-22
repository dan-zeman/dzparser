# Modul s funkcemi umo¾òujícími vyu¾ít pøi parsingu model n-tic vedle sebe le¾ících slov.
package plodnost;
require 5.000;
require Exporter;
use vystupy;



#------------------------------------------------------------------------------
# Uèení plodnosti. Projde vìtu, zjistí poèet dìtí jednotlivých uzlù, vygeneruje
# pøíslu¹né události a zapí¹e je do centrální evidence.
#------------------------------------------------------------------------------
sub ucit
{
    my $anot = shift; # odkaz na pole hashù s anotacemi slov
    my @n_deti;# = map{0}(0..$#{$anot});
    # Zjistit, kolik má který uzel dìtí.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        my $rodic = $anot->[$i]{rodic_vzor};
        if($rodic>=0) # mù¾e to být i -1
        {
            $n_deti[$rodic]++;
        }
    }
    # Projít nasèítané poèty dìtí a ulo¾it výskyt ka¾dého pøípadu.
    for(my $i = 0; $i<=$#n_deti; $i++)
    {
        my $udalost = "ZPL ".$anot->[$i]{uznacka}." ".$n_deti[$i];
        # Kontrola podezøelých událostí.
        if($udalost eq "ZPL Z?K 1")
        {
            print(join(" ", map{$_->{slovo}."/".$_->{uznacka}."/".$_->{rodic_vzor}}(@{$anot})), "\n");
            print(join(" ", @n_deti), "\n");
            die;
        }
        # Zavolat ud() v hlavním modulu, pøedpokládáme, ¾e je to train.pl.
        # Nemù¾eme pøistupovat pøímo do hashe, proto¾e {uznacka} by ve skuteènosti
        # mohl být seznam znaèek ud() to vyøe¹í. Lep¹í by bylo pøesunout ud()
        # do samostatného modulu, ale pozor, trénovací ud() není toté¾ co ud()
        # pro parsing!
        main::ud($udalost);
    }
}



#------------------------------------------------------------------------------
# Naète nauèené plodnosti znaèek. Vzhledem k tomu, ¾e uèení probíhalo v rámci
# standardního tréninku, mohli bychom k plodnostem pøistupovat do standardní
# statistiky, ale tady je máme trochu pøed¾výkané a jsou v nich zahrnuty pouze
# znaèky, které dávají pøednost urèitému poètu dìtí alespoò v 50 %.
#------------------------------------------------------------------------------
sub cist
{
    open(PLODNOST, "plodnost.txt") or die("Nelze otevrit plodnost: $!\n");
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
# Projde v¹echny události typu ZPL v centrální statistice. Sestaví z nich
# tabulku, která pro ka¾dou m-znaèku a daný poèet dìtí øekne, jaká je pravdì-
# podobnost, ¾e uzel, který má tuto m-znaèku a byl mu ji¾ dán dotyèný poèet
# dìtí, dostane je¹tì dal¹í dítì.
#------------------------------------------------------------------------------
sub pripravit_ffm
{
    my $stat = shift; # odkaz na hash s centrální statistikou
    # Najít v centrální evidenci pøíslu¹né události.
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
    # Projít jednotlivé znaèky a sestavit si pro nì tabulky.
    while(my ($znacka, $plodnost) = each(%plodnost))
    {
        # Zjistit celkový poèet výskytù znaèky.
        my $n_vyskytu;
        for(my $i = 0; $i<=$#{$plodnost}; $i++)
        {
            $n_vyskytu += $plodnost->[$i];
        }
        # Vypoèítat pravdìpodobnost pro ka¾dé zvý¹ení poètu dìtí.
        for(my $i = 0; $i<=3; $i++)
        {
            # Zjistit èetnosti vy¹¹ího ne¾ aktuálního poètu dìtí.
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
# Ohodnotí pravdìpodobnost, ¾e uzel, který má nyní n dìtí jich má mít více ne¾
# n. Výsledek je èíslo z uzavøeného intervalu <0;1>.
#------------------------------------------------------------------------------
sub ohodnotit
{
    my $znacka = shift;
    my $dosn = shift; # dosavadní poèet dìtí
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
        # Jestli¾e znaèka nedává jasnou pøednost urèitému poètu dìtí, vrátit 0.5.
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
        # Jestli¾e u¾ byl dosa¾en nebo pøekroèen upøednostòovaný poèet, vrátit 0.
        if($dosn>=$plodnost{$znacka}{nd})
        {
            return 0;
        }
        # Jestli¾e upøednostòovaný poèet je¹tì nebyl dosa¾en, vrátit 1.
        # (Nikdy není takto silnì (80%) upøednostòován poèet 3 nebo vy¹¹í, tak¾e
        # nemusíme mít strach, ¾e nìjakému uzlu schválíme neomezený poèet dìtí.)
        return 1;
    }
}



1;
