package rozebrat;
use utf8;
use debug;
use zakaz;
use genstav;
use stav;
use subkat;
use nepreskocv;



#------------------------------------------------------------------------------
# Vybuduje závislostní strukturu věty.
# Tady se snažím oprostit původní funkci rozebrat_vetu() od globálních proměnných.
#------------------------------------------------------------------------------
sub rozebrat_vetu
{
    my $anot = shift; # odkaz na pole hashů
    # Volitelně lze jako parametr dodat výsledek částečné analýzy jinými
    # prostředky. V tom případě funkce doplní rodiče jen těm uzlům, které je
    # dosud nemají.
    my $analyza0 = shift;
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Založit strukturu se stavem analýzy a vyplnit do ní počáteční hodnoty.
    my $stav = vytvorit_pocatecni_stav($anot, $analyza0);
    while($stav->{zbyva}>0)
    {
        # Kvůli pokusům s přesností a úplností případně zahrnout pro každé slovo i alternativní zavěšení.
        if($konfig->{nekolik_nejlepsich_zavislosti})
        {
            # Pro každou povolenou hranu vygenerovat stav odpovídající přidání této hrany do stromu.
            my $nove_stavy = genstav::generovat_stavy($stav, $anot, 1);
            # První prvek pole je stav, který má zvítězit.
            $stav = shift(@{$nove_stavy});
            # Ze záložních návrhů vybrat ty nejlepší a uložit je do pole alternativ.
            # Toto pole nám zatím slouží výhradně pro vyhodnocení za běhu, alternativy se ani nevypisují
            # do cílového CSTS.
            pridat_do_stavu_alternativy($stav, $nove_stavy);
        }
        else
        {
            # Pro každou povolenou hranu vygenerovat stav odpovídající přidání této hrany do stromu.
            my $nove_stavy = genstav::generovat_stavy($stav, $anot, 0);
            # První prvek pole je stav, který má zvítězit. Záložní návrhy zatím ignorovat a zahodit.
            $stav = $nove_stavy->[0];
        }
    }
    # Prověřit, zda se něco nemělo udělat raději jinak.
    $stav = backtrack($anot, $stav);
    return $stav;
}



#------------------------------------------------------------------------------
# Zjistí, zda je ve stromě něco v nepořádku, co by si zasloužilo přehodnocení
# analýzy, a doporučí stav, ke kterému by se analýza měla vrátit. Pokud strom
# vypadá dobře, vrátí 0.
#------------------------------------------------------------------------------
sub backtrack
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na hash s dosavadním stavem analýzy
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    ### Prověřit naplněnost subkategorizačních rámců - zatím hodně pokusné!
    # Jestliže se zjistí, že některé sloveso nemá naplněný subkategorizační rámec,
    # ve větě je materiál, kterým by mohlo jít tento rámec naplnit, a ještě
    # existují nějaké nevyzkoušené stavy analýzy, vrátit se k těmto stavům.
    if($konfig->{valence1} && subkat::najit_nenaplnene_ramce($anot, $konfig->{nacteny_subkategorizacni_slovnik}, $stav))
    {
        # Zatím ladění. Zjistit, co přesně by nám ve větě mohlo pomoci s naplněním valence.
        my $evidence = subkat::najit_valencni_rezervy($anot, $stav, $konfig->{nacteny_subkategorizacni_slovnik});
        if(join("", @{$evidence}) =~ m/1/)
        {
            print("\n", join("", @{$evidence}), "\n");
            # Tady si budeme pamatovat zpracované i záložní stavy.
            my %prehled;
            # Nejdřív zopakovat analýzu a zapamatovat si stavy, ke kterým bychom se mohli vrátit.
            # Standardně to neděláme, protože to zabírá moc času.
            $stav = vytvorit_pocatecni_stav($anot, $analyza0);
            while($stav->{zbyva}>0)
            {
                # Pro každou povolenou hranu vygenerovat stav odpovídající přidání této hrany do stromu.
                my $nove_stavy = genstav::generovat_stavy($stav, $anot, 1);
                # Zapamatovat si, že dosavadní stav byl zpracován a vyždímán.
                $stav->{zpracovano} = 1;
                # Zapamatovat si odkazy na všechny nové stavy. Pokud některý nový stav
                # obsahuje stejný strom jako některý už známý stav, neukládat strom dvakrát.
                # Pouze se podívat, jestli nový stav neposkytuje danému stromu lepší váhu,
                # vítěze schovat a poraženého zahodit.
                for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
                {
                    my $hashvalue = join(",", @{$nove_stavy->[$i]{rodic}});
                    if(exists($prehled{$hashvalue}))
                    {
                        if($prehled{$hashvalue}{vaha}<$nove_stavy->[$i]{vaha} &&
                           !$prehled{$hashvalue}{zpracovano})
                        {
                            $prehled{$hashvalue} = $nove_stavy->[$i];
                        }
                    }
                    else
                    {
                        $prehled{$hashvalue} = $nove_stavy->[$i];
                    }
                }
                # První prvek pole je stav, který má zvítězit.
                $stav = $nove_stavy->[0];
            }
            my $puvodni_vysledny_stav = $stav;
            my @fronta_stavu;
            my $n_navratu;
            print("\n");
            while(subkat::najit_nenaplnene_ramce($anot, $konfig->{nacteny_subkategorizacni_slovnik}, $stav))
            {
                print("NAVRAT CISLO ", ++$n_navratu, "\n");
                # Seřadit záložní stavy sestupně podle váhy (pozor, odfiltrovat zpracované stavy!)
                @fronta_stavu = keys(%prehled);
                my $n_stavu_celkem = $#fronta_stavu+1;
                print("V prehledu je $n_stavu_celkem stavu.\n");
                @fronta_stavu = grep{!$prehled{$_}{zpracovano}}(@fronta_stavu);
                # Projít nezpracované stavy a označit ty, které nám neslibují nic
                # nového, za zpracované.
                foreach my $stavstrom (@fronta_stavu)
                {
                    my $stav = $prehled{$stavstrom};
                    if(1)
                    {
                        # Zajímavé jsou pouze stavy těsně po zavěšení některého nadějného uzlu.
                        unless($evidence->[$stav->{poslz}]==1)
                        {
                            # Kvůli úspoře paměti úplně vyprázdnit zavržený stav tím, že založíme
                            # nový hash, který bude obsahovat pouze příznak {zpracovano}, a odkazem
                            # na něj přepíšeme odkaz na dosavadní hash.
                            my %stav1;
                            $stav1{zpracovano} = 1;
                            $prehled{$stavstrom} = $stav = \%stav1;
                        }
                    }
                    else
                    {
                        my $nalezeno = 0;
                        for(my $i = 0; $i<=$#{$evidence}; $i++)
                        {
                            # Najít aspoň jeden uzel, který je veden jako nadějný a v tomto stavu ještě není zavěšen.
                            if($evidence->[$i]==1 && $stav->{rodic}[$i]==-1)
                            {
                                $nalezeno = 1;
                                last;
                            }
                        }
                        unless($nalezeno)
                        {
                            $stav->{zpracovano} = 1;
                        }
                    }
                }
                # Znova vyházet z fronty zpracované stavy.
                @fronta_stavu = grep{!$prehled{$_}{zpracovano}}(@fronta_stavu);
                print("Z toho ", $#fronta_stavu+1, " jeste nebylo zpracovano.\n");
                @fronta_stavu = sort{$prehled{$b}{vaha}<=>$prehled{$a}{vaha}}(@fronta_stavu);
                # Jestliže nezbývají žádné záložní stavy a stále není splněna valenční podmínka, vrátit se k původnímu výsledku.
                # Totéž udělat, jestliže jsme dosáhli maximálního povoleného počtu návratů
                # nebo maximálního povoleného počtu nagenerovaných stavů.
                if(!@fronta_stavu ||
                   $konfig->{valence1_maxnavratu} ne "" && $n_navratu>$konfig->{valence1_maxnavratu} ||
                   $konfig->{valence1_maxgenstav} ne "" && $n_stavu_celkem>$konfig->{valence1_maxgenstav})
                {
                    print("Buď došly stavy, nebo byl překročen povolený počet návratů.\n");
                    $stav = $puvodni_vysledny_stav;
                    last;
                }
                # Vrátit se k dosud nevyzkoušenému stavu.
                $stav = $prehled{$fronta_stavu[0]};
                # Znova od tohoto stavu budovat strom. (Celý while je kopií obdobného kódu o pár řádků výše,
                # měla by na to být funkce.)
                while($stav->{zbyva}>0)
                {
                    # Pro každou povolenou hranu vygenerovat stav odpovídající přidání této hrany do stromu.
                    my $nove_stavy = genstav::generovat_stavy($stav, $anot, 1);
                    # Zapamatovat si, že dosavadní stav byl zpracován a vyždímán.
                    $stav->{zpracovano} = 1;
                    # Zapamatovat si odkazy na všechny nové stavy. Pokud některý nový stav
                    # obsahuje stejný strom jako některý už známý stav, neukládat strom dvakrát.
                    # Pouze se podívat, jestli nový stav neposkytuje danému stromu lepší váhu,
                    # vítěze schovat a poraženého zahodit.
                    for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
                    {
                        my $hashvalue = join(",", @{$nove_stavy->[$i]{rodic}});
                        if(exists($prehled{$hashvalue}))
                        {
                            # Jestliže jsme přirozeným procesem získali stav, který už byl v nějakém minulém procesu
                            # nalezen a zpracován, vyloučit ho z nových stavů. Na řadu přijde další náhradník.
                            if($prehled{$hashvalue}{zpracovano})
                            {
                                if($i==0)
                                {
                                    shift(@{$nove_stavy});
                                    $i--;
                                }
                            }
                            else
                            {
                                if($prehled{$hashvalue}{vaha}<$nove_stavy->[$i]{vaha})
                                {
                                    $prehled{$hashvalue} = $nove_stavy->[$i];
                                }
                            }
                        }
                        else
                        {
                            $prehled{$hashvalue} = $nove_stavy->[$i];
                        }
                    }
                    # První prvek pole je stav, který má zvítězit.
                    # Pokud nám ovšem po předcházející čistce vůbec nějaký zbyl.
                    if($#{$nove_stavy}>=0)
                    {
                        $stav = $nove_stavy->[0];
                    }
                    else
                    {
                        $stav = $puvodni_vysledny_stav;
                    }
                }
                # Pokud jsme do předcházející smyčky vůbec nevkročili, náš stav není označen jako zpracovaný!
                # Označit ho, nebo ho budeme dostávat pořád dokola!
                $stav->{zpracovano} = 1;
            }
            print("Jsme venku z valencni smycky. Pokud nedosly stavy, valence je naplnena!\n");
            print("zasmyckou:", join(",", @{$stav->{rodic}}), "\n");
        }
    }
konec_valencniho_backtrackingu:
    # Zjistit, kolik dětí má kořen. Pokud jich bude mít víc než 2, řešit.
    my $n_deti_korene = $stav->{ndeti}[0];
    if($konfig->{koren_2_deti} && $n_deti_korene>2)
    {
        # Vybrat z dětí to nejpravděpodobnější. Poslední uzel vynechat, mohla
        # by to být koncová interpunkce.
        my $maxp;
        my $imaxp;
        for(my $i = 0; $i<$#{$anot}; $i++)
        {
            if($stav->{rodic}[$i]==0)
            {
                my $p = model::ud("OZZ $stav->{uznck}[0] $stav->{uznck}[$i] V D");
                if($maxp eq "" || $p>$maxp)
                {
                    $maxp = $p;
                    $imaxp = $i;
                }
            }
        }
        # Všechny děti kromě vítěze a posledního uzlu odpojit. Jejich závislost
        # na kořeni dát na černou listinu.
        for(my $i = 0; $i<$#{$anot}; $i++)
        {
            if($stav->{rodic}[$i]==0 && $i!=$imaxp)
            {
                stav::zrusit_zavislost($stav, $i);
                zakaz::pridat_zakaz(\$stav->{zakaz}, 0, $i, "kořen");
            }
        }
        # Odpojené uzly znova někam zavěsit.
        while($stav->{zbyva}>0)
        {
            # Pro každou povolenou hranu vygenerovat stav odpovídající přidání této hrany do stromu.
            my $nove_stavy = genstav::generovat_stavy($stav, $anot, 0);
            # První prvek pole je stav, který má zvítězit. Záložní návrhy zatím ignorovat a zahodit.
            $stav = $nove_stavy->[0];
        }
    }
    return $stav;
}



#------------------------------------------------------------------------------
# Nastaví počáteční stav analýzy.
#------------------------------------------------------------------------------
sub vytvorit_pocatecni_stav
{
    my $anot = shift; # odkaz na pole hashů
    # Volitelně lze jako parametr dodat výsledek částečné analýzy jinými
    # prostředky. V tom případě funkce doplní rodiče jen těm uzlům, které je
    # dosud nemají.
    my $analyza0 = shift;
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Založit balíček se všemi údaji o stavu analýzy.
    my %stav;
    # Nejdůležitější část stavu je částečně vybudovaný strom. Reprezentuje ho pole odkazů na rodiče.
    # Na začátku nastavit index rodiče každého uzlu na -1.
    @{$stav{rodic}} = map{-1}(0..$#{$anot});
    $stav{nprid} = 0; # pořadí naposledy přidaného uzlu (první přidaný uzel má jedničku)
    $stav{zbyva} = $#{$anot}; # Pokrok v analýze je řízen touto proměnnou. Předpokládá, že počet uzlů ve větě se nemění!
    # Stav analýzy si udržuje svou vlastní kopii morfologických značek jednotlivých
    # uzlů. Tyto značky se mohou měnit i v průběhu syntaktické analýzy. Např. se
    # může zjistit, že značka navržená taggerem by porušovala shodu. U kořenů koordinace
    # se ihned po sestavení koordinace vyplní morfologická značka některého člena
    # koordinace. Atd. Veškerá pravidla a statistické modely by se během analýzy
    # měla dívat na značku uloženou ve stavu. Pro použití původní značky by musel
    # být dobrý důvod.
    @{$stav{uznck}} = map{$_->{uznacka}}(@{$anot});
    # Přidání některých závislostí může být zakázáno, pokud nebo dokud nejsou splněny určité podmínky. Tyto zákazy
    # jsou většinou motivovány lingvisticky, závisí na konkrétním obsahu věty a mají přednost před seznamem povolených
    # závislostí (který je vymezen matematicky, aby to byl projektivní strom). Na konci mohou být zákazy zrušeny, pokud
    # by bránili dokončení alespoň nějakého stromu. Nyní vytvoříme počáteční množinu zákazů.
    my @prislusnost_k_useku; $stav{prislusnost_k_useku} = \@prislusnost_k_useku; # pro každý uzel číslo mezičárkového úseku
    my @hotovost_useku; $stav{hotovost_useku} = \@hotovost_useku; # pro každý úsek příznak, zda už je jeho podstrom hotový
    zakaz::formulovat_zakazy($anot, \%stav);
    # Jestliže už máme částečný rozbor věty, zapracovat ho do stavu.
    for(my $i = 0; $i<=$#{$analyza0}; $i++)
    {
        if($analyza0->[$i] ne "" && $analyza0->[$i]!=-1)
        {
            stav::pridat_zavislost($anot, \%stav, {"r" => $analyza0->[$i], "z" => $i, "c" => 0, "p" => 1});
        }
    }
    # Vytipovat závislosti, které by mohly naplnit subkategorizační rámce sloves.
    if($konfig->{valence})
    {
        $stav{valencni} = subkat::vytipovat_valencni_zavislosti($anot, $konfig->{nacteny_subkategorizacni_slovnik});
    }
    # Najít závislosti, kterým nemá být dovoleno přeskočit sloveso.
    if($konfig->{nepreskocv})
    {
        $stav{zakaz} = nepreskocv::najit_ve_vete($konfig->{nacteny_seznam_zakazu_preskoceni_slovesa}, $anot, $stav{zakaz});
    }
    $stav{zpracovano} = 0;
    return \%stav;
}



#------------------------------------------------------------------------------
# Do pole @{$stav->{altzav}} připíše "dostatečně slibná" alternativní zavěšení
# uzlu, jenž byl právě zavěšen.
#------------------------------------------------------------------------------
sub pridat_do_stavu_alternativy
{
    my $stav = shift;
    my $nove_stavy = shift; # Už neobsahují aktuální stav.
    my $maxivaha = $stav->{maxp}[$stav->{poslz}];
    for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
    {
        my $z = $nove_stavy->[$i]{poslz};
        my $r = $nove_stavy->[$i]{rodic}[$z];
        my $vaha = $nove_stavy->[$i]{maxp}[$z];
        last if($vaha<0.9*$maxivaha);
        # Tím, že každou závislost zapisujeme na předem určené místo, zajistíme,
        # že žádnou závislost nenavrhneme opakovaně. Nezaručíme však, že jako
        # alternativní nenavrhneme nějakou závislost, která později vyhraje
        # doopravdy.
        $stav->{altzav}[$r][$z] = 1;
        $maxivaha = $vaha;
    }
}



1;
