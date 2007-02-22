package rozebrat;
use debug;
use zakaz;
use genstav;
use stav;
use subkat;
use nepreskocv;



#------------------------------------------------------------------------------
# Vybuduje závislostní strukturu vìty.
# Tady se sna¾ím oprostit pùvodní funkci rozebrat_vetu() od globálních promìnných.
#------------------------------------------------------------------------------
sub rozebrat_vetu
{
    # Volitelnì lze jako parametr dodat výsledek èásteèné analýzy jinými
    # prostøedky. V tom pøípadì funkce doplní rodièe jen tìm uzlùm, které je
    # dosud nemají.
    my $analyza0 = shift;
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zalo¾it strukturu se stavem analýzy a vyplnit do ní poèáteèní hodnoty.
    my $stav = vytvorit_pocatecni_stav($analyza0);
    while($stav->{zbyva}>0)
    {
        # Pro ka¾dou povolenou hranu vygenerovat stav odpovídající pøidání této hrany do stromu.
        my $nove_stavy = genstav::generovat_stavy($stav, 0);
        # První prvek pole je stav, který má zvítìzit. Zálo¾ní návrhy zatím ignorovat a zahodit.
        $stav = $nove_stavy->[0];
    }
    # Provìøit, zda se nìco nemìlo udìlat radìji jinak.
    $stav = backtrack($stav);
    return $stav;
}



#------------------------------------------------------------------------------
# Zjistí, zda je ve stromì nìco v nepoøádku, co by si zaslou¾ilo pøehodnocení
# analýzy, a doporuèí stav, ke kterému by se analýza mìla vrátit. Pokud strom
# vypadá dobøe, vrátí 0.
#------------------------------------------------------------------------------
sub backtrack
{
    my $stav = shift; # odkaz na hash s dosavadním stavem analýzy
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    ### Provìøit naplnìnost subkategorizaèních rámcù - zatím hodnì pokusné!
    # Jestli¾e se zjistí, ¾e nìkteré sloveso nemá naplnìný subkategorizaèní rámec,
    # ve vìtì je materiál, kterým by mohlo jít tento rámec naplnit, a je¹tì
    # existují nìjaké nevyzkou¹ené stavy analýzy, vrátit se k tìmto stavùm.
    if($konfig->{valence1} && subkat::najit_nenaplnene_ramce($konfig->{nacteny_subkategorizacni_slovnik}, $stav))
    {
        # Zatím ladìní. Zjistit, co pøesnì by nám ve vìtì mohlo pomoci s naplnìním valence.
        my $evidence = subkat::najit_valencni_rezervy($anot, $stav, $konfig->{nacteny_subkategorizacni_slovnik});
        if(join("", @{$evidence}) =~ m/1/)
        {
            print("\n", join("", @{$evidence}), "\n");
            # Tady si budeme pamatovat zpracované i zálo¾ní stavy.
            my %prehled;
            # Nejdøív zopakovat analýzu a zapamatovat si stavy, ke kterým bychom se mohli vrátit.
            # Standardnì to nedìláme, proto¾e to zabírá moc èasu.
            $stav = vytvorit_pocatecni_stav($analyza0);
            while($stav->{zbyva}>0)
            {
                # Pro ka¾dou povolenou hranu vygenerovat stav odpovídající pøidání této hrany do stromu.
                my $nove_stavy = genstav::generovat_stavy($stav, 1);
                # Zapamatovat si, ¾e dosavadní stav byl zpracován a vy¾dímán.
                $stav->{zpracovano} = 1;
                # Zapamatovat si odkazy na v¹echny nové stavy. Pokud nìkterý nový stav
                # obsahuje stejný strom jako nìkterý u¾ známý stav, neukládat strom dvakrát.
                # Pouze se podívat, jestli nový stav neposkytuje danému stromu lep¹í váhu,
                # vítìze schovat a pora¾eného zahodit.
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
                # První prvek pole je stav, který má zvítìzit.
                $stav = $nove_stavy->[0];
            }
            my $puvodni_vysledny_stav = $stav;
            my @fronta_stavu;
            my $n_navratu;
            print("\n");
            while(subkat::najit_nenaplnene_ramce($konfig->{nacteny_subkategorizacni_slovnik}, $stav))
            {
                print("NAVRAT CISLO ", ++$n_navratu, "\n");
                # Seøadit zálo¾ní stavy sestupnì podle váhy (pozor, odfiltrovat zpracované stavy!)
                @fronta_stavu = keys(%prehled);
                my $n_stavu_celkem = $#fronta_stavu+1;
                print("V prehledu je $n_stavu_celkem stavu.\n");
                @fronta_stavu = grep{!$prehled{$_}{zpracovano}}(@fronta_stavu);
                # Projít nezpracované stavy a oznaèit ty, které nám neslibují nic
                # nového, za zpracované.
                foreach my $stavstrom (@fronta_stavu)
                {
                    my $stav = $prehled{$stavstrom};
                    if(1)
                    {
                        # Zajímavé jsou pouze stavy tìsnì po zavì¹ení nìkterého nadìjného uzlu.
                        unless($evidence->[$stav->{poslz}]==1)
                        {
                            # Kvùli úspoøe pamìti úplnì vyprázdnit zavr¾ený stav tím, ¾e zalo¾íme
                            # nový hash, který bude obsahovat pouze pøíznak {zpracovano}, a odkazem
                            # na nìj pøepí¹eme odkaz na dosavadní hash.
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
                            # Najít aspoò jeden uzel, který je veden jako nadìjný a v tomto stavu je¹tì není zavì¹en.
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
                # Jestli¾e nezbývají ¾ádné zálo¾ní stavy a stále není splnìna valenèní podmínka, vrátit se k pùvodnímu výsledku.
                # Toté¾ udìlat, jestli¾e jsme dosáhli maximálního povoleného poètu návratù
                # nebo maximálního povoleného poètu nagenerovaných stavù.
                if(!@fronta_stavu ||
                   $konfig->{valence1_maxnavratu} ne "" && $n_navratu>$konfig->{valence1_maxnavratu} ||
                   $konfig->{valence1_maxgenstav} ne "" && $n_stavu_celkem>$konfig->{valence1_maxgenstav})
                {
                    print("Buï do¹ly stavy, nebo byl pøekroèen povolený poèet návratù.\n");
                    $stav = $puvodni_vysledny_stav;
                    last;
                }
                # Vrátit se k dosud nevyzkou¹enému stavu.
                $stav = $prehled{$fronta_stavu[0]};
                # Znova od tohoto stavu budovat strom. (Celý while je kopií obdobného kódu o pár øádkù vý¹e,
                # mìla by na to být funkce.)
                while($stav->{zbyva}>0)
                {
                    # Pro ka¾dou povolenou hranu vygenerovat stav odpovídající pøidání této hrany do stromu.
                    my $nove_stavy = genstav::generovat_stavy($stav, 1);
                    # Zapamatovat si, ¾e dosavadní stav byl zpracován a vy¾dímán.
                    $stav->{zpracovano} = 1;
                    # Zapamatovat si odkazy na v¹echny nové stavy. Pokud nìkterý nový stav
                    # obsahuje stejný strom jako nìkterý u¾ známý stav, neukládat strom dvakrát.
                    # Pouze se podívat, jestli nový stav neposkytuje danému stromu lep¹í váhu,
                    # vítìze schovat a pora¾eného zahodit.
                    for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
                    {
                        my $hashvalue = join(",", @{$nove_stavy->[$i]{rodic}});
                        if(exists($prehled{$hashvalue}))
                        {
                            # Jestli¾e jsme pøirozeným procesem získali stav, který u¾ byl v nìjakém minulém procesu
                            # nalezen a zpracován, vylouèit ho z nových stavù. Na øadu pøijde dal¹í náhradník.
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
                    # První prvek pole je stav, který má zvítìzit.
                    # Pokud nám ov¹em po pøedcházející èistce vùbec nìjaký zbyl.
                    if($#{$nove_stavy}>=0)
                    {
                        $stav = $nove_stavy->[0];
                    }
                    else
                    {
                        $stav = $puvodni_vysledny_stav;
                    }
                }
                # Pokud jsme do pøedcházející smyèky vùbec nevkroèili, ná¹ stav není oznaèen jako zpracovaný!
                # Oznaèit ho, nebo ho budeme dostávat poøád dokola!
                $stav->{zpracovano} = 1;
            }
            print("Jsme venku z valencni smycky. Pokud nedosly stavy, valence je naplnena!\n");
            print("zasmyckou:", join(",", @{$stav->{rodic}}), "\n");
        }
    }
konec_valencniho_backtrackingu:
    # Zjistit, kolik dìtí má koøen. Pokud jich bude mít víc ne¾ 2, øe¹it.
    my $n_deti_korene = $stav->{ndeti}[0];
    if($konfig->{koren_2_deti} && $n_deti_korene>2)
    {
        # Vybrat z dìtí to nejpravdìpodobnìj¹í. Poslední uzel vynechat, mohla
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
        # V¹echny dìti kromì vítìze a posledního uzlu odpojit. Jejich závislost
        # na koøeni dát na èernou listinu.
        for(my $i = 0; $i<$#{$anot}; $i++)
        {
            if($stav->{rodic}[$i]==0 && $i!=$imaxp)
            {
                stav::zrusit_zavislost($stav, $i);
                zakaz::pridat_zakaz(\$stav->{zakaz}, 0, $i, "koøen");
            }
        }
        # Odpojené uzly znova nìkam zavìsit.
        while($stav->{zbyva}>0)
        {
            # Pro ka¾dou povolenou hranu vygenerovat stav odpovídající pøidání této hrany do stromu.
            my $nove_stavy = genstav::generovat_stavy($stav, 0);
            # První prvek pole je stav, který má zvítìzit. Zálo¾ní návrhy zatím ignorovat a zahodit.
            $stav = $nove_stavy->[0];
        }
    }
    return $stav;
}



#------------------------------------------------------------------------------
# Nastaví poèáteèní stav analýzy.
#------------------------------------------------------------------------------
sub vytvorit_pocatecni_stav
{
    # Volitelnì lze jako parametr dodat výsledek èásteèné analýzy jinými
    # prostøedky. V tom pøípadì funkce doplní rodièe jen tìm uzlùm, které je
    # dosud nemají.
    my $analyza0 = shift;
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zalo¾it balíèek se v¹emi údaji o stavu analýzy.
    my %stav;
    # Nejdùle¾itìj¹í èást stavu je èásteènì vybudovaný strom. Reprezentuje ho pole odkazù na rodièe.
    # Na zaèátku nastavit index rodièe ka¾dého uzlu na -1.
    @{$stav{rodic}} = map{-1}(0..$#{$anot});
    $stav{nprid} = 0; # poøadí naposledy pøidaného uzlu (první pøidaný uzel má jednièku)
    $stav{zbyva} = $#{$anot}; # Pokrok v analýze je øízen touto promìnnou. Pøedpokládá, ¾e poèet uzlù ve vìtì se nemìní!
    # Stav analýzy si udr¾uje svou vlastní kopii morfologických znaèek jednotlivých
    # uzlù. Tyto znaèky se mohou mìnit i v prùbìhu syntaktické analýzy. Napø. se
    # mù¾e zjistit, ¾e znaèka navr¾ená taggerem by poru¹ovala shodu. U koøenù koordinace
    # se ihned po sestavení koordinace vyplní morfologická znaèka nìkterého èlena
    # koordinace. Atd. Ve¹kerá pravidla a statistické modely by se bìhem analýzy
    # mìla dívat na znaèku ulo¾enou ve stavu. Pro pou¾ití pùvodní znaèky by musel
    # být dobrý dùvod.
    @{$stav{uznck}} = map{$_->{uznacka}}(@{$anot});
    # Pøidání nìkterých závislostí mù¾e být zakázáno, pokud nebo dokud nejsou splnìny urèité podmínky. Tyto zákazy
    # jsou vìt¹inou motivovány lingvisticky, závisí na konkrétním obsahu vìty a mají pøednost pøed seznamem povolených
    # závislostí (který je vymezen matematicky, aby to byl projektivní strom). Na konci mohou být zákazy zru¹eny, pokud
    # by bránili dokonèení alespoò nìjakého stromu. Nyní vytvoøíme poèáteèní mno¾inu zákazù.
    my @prislusnost_k_useku; $stav{prislusnost_k_useku} = \@prislusnost_k_useku; # pro ka¾dý uzel èíslo mezièárkového úseku
    my @hotovost_useku; $stav{hotovost_useku} = \@hotovost_useku; # pro ka¾dý úsek pøíznak, zda u¾ je jeho podstrom hotový
    zakaz::formulovat_zakazy(\%stav);
    # Jestli¾e u¾ máme èásteèný rozbor vìty, zapracovat ho do stavu.
    for(my $i = 0; $i<=$#{$analyza0}; $i++)
    {
        if($analyza0->[$i] ne "" && $analyza0->[$i]!=-1)
        {
            stav::pridat_zavislost(\%stav, {"r" => $analyza0->[$i], "z" => $i, "c" => 0, "p" => 1});
        }
    }
    # Vytipovat závislosti, které by mohly naplnit subkategorizaèní rámce sloves.
    if($konfig->{valence})
    {
        $stav{valencni} = subkat::vytipovat_valencni_zavislosti($konfig->{nacteny_subkategorizacni_slovnik});
    }
    # Najít závislosti, kterým nemá být dovoleno pøeskoèit sloveso.
    if($konfig->{nepreskocv})
    {
        $stav{zakaz} = nepreskocv::najit_ve_vete($konfig->{nacteny_seznam_zakazu_preskoceni_slovesa}, $anot, $stav{zakaz});
    }
    $stav{zpracovano} = 0;
    return \%stav;
}



1;
