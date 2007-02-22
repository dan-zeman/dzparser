# Funkce související se subkategorizací sloves.
package subkat;
use model;



#------------------------------------------------------------------------------
# Naète seznam subkategorizaèních rámcù sloves.
#------------------------------------------------------------------------------
sub cist
{
    my $jmeno_souboru = shift;
    my %subcat; # výstupní hash (subkategorizaèní slovník)
    open(SUBCAT, $jmeno_souboru) or die("Nelze otevrit soubor $jmeno_souboru se seznamem ramcu: $!\n");
    while(<SUBCAT>)
    {
        chomp;
        # Na øádku je nejdøíve sloveso, pak dvì (?) mezery, pak rámec.
        # Rámec mezery neobsahuje. Èleny jsou oddìleny dvìma vlnovkami.
        # Prázdný rámec nepøechodných sloves je zastoupen znaèkou <INTR>.
        if(m/(.+?)\s+(.+)$/)
        {
            my $sloveso = $1;
            next if($sloveso eq "být");
            my $ramec = $2;
            # Rozdìlit rámce na jednotlivé vazby.
            my @vazby = split(/~~/, $ramec);
            for(my $i = 0; $i<=$#vazby; $i++)
            {
                # Vazba se skládá ze subkategorizaèní znaèky a
                # z analytické funkce (s-znaèky), oddìlené jsou
                # lomítkem. Odstranit lomítko a s-znaèku.
                $vazby[$i] =~ s-/.*--;
                $subcat{"$sloveso $vazby[$i]"}++;
            }
            # Zapamatovat si, ¾e sloveso je slovníkem vùbec nìjak pokryto.
            $subcat{"SLO $sloveso"}++;
            # Zapamatovat si celý rámec slovesa (vý¹e jsme si pamatovali jen jednotlivé
            # vazby) tak, aby bylo mo¾né najít v¹echny rámce urèitého slovesa.
            push(@{$subcat{"RAM $sloveso"}}, "$sloveso $ramec");
        }
    }
    close(SUBCAT);
    return \%subcat;
}



#------------------------------------------------------------------------------
# Pøevede (neredukovanou) morfologickou znaèku na subkategorizaèní.
#------------------------------------------------------------------------------
sub prevest_mznacku_na_vazbu
{
    my $mznacka = $_[0];
    my $heslo = $_[1];
    # Základem vazby je slovní druh. Podstatná jména, pøídavná jména, zájmena
    # a èíslovky v¹ak pova¾ujeme za jediný slovní druh. Výjimkou jsou urèité
    # výskyty zvratných zájmen "se" a "si" (vlastnì jen ty, v nich¾ vystupují
    # jako zvratné èástice. Nikdy v¹ak nemají morfologickou znaèku èástice.
    my $vazba = substr($mznacka, 0, 1);
    if($vazba eq "P" && $heslo =~ m/^(se|si)/)
    {
        $vazba = PR;
    }
    else
    {
        $vazba =~ s/[APC]/N/;
    }
    # Pøes podøadící spojky visí na slovesech závislé klauze (¾e, aby...)
    if(substr($mznacka, 0, 2) eq "J,")
    {
        $vazba = "JS";
    }
    # Pokud visí na slovese jiné urèité sloveso, jde o klauzi (který...)
    # nebo o pøímou øeè.
    if($mznacka =~ m/^V[^f]/)
    {
        $vazba = "S";
    }
    # Pokud visí na slovese infinitiv, chceme to vyjádøit zøetelnìji.
    if(substr($mznacka, 0, 2) eq "Vf")
    {
        $vazba = "VINF";
    }
    # Pøíslovce byla znaèena DB (i pokud jejich m-znaèka je Dg).
    if($vazba eq "D")
    {
        $vazba = "DB";
    }
    # Je-li relevantní pád, pøidat ho (mù¾e nastat u vý¹e uvedených a u
    # pøedlo¾ek.
    my $pad = substr($mznacka, 4, 1);
    if($pad ne "-")
    {
        $vazba .= $pad;
    }
    # U pøedlo¾ek a podøadících spojek pøidat do závorky heslo.
    # Toté¾ platí i o slovech "jak" a "proè", která jsou sice ve slovníku
    # vedena jako pøíslovce, ale anotátoøi je obèas povìsili jako AuxC.
    # Kvùli této nekonzistenci se tu musí objevit jazykovì závislý seznam.
    if($vazba =~ m/^(R|JS)/ ||
    $vazba eq "DB" && $heslo =~ m/^(jak|proè)(?:[-_].*)?$/)
    {
        # Z hesla odstranit pøípadné rozli¹ení významù za pomlèkou.
        $heslo =~ s/-.*//;
        $vazba .= "($heslo)";
    }
    return $vazba;
}



#------------------------------------------------------------------------------
# Vytipuje valenèní závislosti ve vìtì. Volá se pøed vlastní analýzou vìty.
# Vrací pole @valencni, jeho¾ prvek má tvar $r-$z($p), r a z jsou indexy
# øídícího a závislého uzlu a p je pravdìpodobnost takové závislosti (podle
# normálního modelu, nemá zatím nic spoleèného s pravdìpodobností pou¾itého
# rámce).
#------------------------------------------------------------------------------
sub vytipovat_valencni_zavislosti
{
    my $subcat = shift; # odkaz na hash se subkategorizaèním slovníkem
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zjistit, které potenciální závislosti ve vìtì by mohly být valenèní.
    my @valencni;
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{uznacka}=~m/^V/)
        {
            # Pro ka¾dé sloveso projít v¹echny ostatní uzly a zkoumat,
            # jestli by mohly být jeho vazbami.
            for(my $j = 0; $j<=$#{$anot}; $j++)
            {
                if($j!=$i)
                {
                    my $zn = $anot->[$j]{uznacka};
                    $zn =~ s/P(\d)/N$1/;
                    $zn =~ s/V([Bp]|jsem|jsi|je|ní|jsme|jste|jsou|budu|bude¹|bude|budeme|budete|budou|byl[aoiy]?)/S/;
                    $zn =~ s/V(f|být)/VINF/;
                    $zn =~ s/Pse(s)?/PR4/;
                    $zn =~ s/Psi(s)?/PR3/;
                    $zn =~ s/Db/DB/;
                    # Pøedlo¾ky se konvertují pøi naèítání valencí,
                    # proto¾e tady neznáme jejich pád.
                    $zn =~ s/J(,|¾e|aby|zda)/JS($anot->[$j]{slovo})/;
                jeste_jako_n:
                    if(exists($subcat->{"$anot->[$i]{heslo} $zn"}))
                    {
                        # Závislost i-j by mohla být valenèní.
                        # Zjistit její pravdìpodobnost.
                        my ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($i, $j);
                        push(@valencni, "$i-$j($p)");
                    }
                    elsif($zn=~s/^PR/N/)
                    {
                        goto jeste_jako_n;
                    }
                }
            }
        }
    }
    # Setøídit seznam potenciálních valenèních závislostí v této vìtì sestupnì podle pravdìpodobnosti.
    @valencni = sort
    {
        $a =~ m/(\d+)-(\d+)\((.*)\)/;
        my $ap = $3;
        my $ad = abs($1-$2);
        $b =~ m/(\d+)-(\d+)\((.*)\)/;
        my $bp = $3;
        my $bd = abs($1-$2);
        if($ap!=$bp)
        {
            return $bp<=>$ap;
        }
        else
        {
            return $bd<=>$ad;
        }
    }
    (@valencni);
    return \@valencni;
}



#------------------------------------------------------------------------------
# Projde strom vytvoøený parserem a pokusí se najít slovesa, kterým chybí
# nìjaký argument. Pokud taková najde a pokud navíc zjistí, ¾e ve vìtì existuje
# materiál, kterým by rámce mohly jít naplnit, vrátí 1. Jinak vrátí 0.
#------------------------------------------------------------------------------
sub najit_nenaplnene_ramce
{
    my $subcat = shift; # odkaz na hash se subkategorizaèním slovníkem
    my $stav = shift; # odkaz na hash se stavem analýzy (obsahuje mj. návrh stromu)
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Najít slovesa.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zajímají nás pouze slovesa pokrytá subkategorizaèním slovníkem.
        # Nezajímají nás, pokud jsou v pøíèestí trpném (pak toti¾ asi chybí N4 a nemá se doplòovat).
        if($anot->[$i]{znacka} =~ m/^V[^s]/ && exists($subcat->{"SLO $anot->[$i]{heslo}"}))
        {
            # Najít v¹echny navrhované dìti tohoto slovesa.
            my @deti;
            my %vazby_navrh;
            my %k_dispozici;
            for(my $j = 0; $j<=$#{$stav->{rodic}}; $j++)
            {
                # Zapamatovat si, jaké vazby by byly k dispozici.
                my $vznacka;
                if(exists($anot->[$j]{dedic}))
                {
                    $vznacka = prevest_mznacku_na_vazbu($anot->[$anot->[$j]{dedic}]{znacka}, $anot->[$anot->[$j]{dedic}]{heslo});
                }
                else
                {
                    $vznacka = prevest_mznacku_na_vazbu($anot->[$j]{znacka}, $anot->[$j]{heslo});
                }
                $k_dispozici{$vznacka}++;
                if($stav->{rodic}[$j]==$i)
                {
                    push(@deti, $anot->[$j]);
                    # Zapamatovat si, ¾e se v návrhu vyskytla urèitá vazba.
                    # Bude se nám to hodit pøi ovìøování naplnìnosti rámcù.
                    $vazby_navrh{$vznacka}++;
                    my $spravne = $anot->[$j]{rodic_vzor}==$i ? 1 : 0;
                }
            }
            # Projít v¹echny známé rámce tohoto slovesa a hledat nìjaký naplnìný.
            my $n_naplnenych = 0;
            my $n_lze_naplnit;
            foreach my $ramec (@{$subcat->{"RAM $anot->[$i]{heslo}"}})
            {
                # Zjistit, zda je tento rámec v navrhovaném stromu naplnìn.
                # Udìlat si kopii evidence navrhovaných vazeb, abychom si v ní mohli èmárat.
                my %kopie_navrhovanych_vazeb = %vazby_navrh;
                my %kopie_vazeb_k_dispozici = %k_dispozici;
                # Rozdìlit rámec na jednotlivé vazby.
                # Nejdøív z rámce odstranit sloveso.
                my $ramec_bez_slovesa = $ramec;
                $ramec_bez_slovesa =~ s/^\S+ //;
                my $ok = 1;
                my $lze_naplnit = 1;
                # Rámec "<INTR>" znamená, ¾e jde o nepøechodné sloveso, které nevy¾aduje ¾ádné argumenty.
                unless($ramec_bez_slovesa eq "<INTR>")
                {
                    my @vazby = split(/~~/, $ramec_bez_slovesa);
                    foreach my $vazba (@vazby)
                    {
                        # Vazba se skládá ze subkategorizaèní znaèky a
                        # z analytické funkce (s-znaèky), oddìlené jsou
                        # lomítkem. Odstranit lomítko a s-znaèku.
                        $vazba =~ s-/.*--;
                        # Zjistit, zda na tuto vazbu je¹tì zbývá nìjaký uzel z návrhu.
                        if($kopie_navrhovanych_vazeb{$vazba}>0)
                        {
                            $kopie_navrhovanych_vazeb{$vazba}--;
                            $kopie_vazeb_k_dispozici{$vazba}--;
                        }
                        else
                        {
                            # Zvlá¹tní pøípad: PR4 mù¾e naplnit i N4, tak¾e pokud nemù¾eme najít N4, zkusíme je¹tì PR4.
                            if($vazba eq "N4" && $kopie_navrhovanych_vazeb{"PR4"}>0)
                            {
                                $kopie_navrhovanych_vazeb{"PR4"}--;
                                $kopie_vazeb_k_dispozici{"PR4"}--;
                            }
                            else
                            {
                                $ok = 0;
                                if($kopie_vazeb_k_dispozici{$vazba}<=0)
                                {
                                    $lze_naplnit = 0;
                                    last;
                                }
                                else
                                {
                                    $kopie_vazeb_k_dispozici{$vazba}--;
                                }
                            }
                        }
                    }
                }
                if($ok)
                {
                    $n_naplnenych++;
                }
                else
                {
                    if($lze_naplnit)
                    {
                        $n_lze_naplnit++;
                        return 1;
                    }
                }
            }
        }
    }
    return 0;
}



#==============================================================================
# Funkce pro zji¹tìní, co lze na souèasné analýze vìty zlep¹it, aby byly lépe
# naplnìny valenèní rámce.
#==============================================================================



#------------------------------------------------------------------------------
# Získá seznam slov, která v dané analýze zaplòují nìkteré místo ve valenèních
# rámcích (a není tedy vhodné na jejich zavì¹ení nìco mìnit) a seznam slov,
# která nepatøí do první mno¾iny a souèasnì jejich pøevì¹ení mù¾e vést
# k zaplnìní dal¹ích valenèních míst. Oba seznamy zakóduje do návratového pole
# takto: 0 ... slovo u¾ zaplòuje valenci, nemìnit; 1 ... slovo nezaplòuje
# valenci, ale mohlo by; 2 ... slovo nezaplòuje valenci a ani nebylo zji¹tìno,
# ¾e by mohlo.
#------------------------------------------------------------------------------
sub najit_valencni_rezervy
{
    my $anot = shift; # odkaz na pole hashù
    my $stav = shift; # odkaz na hash (potøebujeme z nìj zejména návrh stromu, ale nejen ten)
    my $subkat = shift; # odkaz na hash se subkategorizaèním slovníkem
    my @evidence; # výstupní pole (0 u¾ pou¾ito 1 lze pou¾ít 2 ostatní)
    # Naplnit evidenci výchozími hodnotami.
    @evidence = map{2}(0..$#{$anot});
    # Získat seznam sloves ve vìtì, pokrytých valenèním slovníkem.
    my $slovesa = ziskat_seznam_sloves($anot, $subkat);
    # Získat doplòující údaje ke v¹em uzlùm navr¾eným za dìti sloves.
    my $deti = obohatit_deti($anot, $stav);
    # Projít slovesa a zjistit, co mají a co jim chybí.
    foreach my $sloveso (@{$slovesa})
    {
        # Pro dané sloveso vybrat rámec, zjistit, která slova se v nìm anga¾ují a
        # jaké druhy slov rámec je¹tì shání. Tato zji¹tìní rovnou pøipsat do
        # centrální evidence vyu¾itelnosti slov pro valenci.
        vybrat_ramec_a_promitnout_ho_do_evidence($anot, $sloveso, $deti, $subkat, \@evidence);
    }
    return \@evidence;
}



#------------------------------------------------------------------------------
# Dílèí funkce pro kontrolu valence. Projde vìtu a najde slovesa, pro která
# známe alespoò jeden rámec.
#------------------------------------------------------------------------------
sub ziskat_seznam_sloves
{
    my $anot = shift; # odkaz na pole hashù
    my $subcat = shift; # odkaz na hash se subkategorizaèním slovníkem
    my @slovesa;
    # Najít slovesa.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zajímají nás pouze slovesa pokrytá subkategorizaèním slovníkem.
        # Nezajímají nás, pokud jsou v pøíèestí trpném (pak toti¾ asi chybí N4 a nemá se doplòovat).
        if($anot->[$i]{znacka} =~ m/^V[^s]/ && exists($subcat->{"SLO $anot->[$i]{heslo}"}))
        {
            push(@slovesa, $i);
        }
    }
    return \@slovesa;
}



#------------------------------------------------------------------------------
# Zjistí pro ka¾dé dítì slovesa informace, které mohou rozhodovat o jeho zaøazení
# mezi povinná nebo volitelná doplnìní.
#------------------------------------------------------------------------------
sub obohatit_deti
{
    my $anot = shift; # odkaz na anotace jednotlivých slov
    my $stav = shift; # odkaz na hash; potøebujeme jen pøedat dál do model::ohodnotit_hranu(), jinak staèí pole navrhovaných rodièù
    my $navrhrod = $stav->{rodic}; # odkaz na pole indexù navrhovaných rodièù
    my @hodnoceni; # výstupní pole hashù
    # Potøebujeme zjistit:
    # - pro ka¾dé dítì slovesa váhu jeho závislosti na jeho rodièi
    # - pro ka¾dé dítì slovesa poèet sloves mezi ním a jeho rodièem
    # - pro ka¾dé dítì slovesa poèet sloves od nìj smìrem pryè od jeho rodièe
    my @slovesa; # seznam indexù dosud vidìných sloves
    my @deti; # evidence rozpracovaných a zpracovaných dìtí
    # A teï vlastní implementace.
    # Procházet slova ve vìtì.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zkonstruovat valenèní znaèku podle morfologické znaèky a dát ji do hodnocení.
        $hodnoceni[$i]{vznacka} = zjistit_valencni_znacku($anot, $i);
        # Zkopírovat do hodnocení index navrhovaného rodièe, aby se v¹em funkcím nemusel pøedávat i stav analýzy.
        $hodnoceni[$i]{index} = $i;
        $hodnoceni[$i]{rodic} = $navrhrod->[$i];
        $hodnoceni[$i]{vzdalenost} = abs($i-$navrhrod->[$i]);
        # Jsme na dítìti slovesa?
        if(je_sloveso($anot->[$navrhrod->[$i]]))
        {
            # Zjistit váhu závislosti aktuálního dítìte na slovese.
            $hodnoceni[$i]{vaha} = model::ohodnotit_hranu($i, $navrhrod->[$i], $stav);
            # Je rodièovské sloveso vpravo od nás?
            if($navrhrod->[$i]>$i)
            {
                # V¹echna dosud vidìná slovesa pøièíst jako vnìj¹í slovesa tohoto uzlu.
                $hodnoceni[$i]{vnejsi} += $#slovesa+1;
                # Pøidat se do seznamu dìtí jako rozpracované.
                push(@deti, {"index" => $i, "stav" => "rozprac"});
            }
            # Rodièovské sloveso je vlevo od nás.
            else
            {
                # Vrátit se po seznamu vidìných sloves a¾ k rodièi tohoto uzlu a spoèítat vnitøní slovesa.
                for(my $j = $#slovesa; $j>=0 && $slovesa[$j]!=$navrhrod->[$i]; $j--)
                {
                    $hodnoceni[$i]{vnitrni}++;
                }
                # Pøidat se do seznamu dìtí rovnou jako zpracované.
                push(@deti, {"index" => $i, "stav" => "zprac"});
            }
        }
        # Jsme na slovese? (Pozor na poøadí krokù, i sloveso mù¾e být dítìtem jiného slovesa!)
        if(je_sloveso($anot->[$i]))
        {
            # Pøipsat se mezi vidìná slovesa.
            push(@slovesa, $i);
            # Projít rozpracované dìti. K cizím se pøièíst jako vnitøní, své ukonèit, ke zpracovaným pøípadnì jako vnìj¹í.
            for(my $j = 0; $j<=$#deti; $j++)
            {
                # Ke zpracovaným dìtem (nemohou být moje), jejich¾ rodiè le¾í vlevo od nich, se pøièíst jako vnìj¹í.
                my $index = $deti[$j]{index};
                if($deti[$j]{stav} eq "zprac" && $navrhrod->[$index]<$index)
                {
                    $hodnoceni[$index]{vnejsi}++;
                }
                # Rozpracované dìti.
                elsif($deti[$j]{stav} eq "rozprac")
                {
                    # Pokud jsou moje, oznaèit je za zpracované.
                    if($navrhrod->[$index]==$i)
                    {
                        $deti[$j]{stav} = "zprac";
                    }
                    # Pokud nejsou moje, pøièíst se k nim jako vnitøní.
                    else
                    {
                        $hodnoceni[$index]{vnitrni}++;
                    }
                }
            }
        }
    }
    return \@hodnoceni;
}



#------------------------------------------------------------------------------
# Dílèí funkce pro kontrolu valence. Zjistí valenèní znaèku slova.
#------------------------------------------------------------------------------
sub zjistit_valencni_znacku
{
    my $anot = shift; # odkaz na pole hashù pro jednotlivá slova ve vìtì
    my $index = shift; # index slova, jeho¾ valenèní znaèka nás zajímá
    my $vznacka;
    if(exists($anot->[$index]{dedic}))
    {
        $vznacka = prevest_mznacku_na_vazbu($anot->[$anot->[$index]{dedic}]{znacka}, $anot->[$anot->[$index]{dedic}]{heslo});
    }
    else
    {
        $vznacka = prevest_mznacku_na_vazbu($anot->[$index]{znacka}, $anot->[$index]{heslo});
    }
    return $vznacka;
}



#------------------------------------------------------------------------------
# Projde rámce zadaného slovesa a porovná je s dìtmi, které slovesu navrhl
# parser. Vybere rámec, který je danou mno¾inou dìtí nejlépe naplnìn. Vyhraje
# rámec, kterému zùstalo nejménì nezaplnìných míst. Pøi rovnosti vyhraje první
# takový nalezený rámec. Mohli bychom je¹tì brát v úvahu, kolik je ve vìtì
# k dispozici uzlù s valenèní znaèkou, kterou po¾aduje nìkteré nezaplnìné místo
# rámce, ale tento poèet nebudeme znát pøesnì, dokud v¹em slovesùm nepøiøadíme
# rámce (nìkteré dìti sloves mohou být oznaèeny za volná doplnìní a být tak
# k dispozici pro rámce, které by z nich chtìly udìlat povinná doplnìní), a to
# je zaèarovaný kruh. Funkce u¾ také nehledí na to, jak kvalitními doplnìními
# jsou jednotlivá místa rámce zaplnìna (napø. jak daleko má pøíslu¹né dítì ke
# slovesu), pøesto¾e se tato kritéria pou¾ívají pøi vlastním zaplòování jednoho
# rámce a výbìru mezi nìkolika dìtmi, které by dané místo mohly zaplnit.
#
# Funkce nevrací pøímo vybraný rámec, ale rovnou výsledky jeho srovnání s dìtmi
# slovesa, proto¾e to je to, co volající potøebuje, a my to v prùbìhu vybírání
# tak jako tak musíme získat.
#------------------------------------------------------------------------------
sub vybrat_ramec_a_promitnout_ho_do_evidence
{
    my $anot = shift; # odkaz na pole hashù
    my $sloveso = shift; # index do pole @{$anot}
    my $deti = shift; # odkaz na pole s doplòujícími informacemi o dìtech sloves
    my $subcat = shift; # odkaz na hash se subkategorizaèním slovníkem
    my $evidence = shift; # odkaz na cílové pole
    # Získat seznam rámcù daného slovesa ze slovníku.
    my $ramce = $subcat->{"RAM $anot->[$sloveso]{heslo}"};
    # Vybrat z pole informací o dìtech sloves pouze dìti na¹eho slovesa.
    my @me_deti = grep{$_->{rodic}==$sloveso}(@{$deti});
    # Projít v¹echny rámce slovesa, hledat ten nejlépe zaplnìný.
    my $min_nezaplnenych;
    my $srovnani_min;
    foreach my $ramec (@{$ramce})
    {
        my $vazby = pripravit_ramec_k_porovnani($ramec);
        my $srovnani = porovnat_deti_s_ramcem(\@me_deti, $vazby);
        # Jestli¾e srovnání vy¹lo lépe ne¾ u dosud nejlep¹ího rámce, prohlásit za nejlep¹í tenhle.
        if($min_nezaplnenych eq "" || $srovnani->{n_chybi}<$min_nezaplnenych)
        {
            $min_nezaplnenych = $srovnani->{n_chybi};
            $srovnani_min = $srovnani;
        }
    }
    # Pøipsat nejlep¹í rámec do evidence.
    # Uzlùm, které se podílejí na zaplnìní rámce, nastavit v evidenci 0.
    foreach my $i (@{$srovnani_min->{nalezeno}})
    {
        $evidence->[$i] = 0;
    }
    # Uzlùm, které ode mne ani od nikoho jiného nemají 0, ale mohly by mi pomoci k lep¹ímu zaplnìní, nastavit 1.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($srovnani_min->{chybi}{$deti->[$i]{vznacka}} && $evidence->[$i]!=0)
        {
            $evidence->[$i] = 1;
        }
    }
}



#------------------------------------------------------------------------------
# Zpracuje rámec tak, aby bylo mo¾né s ním porovnat seznam uzlù, které ho mají
# naplnit.
#------------------------------------------------------------------------------
sub pripravit_ramec_k_porovnani
{
    my $ramec = shift; # øetìzec vazeb oddìlených ~~ nebo <INTR>
    # Odstranit z rámce sloveso.
    my $ramec_bez_slovesa = $ramec;
    $ramec_bez_slovesa =~ s/^\S+ //;
    # Pøevést rámec na seznam vazeb. Seznam reprezentovat hashem, pro ka¾dou vazbu poèet výskytù.
    # Rámec "<INTR>" znamená, ¾e jde o nepøechodné sloveso, které nemá ¾ádné vazby.
    my %hash;
    unless($ramec_bez_slovesa eq "<INTR>")
    {
        my @vazby = split(/~~/, $ramec_bez_slovesa);
        # Pøevést pole vazeb na reprezentaèní hash.
        for(my $i = 0; $i<=$#vazby; $i++)
        {
            # Vazby jsou ulo¾eny ve tvaru vznacka/afun. Odstranit analytickou funkci.
            $vazby[$i] =~ s-/.*--;
            $hash{$vazby[$i]}++;
        }
    }
    return \%hash;
}



#------------------------------------------------------------------------------
# Dílèí funkce pro kontrolu valence. Porovná seznam navrhovaných dìtí slovesa
# s rámcem tohoto slovesa.
#
# Vrací:
# - seznam valenèních znaèek, které chybí
# - seznam indexù uzlù, které plní roli argumentù
#
# Mù¾e se stát, ¾e rámec po¾aduje men¹í poèet doplnìní urèitého druhu (napø. N4),
# ne¾ kolik takových doplnìní na slovesu podle návrhu visí. V tom pøípadì je tøeba
# rozhodnout, které z navrhovaných dìtí je to nejlep¹í a ostatní prohlásit za
# volná doplnìní. Za nejlep¹í prohlásíme to dítì, jeho¾ závislosti model pøiøadí
# nejvìt¹í váhu. Pøi rovnosti vah rozhodne vzdálenost dítìte od slovesa: vyhrává
# dítì oddìlené men¹ím poètem jiných sloves, potom bli¾¹í dítì, potom dítì na
# stranì, na které je ménì dal¹ích sloves, potom dítì vpravo.
#
# Pozor, tato funkce nebere v úvahu, ¾e mohou existovat je¹tì jiné rámce tého¾
# slovesa, které by seznam dìtí uspokojil.
#------------------------------------------------------------------------------
sub porovnat_deti_s_ramcem
{
    my $deti = shift; # odkaz na pole hashù o dìtech (obsahují mj. i odkaz do @anot na standardní údaje)
    my $ramec = shift; # odkaz na hash indexovaný valenèními znaèkami, hodnoty jsou poèet po¾adovaných takových vazeb
    # Seøadit dìti sestupnì podle pravdìpodobnosti, ¾e právì ony jsou povinnými doplnìními slovesa.
    # "Pravdìpodobností" se zde nemyslí jen váha podle modelu, ale pøi nerozhodnosti i dal¹í heuristiky.
    my @sdeti = sort
    {
        my $vysledek = $b->{vaha}<=>$a->{vaha};
        unless($vysledek)
        {
            $vysledek = $a->{vnitrni}<=>$b->{vnitrni};
            unless($vysledek)
            {
                $vysledek = $a->{vzdalenost}<=>$b->{vzdalenost};
                unless($vysledek)
                {
                    $vysledek = $a->{vnejsi}<=>$b->{vnejsi};
                    unless($vysledek)
                    {
                        $vysledek = $a->{index}<=>$b->{index};
                    }
                }
            }
        }
        return $vysledek;
    }
    (@{$deti});
    # Vytvoøit si kopii rámce, abychom si v ní mohli èmárat.
    my %ramec = %{$ramec};
    # Procházet dìti a u ka¾dého se zeptat, jestli je povinné (umazáváním pøíslu¹ných znaèek z rámce).
    # PR4 uspokojí pøednostnì po¾adavek na PR4, ale pokud takový po¾adavek není, zkusí uspokojit po¾adavek na N4.
    for(my $i = 0; $i<=$#sdeti; $i++)
    {
        if($ramec{$sdeti[$i]{vznacka}})
        {
            # Poznamenat si, ¾e tento èlen rámce u¾ je naplnìn.
            $ramec{$sdeti[$i]{vznacka}}--;
            # Poznamenat si, ¾e tento uzel u¾ je anga¾ován jako povinné doplnìní.
            $sdeti[$i]{arg} = 1;
        }
        elsif($sdeti[$i]{vznacka} eq "PR4" && $ramec{"N4"})
        {
            # Poznamenat si, ¾e tento èlen rámce u¾ je naplnìn.
            $ramec{"N4"}--;
            # Poznamenat si, ¾e tento uzel u¾ je anga¾ován jako povinné doplnìní.
            $sdeti[$i]{arg} = 1;
        }
    }
    # Sestavit návratové údaje a vrátit je.
    my %srovnani;
    while(my ($klic, $hodnota) = each(%ramec))
    {
        $srovnani{n_chybi} += $hodnota;
    }
    $srovnani{chybi} = \%ramec;
    my @nalezeno = map{$_->{index}}(grep{$_->{arg}}(@sdeti));
    $srovnani{nalezeno} = \@nalezeno;
    return \%srovnani;
}



#==============================================================================
# Pomocné funkce, ze kterých by se èasem mìl vytvoøit samostatný modul pro
# odstínìní zvlá¹tností jazyka nebo znaèení v konkrétním korpusu.
#==============================================================================



#------------------------------------------------------------------------------
# Zjistí z anotace slova, zda jde o sloveso.
#------------------------------------------------------------------------------
sub je_sloveso
{
    my $anot = shift;
    return $anot->{znacka} =~ m/^V/;
}



1;
