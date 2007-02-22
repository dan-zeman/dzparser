# Modul s funkcemi umožňujícími využít při parsingu model n-tic vedle sebe ležících slov.
package ntice;
use utf8;
use vystupy;



#------------------------------------------------------------------------------
# Učení n-tic. Projde všechny n-tice po sobě jdoucích slov ve větě, zjistí
# jejich morfologický vzor a zapamatuje si jejich syntaktickou strukturu.
#------------------------------------------------------------------------------
sub ucit
{
    my $n = shift; # jak velké n-tice se mají hledat
    my $anot = shift;
    # Později by to mohlo jít zobecnit na trojice složek, které se ocitly vedle
    # sebe v průběhu analýzy. (Při tréninku znamená "vedle sebe" děti jednoho rodiče. Všechny děti?)
    # Pozor. První nástřel počítal s trojicemi po sobě jdoucích slov, které však mohly mít i dvoupatrovou strukturu.
    # Druhý nápad počítá s trojicemi (n-ticemi) slov, která nemusejí ve větě ležet vedle sebe, ale zase to musejí být
    # děti jednoho rodiče, tj. struktura je vždy jednopatrová. Obecný DOP model by uvolnil obojí, tj. jak vzdálenost
    # slov, tak hloubku struktury. Zatím ale nevím, zda a jak je realizovatelný.
    for(my $i = 0; $i<=$#{$anot}-$n+1; $i++)
    {
        # Získat morfologický a syntaktický vzorec n-tice.
        # Morfologickým myslím posloupnost upravených značek, syntaktickým posloupnost indexů rodičů.
        # U syntaktických je indexem "X", pokud závislost vede ven z n-tice, a také pokud uzel "visí"
        # sám na sobě (nemělo by se stát jinde než u kořene, tj. uzlu s indexem 0).
        my @mvzor = map{$_->{uznacka}}(@{$anot}[$i..$i+$n-1]);
        my @svzor;
        # Spočítat závislosti, které vedou ze skupiny ven.
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
        # Jestliže ven vede více než jedna závislost, skupina je roztržená a asi nemá smysl se pokoušet
        # někdy ji rekonstruovat. I tak si ale musíme zapamatovat výskyt mvzoru, protože nám sníží váhu
        # těch výskytů, při nichž skupina roztržená nebyla.
        if($ven>1)
        {
            $svzor = join(",", map{"X"}[0..$n-1]);
        }
        else
        {
            $svzor = join(",", @svzor);
        }
        # Proměnné globální v rámci tohoto modulu: %ntice a %priklady.
        # Zapamatovat si výskyt dané dvojice vzorů.
        $ntice{$mvzor}{$svzor}++;
        # Jestliže neznáme příklad, zapamatovat si také příklad.
        unless(exists($priklady{$mvzor}))
        {
            $priklady{$mvzor} = join(" ", map{$_->{slovo}}(@{$anot}[$i..$i+$n-1]));
        }
    }
}



#------------------------------------------------------------------------------
# Uloží naučené vzory n-tic morfologických značek.
#------------------------------------------------------------------------------
sub vypsat
{
    my @mvzory = sort(keys(%ntice));
    print STDERR ("Mame ", $#mvzory+1, " mvzoru.\n");
    for(my $i = 0; $i<=$#mvzory; $i++)
    {
        # Seřadit řešení sestupně podle četnosti.
        my $svzhsh = $ntice{$mvzory[$i]};
        my @svzory = sort{$svzhsh->{$b}<=>$svzhsh->{$a}}(keys(%{$svzhsh}));
        # Zjistit celkový počet výskytů n-tice. Řídkým n-ticím raději nevěřit.
        # Současně zjistit, zda jeden názor na řešení dostatečně převažuje a
        # zda převažující "řešení" není případ, kdy byla n-tice roztržena.
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
        # Jestliže n-tice prošla filtrem, uložit si její výstup. Na konci výstupy seřadíme a vypíšeme.
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
    # Seřadit a vypsat záznamy.
    @vystupy = sort{$a->{vyznam}<=>$b->{vyznam}}(@vystupy);
    for(my $i = 0; $i<=$#vystupy; $i++)
    {
        vystupy::vypsat("ntice", $vystupy[$i]{vystup});
    }
}



#------------------------------------------------------------------------------
# Uloží naučené vzory n-tic morfologických značek do centrálního souboru se
# statistikou.
#------------------------------------------------------------------------------
sub vypsat_do_stat
{
    # Parametry pro filtrování n-tic.
    my $min_vyskytu = 5;
    my $min_uspesnost = 0.9;
    my @mvzory = sort(keys(%ntice));
    foreach $mvzor (@mvzory)
    {
        # Seřadit řešení sestupně podle četnosti.
        my $svzhsh = $ntice{$mvzor};
        my @svzory = sort{$svzhsh->{$b}<=>$svzhsh->{$a}}(keys(%{$svzhsh}));
        # Zjistit celkový počet výskytů n-tice. Řídkým n-ticím raději nevěřit.
        # Současně zjistit, zda jeden názor na řešení dostatečně převažuje a
        # zda převažující "řešení" není případ, kdy byla n-tice roztržena.
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
        # Ignorovat mvzory, které se vyskytly málokrát, které nemají jasného vítěze
        # mezi svzory nebo jejichž svzor není souvislý strom.
        next if($celkem<$min_vyskytu || $max/$celkem<$min_uspesnost || $svzory[$jmax] !~ m/\d/);
        # Jestliže n-tice prošla filtrem, uložit si její výstup. Na konci výstupy seřadíme a vypíšeme.
        vystupy::vypsat("stat", "NTC MVZOR $mvzor SVZOR $svzory[$jmax]\t$svzhsh->{$svzory[$jmax]}\n");
    }
}



#------------------------------------------------------------------------------
# Načte naučené vzory n-tic morfologických značek.
#------------------------------------------------------------------------------
sub cist
{
    my @soubory = @_;
    my %ntice;
    foreach my $soubor (@soubory)
    {
        open(NTICE, $soubor) or die("Nelze otevřít soubor $soubor: $!\n");
        binmode(NTICE, ":encoding(iso-8859-2)");
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
                # Zajistit, aby se k mvzoru zapsalo pouze první (nejlepší) řešení: ostatní přesměrovat do kanálu.
                $mvzor = "";
            }
        }
        close(NTICE);
    }
    return \%ntice;
}



#------------------------------------------------------------------------------
# Projde statistiku, vybere z ní naučené vzory n-tic morfologických značek a
# uloží je ve stravitelnějším tvaru.
#------------------------------------------------------------------------------
sub cist_ze_stat
{
    my $stat = shift; # odkaz na hash se statistikou
    my @udalosti = keys(%{$stat});
    my %ntice;
    foreach my $ud (@udalosti)
    {
        if($ud =~ m/^NTC/)
        {
            if($ud =~ m/^NTC MVZOR (.*) SVZOR (\S*)/)
            {
                my $mvzor = $1;
                my $svzor = $2;
                $ntice{$mvzor} = $svzor;
            }
            delete($stat->{$ud});
        }
    }
    return \%ntice;
}



#------------------------------------------------------------------------------
# Pokusí se na větu aplikovat vzory n-tic. Vrátí částečně rozebranou větu.
# (Předpokládá, že byla nasazena před všemi ostatními nástroji, tj. že žádná
# část věty ještě rozebraná není.)
#------------------------------------------------------------------------------
sub nasadit
{
    my $ntice = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashů s anotacemi jednotlivých slov
    my @rodice; # výstupní pole
    my @mzn = map{$_->{uznacka}}(@{$anot});
    # Přednost vzorů při konfliktu: zatím ten, který se ve větě najde první (tj. nejdelší vzor, a nebo, pokud jsou stejně dlouhé, vzor nejvíc vlevo).
    ### Mělo by to být spíš tak, že nejúspěšnější pravidlo má největší přednost!
    ### Nebo by se od n-tic mělo upustit tam, kde jsou v konfliktu.
    for(my $n = 10; $n>=2; $n--)
    {
    for(my $i = 0; $i<=$#mzn-2; $i++)
    {
        my $mvzor = join(" ", @mzn[$i..$i+$n-1]);
        next if(!exists($ntice->{$mvzor}));
        my @svzor = split(",", $ntice->{$mvzor});
        # Uložit nalezené řešení do seznamu rodičů.
        for(my $j = 0; $j<=$#svzor; $j++)
        {
        unless($svzor[$j] eq "X")
        {
            # Zapamatovat si konflikty mezi překrývajícími se n-ticemi.
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
# Porovná vzorovou, úplnou a částečnou analýzu téže věty. Předpokládá, že
# úplná analýza je "původní" bez n-tic, zatímco částečná je "nová", s n-ticemi.
# Tam, kde se částečná analýza uplatnila, zjistí, zda jde o zlepšení apod.
#------------------------------------------------------------------------------
sub zhodnotit
{
    my $vzor = shift; # odkaz na vzorové pole indexů rodičů
    my $ntc0 = shift; # odkaz na pole indexů rodičů dodané původním parserem
    my $ntc1 = shift; # odkaz na pole indexů rodičů dodané novým parserem
    my $ntc = shift; # odkaz na pole indexů rodičů podle n-tic umožňuje poznat, kde n-tice přímo zasáhly
    for(my $i = 0; $i<=$#{$ntc1}; $i++)
    {
        if($ntc->[$i] ne "")
        {
            $main::ntice_celkem++;
            my $dobre0 = $ntc0->[$i]==$vzor->[$i];
            my $dobre1 = $ntc1->[$i]==$vzor->[$i];
            my $stejne = $ntc1->[$i]==$ntc0->[$i];
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
        # Tento uzel nebyl zavěšen podle modelu n-tic, ale jeho zavěšení mohlo být ovlivněno
        # novou situací, která po částečném rozboru věty pomocí n-tic nastala.
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
# Vytvoří hlášení na základě svých statistik. Nikam ho nevypisuje, jen ho vrátí
# volajícímu. Je na volajícím, aby rozhodl, na který výstup ho pošle.
#------------------------------------------------------------------------------
sub vytvorit_hlaseni
{
    my $hlaseni = "------- Model n-tic -------\n";
    $hlaseni .= sprintf("%7d   rozhodnutých slov\n", $main::ntice_celkem);
    $hlaseni .= sprintf("%7d   konfliktů mezi překrývajícími se n-ticemi\n", $main::ntice_konflikty);
    $hlaseni .= sprintf("%7d   zlepšení oproti původnímu modelu\n", $main::ntice_lepsi);
    $hlaseni .= sprintf("%7d   zhoršení oproti původnímu modelu\n", $main::ntice_horsi);
    $hlaseni .= sprintf("%7d   stejně dobrých jako původní model\n", $main::ntice_dobre);
    $hlaseni .= sprintf("%7d   stejně špatných jako původní model\n", $main::ntice_stejne_spatne);
    $hlaseni .= sprintf("%7d   jiných než původní model, ale také špatných\n", $main::ntice_ruzne_spatne);
    $hlaseni .= sprintf("%7d   slov mimo n-tice\n", $main::ntice_neprimo);
    $hlaseni .= sprintf("%7d   nepřímých zlepšení oproti původnímu modelu\n", $main::ntice_neprimo_lepsi);
    $hlaseni .= sprintf("%7d   nepřímých zhoršení oproti původnímu modelu\n", $main::ntice_neprimo_horsi);
    $hlaseni .= sprintf("%7d   nepřímo stejně dobrých jako původní model\n", $main::ntice_neprimo_dobre);
    $hlaseni .= sprintf("%7d   nepřímo stejně špatných jako původní model\n", $main::ntice_neprimo_stejne_spatne);
    $hlaseni .= sprintf("%7d   nepřímo jiných než původní model, ale také špatných\n", $main::ntice_neprimo_ruzne_spatne);
    return $hlaseni;
}



1;
