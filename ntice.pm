# Modul s funkcemi umo¾òujícími vyu¾ít pøi parsingu model n-tic vedle sebe le¾ících slov.
package ntice;
require 5.000;
require Exporter;
use vystupy;



#------------------------------------------------------------------------------
# Uèení n-tic. Projde v¹echny n-tice po sobì jdoucích slov ve vìtì, zjistí
# jejich morfologický vzor a zapamatuje si jejich syntaktickou strukturu.
#------------------------------------------------------------------------------
sub ucit
{
    my $n = shift; # jak velké n-tice se mají hledat
    # Zatím globální promìnné.
    my $anot = \@main::anot;
    # Pozdìji by to mohlo jít zobecnit na trojice slo¾ek, které se ocitly vedle
    # sebe v prùbìhu analýzy. (Pøi tréninku znamená "vedle sebe" dìti jednoho rodièe. V¹echny dìti?)
    # Pozor. První nástøel poèítal s trojicemi po sobì jdoucích slov, které v¹ak mohly mít i dvoupatrovou strukturu.
    # Druhý nápad poèítá s trojicemi (n-ticemi) slov, která nemusejí ve vìtì le¾et vedle sebe, ale zase to musejí být
    # dìti jednoho rodièe, tj. struktura je v¾dy jednopatrová. Obecný DOP model by uvolnil obojí, tj. jak vzdálenost
    # slov, tak hloubku struktury. Zatím ale nevím, zda a jak je realizovatelný.
    for(my $i = 0; $i<=$#{$anot}-$n+1; $i++)
    {
        # Získat morfologický a syntaktický vzorec n-tice.
        # Morfologickým myslím posloupnost upravených znaèek, syntaktickým posloupnost indexù rodièù.
        # U syntaktických je indexem "X", pokud závislost vede ven z n-tice, a také pokud uzel "visí"
        # sám na sobì (nemìlo by se stát jinde ne¾ u koøene, tj. uzlu s indexem 0).
        my @mvzor = map{$_->{uznacka}}(@{$anot}[$i..$i+$n-1]);
        my @svzor;
        # Spoèítat závislosti, které vedou ze skupiny ven.
        my $ven;
        for(my $j = 0; $j<$n; $j++)
        {
            my $r = $anot->[$i+$j]{rodic_vzor};
            if($r<$i || $r>$i+$n-1 || $r==$i+$j)
            {
                $svzor[$j] = "X";
                $ven++;
            }
            else
            {
                $svzor[$j] = $r-$i;
            }
        }
        my $mvzor = join(" ", @mvzor);
        my $svzor;
        # Jestli¾e ven vede více ne¾ jedna závislost, skupina je roztr¾ená a asi nemá smysl se pokou¹et
        # nìkdy ji rekonstruovat. I tak si ale musíme zapamatovat výskyt mvzoru, proto¾e nám sní¾í váhu
        # tìch výskytù, pøi nich¾ skupina roztr¾ená nebyla.
        if($ven>1)
        {
            $svzor = join(",", map{"X"}[0..$n-1]);
        }
        else
        {
            $svzor = join(",", @svzor);
        }
        # Promìnné globální v rámci tohoto modulu: %ntice a %priklady.
        # Zapamatovat si výskyt dané dvojice vzorù.
        $ntice{$mvzor}{$svzor}++;
        # Jestli¾e neznáme pøíklad, zapamatovat si také pøíklad.
        unless(exists($priklady{$mvzor}))
        {
            $priklady{$mvzor} = join(" ", @{$anot}[$i..$i+$n-1]);
        }
    }
}



#------------------------------------------------------------------------------
# Ulo¾í nauèené vzory n-tic morfologických znaèek.
#------------------------------------------------------------------------------
sub vypsat
{
    my @mvzory = sort(keys(%ntice));
    print STDERR ("Mame ", $#mvzory+1, " mvzoru.\n");
    for(my $i = 0; $i<=$#mvzory; $i++)
    {
        # Seøadit øe¹ení sestupnì podle èetnosti.
        my $svzhsh = $ntice{$mvzory[$i]};
        my @svzory = sort{$svzhsh->{$b}<=>$svzhsh->{$a}}(keys(%{$svzhsh}));
        # Zjistit celkový poèet výskytù n-tice. Øídkým n-ticím radìji nevìøit.
        # Souèasnì zjistit, zda jeden názor na øe¹ení dostateènì pøeva¾uje a
        # zda pøeva¾ující "øe¹ení" není pøípad, kdy byla n-tice roztr¾ena.
        my $celkem;
        my $max;
        my $jmax;
        for(my $j = 0; $j<=$#svzory; $j++)
        {
            my $tento = $svzhsh->{$svzory[$j]};
            $celkem += $tento;
            if($max eq "" || $tento>$max)
            {
                $max = $tento;
                $jmax = $j;
            }
        }
        next if($celkem<5 || $max/$celkem<0.9 || $svzory[$jmax] !~ m/\d/);
        # Jestli¾e n-tice pro¹la filtrem, ulo¾it si její výstup. Na konci výstupy seøadíme a vypí¹eme.
        my $vystup = "MVZOR $mvzory[$i]\t\t\t($priklady{$mvzory[$i]})\n";
        for(my $j = 0; $j<=$#svzory; $j++)
        {
            $vystup .= sprintf("    SVZOR %s\t%4d\t%3d %%\n", $svzory[$j], $svzhsh->{$svzory[$j]}, $svzhsh->{$svzory[$j]}*100/$celkem);
        }
        my %zaznam;
        $zaznam{vystup} = $vystup;
        $zaznam{vyznam} = $max;
        push(@vystupy, \%zaznam);
    }
    print STDERR ("Pro vystup zbylo ", $#vystupy+1, " vzoru.\n");
    # Seøadit a vypsat záznamy.
    @vystupy = sort{$a->{vyznam}<=>$b->{vyznam}}(@vystupy);
    for(my $i = 0; $i<=$#vystupy; $i++)
    {
        vystupy::vypsat("ntice", $vystupy[$i]{vystup});
    }
}



#------------------------------------------------------------------------------
# Naète nauèené vzory n-tic morfologických znaèek.
#------------------------------------------------------------------------------
sub cist
{
    my $soubor = shift;
    # 8.3.2004: Ignoruje se jméno souboru dodané volajícím. Místo toho se
    # postupnì ètou soubory 2ice.txt a¾ 10ice.txt v aktuální slo¾ce.
    my %ntice;
    for(my $i = 2; $i<=10; $i++)
    {
        $soubor = $i."ice.txt";
    open(NTICE, $soubor) or die("Nelze otevøít soubor $soubor: $!\n");
    my $mvzor;
    while(<NTICE>)
    {
        if(m/^MVZOR (.*?)\t/)
        {
        $mvzor = $1;
        }
        elsif(m/SVZOR (.*?)\t/)
        {
        $ntice{$mvzor} = $1;
        # Zajistit, aby se k mvzoru zapsalo pouze první (nejlep¹í) øe¹ení: ostatní pøesmìrovat do kanálu.
        $mvzor = "";
        }
    }
    close(NTICE);
    }
    return \%ntice;
}



#------------------------------------------------------------------------------
# Pokusí se na vìtu aplikovat vzory n-tic. Vrátí èásteènì rozebranou vìtu.
# (Pøedpokládá, ¾e byla nasazena pøed v¹emi ostatními nástroji, tj. ¾e ¾ádná
# èást vìty je¹tì rozebraná není.)
#------------------------------------------------------------------------------
sub nasadit
{
    my $ntice = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashù s anotacemi jednotlivých slov
    my @rodice; # výstupní pole
    my @mzn = map{$_->{uznacka}}(@{$anot});
    # Pøednost vzorù pøi konfliktu: zatím ten, který se ve vìtì najde první (tj. nejdel¹í vzor, a nebo, pokud jsou stejnì dlouhé, vzor nejvíc vlevo).
    ### Mìlo by to být spí¹ tak, ¾e nejúspì¹nìj¹í pravidlo má nejvìt¹í pøednost!
    ### Nebo by se od n-tic mìlo upustit tam, kde jsou v konfliktu.
    for(my $n = 10; $n>=2; $n--)
    {
    for(my $i = 0; $i<=$#mzn-2; $i++)
    {
        my $mvzor = join(" ", @mzn[$i..$i+$n-1]);
        next if(!exists($ntice->{$mvzor}));
        my @svzor = split(",", $ntice->{$mvzor});
        # Ulo¾it nalezené øe¹ení do seznamu rodièù.
        for(my $j = 0; $j<=$#svzor; $j++)
        {
        unless($svzor[$j] eq "X")
        {
            # Zapamatovat si konflikty mezi pøekrývajícími se n-ticemi.
                    if($rodice[$i+$j] ne "" && $rodice[$i+$j]!=$i+$svzor[$j])
            {
            $main::ntice_konflikty++;
            }
            else
            {
            $rodice[$i+$j] = $i+$svzor[$j];
            }
        }
        }
    }
    }
    return \@rodice;
}



#------------------------------------------------------------------------------
# Porovná vzorovou, úplnou a èásteènou analýzu té¾e vìty. Pøedpokládá, ¾e
# úplná analýza je "pùvodní" bez n-tic, zatímco èásteèná je "nová", s n-ticemi.
# Tam, kde se èásteèná analýza uplatnila, zjistí, zda jde o zlep¹ení apod.
#------------------------------------------------------------------------------
sub zhodnotit
{
    my $vzor = shift; # odkaz na vzorové pole indexù rodièù
    my $ntc0 = shift; # odkaz na pole indexù rodièù dodané pùvodním parserem
    my $ntc1 = shift; # odkaz na pole indexù rodièù dodané novým parserem
    my $ntc = shift; # odkaz na pole indexù rodièù podle n-tic umo¾òuje poznat, kde n-tice pøímo zasáhly
    for(my $i = 0; $i<=$#{$ntc1}; $i++)
    {
        if($ntc->[$i] ne "")
        {
            $main::ntice_celkem++;
            my $dobre0 = $ntc0->[$i]==$vzor->[$i];
            my $dobre1 = $ntc1->[$i]==$vzor->[$i];
            my $stejne = $ntc1->[$i]==$ntc0->[$i];
            if(!$dobre1 && 0)
            {
                my $anot = \@main::anot;
                print("\n");
                for(my $j = 0; $j<=$#{$anot}; $j++)
                {
                    print("$j:$anot->[$j]{slovo} ");
                }
                print("\n");
                print("i=$i, vzor=$vzor->[$i], ntc0=$ntc0->[$i], ntc1=$ntc1->[$i]\n");
            }
            if($dobre0)
            {
                if($dobre1)
                {
                    $main::ntice_dobre++;
                }
                else
                {
                    $main::ntice_horsi++;
                }
            }
            else
            {
                if($dobre1)
                {
                    $main::ntice_lepsi++;
                }
                elsif($stejne)
                {
                    $main::ntice_stejne_spatne++;
                }
                else
                {
                    $main::ntice_ruzne_spatne++;
                }
            }
        }
        # Tento uzel nebyl zavì¹en podle modelu n-tic, ale jeho zavì¹ení mohlo být ovlivnìno
        # novou situací, která po èásteèném rozboru vìty pomocí n-tic nastala.
        else
        {
            $main::ntice_neprimo++;
            my $dobre0 = $ntc0->[$i]==$vzor->[$i];
            my $dobre1 = $ntc1->[$i]==$vzor->[$i];
            my $stejne = $ntc1->[$i]==$ntc0->[$i];
            if($dobre0)
            {
                if($dobre1)
                {
                    $main::ntice_neprimo_dobre++;
                }
                else
                {
                    $main::ntice_neprimo_horsi++;
                }
            }
            else
            {
                if($dobre1)
                {
                    $main::ntice_neprimo_lepsi++;
                }
                elsif($stejne)
                {
                    $main::ntice_neprimo_stejne_spatne++;
                }
                else
                {
                    $main::ntice_neprimo_ruzne_spatne++;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Vytvoøí hlá¹ení na základì svých statistik. Nikam ho nevypisuje, jen ho vrátí
# volajícímu. Je na volajícím, aby rozhodl, na který výstup ho po¹le.
#------------------------------------------------------------------------------
sub vytvorit_hlaseni
{
    my $hlaseni = "------- Model n-tic -------\n";
    $hlaseni .= sprintf("%7d   rozhodnutých slov\n", $main::ntice_celkem);
    $hlaseni .= sprintf("%7d   konfliktù mezi pøekrývajícími se n-ticemi\n", $main::ntice_konflikty);
    $hlaseni .= sprintf("%7d   zlep¹ení oproti pùvodnímu modelu\n", $main::ntice_lepsi);
    $hlaseni .= sprintf("%7d   zhor¹ení oproti pùvodnímu modelu\n", $main::ntice_horsi);
    $hlaseni .= sprintf("%7d   stejnì dobrých jako pùvodní model\n", $main::ntice_dobre);
    $hlaseni .= sprintf("%7d   stejnì ¹patných jako pùvodní model\n", $main::ntice_stejne_spatne);
    $hlaseni .= sprintf("%7d   jiných ne¾ pùvodní model, ale také ¹patných\n", $main::ntice_ruzne_spatne);
    $hlaseni .= sprintf("%7d   slov mimo n-tice\n", $main::ntice_neprimo);
    $hlaseni .= sprintf("%7d   nepøímých zlep¹ení oproti pùvodnímu modelu\n", $main::ntice_neprimo_lepsi);
    $hlaseni .= sprintf("%7d   nepøímých zhor¹ení oproti pùvodnímu modelu\n", $main::ntice_neprimo_horsi);
    $hlaseni .= sprintf("%7d   nepøímo stejnì dobrých jako pùvodní model\n", $main::ntice_neprimo_dobre);
    $hlaseni .= sprintf("%7d   nepøímo stejnì ¹patných jako pùvodní model\n", $main::ntice_neprimo_stejne_spatne);
    $hlaseni .= sprintf("%7d   nepøímo jiných ne¾ pùvodní model, ale také ¹patných\n", $main::ntice_neprimo_ruzne_spatne);
    return $hlaseni;
}



1;
