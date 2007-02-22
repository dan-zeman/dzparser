#!/usr/bin/perl
# Natrénuje statistiky z treebanku a ulo¾í je.
use parse;
use csts;
use model; # kvùli zjistit_smer_a_delku()
use vystupy;
use ntice;



$starttime = time();
parse::precist_konfig("parser.ini", \%konfig);



# Naèíst seznam subkategorizaèních rámcù sloves.
# Potøebujeme ho, abychom mohli poèítat, kolikrát se která m-znaèka vyskytla
# jako povinné, a kolikrát jako volné doplnìní.
if($konfig{valence})
{
    $konfig{nacteny_subkategorizacni_slovnik} = subkat::cist($konfig{subcat}); # vrátí odkaz na hash se subkategorizaèním slovníkem
}



# Kvùli sní¾ení pamì»ových nárokù lze statistický model rozdìlit do dílù.
# Díly se èíslují od jednièky.
$i_dil = 1;
$konfig{hook_zacatek_cteni} = sub
{
    my $maska = shift;
    my $soubory = shift;
    vypsat("prubeh", "Maska pro jména souborù s daty: $maska\n");
    vypsat("prubeh", "Nalezeno ".($#{$soubory}+1)." souborù.\n");
};
csts::projit_data($konfig{train}, \%konfig);
# Poslat mi mail, ¾e trénink je u konce. Musíme do mailu dát nìjaký existující
# soubor. Staèil by mi sice prázdný mail jen s pøedmìtem zprávy, ale pokud bych
# k tomu chtìl vyu¾ít existující mechanismy, vznikl by mi tím na disku prázdný
# soubor.
vystupy::kopirovat_do_mailu("konfig", "Trenink $vystupy::cislo_instance skoncil");

# Konec.
$stoptime = time();
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "konfig");
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "vysledky");



###############################################################################
# PODPROGRAMY
###############################################################################



#------------------------------------------------------------------------------
# Projde vìtu a zapamatuje si vztahy v ní.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a vìtì
    my $anot = shift; # pole hashù o jednotlivých slovech
    @anot = @{$anot}; # zatím se ukládá jako globální promìnná v main
    # Pøed zpracováním první vìty souboru ohlásit nový soubor.
    if($stav_cteni->{novy_soubor})
    {
        my ($sek, $min, $hod) = localtime(time());
        my $jmeno_souboru_do_hlaseni = $stav_cteni->{soubor};
        $jmeno_souboru_do_hlaseni =~ s-^.*/([^/]*)$-$1-;
        $jmeno_souboru_do_hlaseni =~ s/\.(?:csts|amm)$//i;
        vypsat("prubeh", parse::cas()." Otevírá se soubor $jmeno_souboru_do_hlaseni\n");
    }
    # Nauèit se n-tice znaèek, které le¾í vedle sebe a tvoøí komponentu stromu.
    for(my $i = 2; $i<=10; $i++)
    {
#        ntice::ucit($i);
    }
    # Vynechat vìty se závadným obsahem (promìnná $vynechat_vetu se nastavuje
    # pøi naèítání slova).
    unless($vynechat_vetu)
    {
        # Ohlásit na výstup èíslo zpracovávané vìty.
        $veta++;
        if($veta-$ohlasena_veta==100 || $stav_cteni->{posledni_veta})
        {
            my $n_udalosti = int(keys(%stat));
            vypsat("prubeh", parse::cas()." Zpracovává se vìta $veta.\n");
            $ohlasena_veta = $veta;
            # Jestli¾e jsme u¾ pøeèetli urèitý poèet událostí, ulo¾it dosud
            # nasbíranou statistiku, vyprázdnit pamì» a od této vìty zaèít
            # nanovo.
            if($konfig{split}>0 && $n_udalosti>=$konfig{split} || $stav_cteni->{posledni_veta})
            {
                # Jméno souboru se statistikou.
                my $jmeno = $konfig{prac}."/".$konfig{stat};
                if($konfig{split}>0)
                {
                    vypsat("prubeh", parse::cas()." Konec $i_dil. dílu.\n");
                    $jmeno .= $i_dil;
                }
                # Ulo¾it dosud nasbíranou statistiku.
                ulozit(\%stat, $jmeno);
                unless($stav_cteni->{posledni_veta})
                {
                    # Uvolnit pamì» pro nový díl.
                    vypsat("prubeh", parse::cas()." Uvolòuje se pamì».\n");
                    undef(%stat);
                }
                $i_dil++;
            }
        }
        # Zapamatovat si nejdel¹í vìtu.
        if($#{$anot}>$maxn_slov)
        {
            $maxn_slov = $#{$anot};
        }
        if($#{$anot}>0) # Pokud nezaèínáme èíst první vìtu.
        {
            #!!!
            # Alternující èásti kódu.
            my @alt;
            $alt[0] = 1; # coordmember je (0) dite rodice se spravnym afunem (1) i vzdalenejsi potomek (treba pod predlozkou), ale zato clen (pokud je tedy dite korene koordinace, ale neni jeji clen, neni coordmember)
            $alt[1] = 0; # ke koordinacim pridat apozice
            $alt[2] = 1; # v beznych zavislostech zdedene znacky
            $alt[3] = 0; # zaznamenavat koordinacni udalosti
            # (jinak se zaznamenavaji pouze zavislosti)
            #!!!
            # Dokud existuje mo¾nost, ¾e pøi procházení koordinací se budou
            # upravovat $anot->[$i]{znacka} a $anot->[$i]{afun}, musejí se koordinace zpracovávat pøed
            # závislostmi, ve kterých se tohle vyu¾ije. A¾ se bude spoléhat jen
            # na zdìdìné znaèky, bude mo¾né poøadí otoèit.
            if($konfig{koordinace})
            {
                projit_koordinace($anot, \@alt);
            }
            # Projít vìtu a posbírat statistiky.
            for(my $i = 1; $i<=$#{$anot}; $i++)
            {
                zjistit_udalosti_slovo($i, $anot->[$i]{rodic_vzor}, \@alt, $anot);
            }
            # Spoèítat lokální konflikty.
            spocitat_lokalni_konflikty($anot);
            # U krátkých vìt si zapamatovat celý strom.
            projit_kratkou_vetu($anot);
        }
    }
}



#------------------------------------------------------------------------------
# Zjistí trénovací události o jednom slovì (to neznamená, ¾e kvùli nìmu nebude
# potøebovat projít v¹echna ostatní slova vìty).
#------------------------------------------------------------------------------
sub zjistit_udalosti_slovo
{
    my $z = shift;
    my $r = shift;
    my $alt = shift; # jen odkaz na pole
    my $anot = shift; # jen odkaz na pole
    # Vynechat uzly, jejich¾ rodiè øídí koordinaci. Buï jsou èleny koordinace a
    # jejich vztah k rodièi není závislost. Nebo závisejí na koordinaci, ta by
    # ale místo znaèky souøadící spojky mìla být reprezentována znaèkou
    # typického èlena, tak¾e závislost na koordinaci vy¾aduje zvlá¹tní
    # zacházení.
    my $coordmember;
    if($konfig{koordinace})
    {
        if(!$alt->[0])
        {
            if(!$alt->[1])
            {
                $coordmember = ($anot->[$r]{afun}=~m/Coord/);
            }
            else
            {
                $coordmember = ($anot->[$r]{afun}=~m/(?:Coord|Apos)/);
            }
        }
        else
        {
            $coordmember = $anot->[$z]{coordmember};
        }
    }
    # Odli¹it èleny koordinací od závislých uzlù.
    if(!$coordmember)
    {
        if($konfig{koordinace})
        {
            # Vynechat uzly, které samy øídí koordinaci. I vùèi svým nadøízeným
            # by koordinace mìla být reprezentována nìèím jiným ne¾ znaèkou
            # souøadící spojky.
            my $coordroot;
            if(!$alt->[1])
            {
                $coordroot = $anot->[$z]{afun}=~m/Coord/;
            }
            else
            {
                $coordroot = $anot->[$z]{afun}=~m/(?:Coord|Apos)/;
            }
            if($coordroot)
            {
                next;
            }
        }
        # Doplòkové parametry: smìr hrany a vzdálenost.
        my $rs = $anot->[$r]{slovo};
        my $zs = $anot->[$z]{slovo};
        my $rz;
        my $zz;
        # Pou¾ít vlastní, nebo zdìdìné znaèky?
        if(!$alt->[2] || !$konfig{koordinace})
        {
            $rz = $anot->[$r]{uznacka};
            $zz = $anot->[$z]{uznacka};
        }
        else
        {
            $rz = $anot->[$r]{mznpodstrom};
            $zz = $anot->[$z]{mznpodstrom};
        }
        my ($smer, $delka) = model::zjistit_smer_a_delku($r, $z);
        # Pokusné volitelné roz¹íøení: má uzel sourozence stejného druhu?
        my $zarlivost = $konfig{zarlivost} ? (ma_sourozence_stejneho_druhu($anot, $r, $z) ? " N" : " Z") : "";
        ud("OSS $rs $zs $smer $delka");
        ud("OZZ $rz $zz $smer $delka$zarlivost");
        ###!!! Následující druhy událostí se momentálnì nevyu¾ívají pøi parsingu,
        # tak nemá smysl s nimi prodlu¾ovat uèení a nafukovat statistiku.
#        ud("OSZ $rs $zz $smer $delka");
#        ud("OZS $rz $zs $smer $delka");
#        ud("ZSS $rs $zs");
#        ud("ZZZ $rz $zz");
#        ud("ZSZ $rs $zz");
#        ud("ZZS $rz $zs");
        if($konfig{"pseudoval"})
        {
            if($rz =~ m/^V/)
            {
                my $rrr = $rz.$anot->[$r]{heslo};
                $rrr =~ s/_.*//;
                ud("ZPV $rrr $zz $smer $delka");
            }
        }
    }
}



#------------------------------------------------------------------------------
# Projde vìtu a zaeviduje události související s koordinacemi.
# Parametry: @anot. Do znaèek a afunù zapisuje!
# $alt_coordmember: 1 = èlen koordinace se pozná novým zpùsobem
# $alt_apos: 1 = ke koordinacím pøidat apozice
# $alt_znvkor: 1 = události KZZ se sestavují podle zdìdìných znaèek v koøeni;
# toté¾ platí pro morfologickou(é) znaèku(y), která(é) reprezentuje(í) koordi-
# naci v jejích závislostních vztazích s okolím.
#------------------------------------------------------------------------------
sub projit_koordinace
{
    my $anot = shift; # odkaz na pole hashù
    my $alt = shift; # odkaz na pole
    my $alt_znvkor = shift;
    # Projít koordinace a posbírat statistiky o nich.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Zapamatovat si výskyty ka¾dého slova, aby bylo mo¾né poèítat,
        # v kolika procentech toto slovo øídilo koordinaci.
        ud("USS $anot->[$i]{slovo}");
        ud("USZ $anot->[$i]{slovo}/$anot->[$i]{uznacka}");
        ud("UZZ $anot->[$i]{uznacka}");
        my $koren;
        if($alt->[1])
        {
            $koren = $anot->[$i]{afun} =~ m/(?:Coord|Apos)/;
        }
        else
        {
            $koren = $anot->[$i]{afun} =~ m/Coord/;
        }
        if($koren)
        {
            # Zapamatovat si pro ka¾dé slovo, kolikrát øídilo koord.
            ud("KJJ $anot->[$i]{slovo}");
            my $n_clenu; # Poèet èlenù koordinace.
            my @koortypy; # Potøeba jen kdy¾ !$alt->[3].
            for(my $j = 1; $j<=$#{$anot}; $j++)
            {
                my $clen;
                if($alt->[0])
                {
                    $clen = $anot->[$j]{coordmember};
                }
                else
                {
                    if($alt->[1])
                    {
                        $clen = $anot->[$j]{afun} =~ m/_(?:Co|Ap)$/;
                    }
                    else
                    {
                        $clen = $anot->[$j]{afun} =~ m/_Co$/;
                    }
                }
                if($anot->[$j]{rodic_vzor}==$i && $clen)
                {
                    # Zapamatovat si pro ka¾dé heslo, kolikrát øídilo
                    # víceèetnou koordinaci.
                    if(++$n_clenu==3)
                    {
                        ud("KJ3 $anot->[$i]{slovo}");
                    }
                    if($alt->[3])
                    {
                        # Znaèky v¹ech èlenù koordinace jsou posbírané u
                        # koøene.
                        my $mz = $anot->[$j]{mznpodstrom};
                        my $oz = $anot->[$i]{mznpodstrom};
                        # Vyhodit z nich první výskyt mojí znaèky - zastupuje
                        # mne sama. Nemù¾eme to udìlat pomocí regulárních
                        # výrazù, proto¾e bychom museli zne¹kodnit nejen
                        # svislítka, ale i závorky a jiné znaky ve znaèkách.
                        my @mz = split(/\|/, $mz);
                        my @oz = split(/\|/, $oz);
                        for(my $k = 0; $k<=$#mz; $k++)
                        {
                            for(my $l = 0; $l<=$#oz; $l++)
                            {
                                if($oz[$l] eq $mz[$k])
                                {
                                    splice(@oz, $l, 1);
                                    last;
                                }
                            }
                        }
                        $oz = join("|", @oz);
                        # Nyní u¾ lze ohlásit koordinaèní událost. Roznásobení
                        # zbývajících znaèek s tìmi mými zajistí pøímo
                        # procedura ud().
                        ud("KZZ $mz $oz");
                    }
                    else
                    {
                        # Projít v¹echny dosud zji¹tìné èleny a spárovat je se
                        # mnou.
                        for(my $k = 0; $k<=$#koortypy; $k++)
                        {
                            ud("KZZ $anot->[$j]{uznacka} $koortypy[$k]");
                            ud("KZZ $koortypy[$k] $anot->[$j]{uznacka}");
                        }
                        $koortypy[++$#koortypy] = $anot->[$j]{uznacka};
                    }
                }
            }
            if(!$alt->[2])
            {
                # Zru¹it koordinaci, aby byl vidìt typ èlenù.
                $anot->[$i]{afun} = "zpracovana koordinace";
                $anot->[$i]{uznacka} = $koortypy[0];
            }
        }
    }
}



#------------------------------------------------------------------------------
# Kontextové trénování.
# Projde vìtu a pro ka¾dé slovo si zapamatuje jeho skuteèné zavì¹ení
# v konkurenci s ka¾dým mo¾ným jiným zavì¹ením v okolí.
#------------------------------------------------------------------------------
sub spocitat_lokalni_konflikty
{
    my $anot = shift; # odkaz na pole hashù
    # Bohu¾el je asi nìkde v této funkci chyba: asi se pøistupuje k prvkùm za
    # souèasnou hranicí pole @anot. Tímpádem se nemù¾eme spolehnout na délku
    # pole a øídit s její pomocí cykly. Pokud chybu neopravíme, bude bezpeènìj¹í
    # hned na zaèátku délku vìty zafixovat a na konci ji vrátit.
    my $n = $#{$anot};
    for(my $i = 1; $i<=$n; $i++)
    {
        # Pokud je slovo zavì¹eno doleva, zapamatovat si pora¾ené konkurenty napravo.
        if($anot->[$i]{rodic_vzor}<$i)
        {
            # Jde o závislost, nebo koordinaci?
            my $vazba = ($anot->[$i]{afun}=~m/_Co/ ? "C " : "").$anot->[zjistit_vazbu($i)]{uznacka};
            # Projít konkurenty.
            my $j = $i+1;
            do {
                # Zapamatovat si konkurenèní závislost.
                ud("LOK $anot->[$i]{uznacka} L $vazba P $anot->[$j]{uznacka} L");
                # Pokud $j øídí kooridnaci, zapamatovat si ji také.
                if($anot->[$j]{afun}=~m/Coord/)
                {
                    for(my $k = $j+1; $k<=$n; $k++)
                    {
                        if($anot->[$k]{rodic_vzor}==$j && $anot->[$k]{afun}=~m/_Co$/ &&
                        $anot->[$k]{afun}!~m/Coord/) # Slo¾ené koordinace je lep¹í
                        # vynechat ne¾ správnì procházet.
                        {
                            ud("LOK $anot->[$i]{uznacka} L $vazba P C $anot->[$k]{uznacka} L");
                            last;
                        }
                    }
                }
                # Pokud $j neøídí koordinaci, ale teoreticky by mohlo, proto¾e
                # u¾ jsme ho døíve vidìli v pozici koordinaèní spojky,
                # zapamatovat si i v¹echny potenciální koordinace.
                my $n_jako_koord = $stat{"KJJ $anot->[$j]{slovo}"};
                if($n_jako_koord>0)
                {
                    my $n_jako_cokoli = $stat{"USS $anot->[$j]{slovo}"};
                    for(my $k = $j+1; $k>=0 && $k<=$n && $k>$j; $k = $anot->[$k]{rodic_vzor})
                    {
                        ud("LOK $anot->[$i]{uznacka} L $vazba P C $anot->[$k]{uznacka} L",
                        $n_jako_koord/$n_jako_cokoli);
                    }
                }
                # Pokud má $j dítì nalevo ode mì, skonèit.
                for(my $k = $i-1; $k>0; $k--)
                {
                    if($anot->[$k]{rodic_vzor}==$j)
                    {
                        $j = 0;
                        last;
                    }
                }
                $j = $anot->[$j]{rodic_vzor};
            } while($j>$i);
        }
        # Pokud je zavì¹eno doprava, zapamatovat si pora¾ené konkurenty nalevo.
        else
        {
            # Jde o závislost, nebo koordinaci?
            my $vazba = ($anot->[$i]{afun}=~m/_Co/ ? "C " : "").$anot->[zjistit_vazbu($i)]{uznacka};
            # Projít konkurenty.
            my $j = $i-1;
            do {
                # Zapamatovat si konkurenèní závislost.
                ud("LOK $anot->[$i]{uznacka} L $anot->[$j]{uznacka} P $vazba P");
                # Pokud $j øídí kooridnaci, zapamatovat si ji také.
                if($anot->[$j]{afun}=~m/Coord/)
                {
                    for(my $k = $j-1; $k>0 && $k<=$n; $k--)
                    {
                        if($anot->[$k]{rodic_vzor}==$j && $anot->[$k]{afun}=~m/_Co$/ &&
                        $anot->[$k]{afun}!~m/Coord/) # Slo¾ené koordinace je lep¹í
                        # vynechat ne¾ správnì procházet.
                        {
                            ud("LOK $anot->[$i]{uznacka} L C $anot->[$k]{uznacka} P $vazba P");
                            last;
                        }
                    }
                }
                # Pokud $j neøídí koordinaci, ale teoreticky by mohlo, proto¾e
                # u¾ jsme ho døíve vidìli v pozici koordinaèní spojky,
                # zapamatovat si i v¹echny potenciální koordinace.
                my $n_jako_koord = $stat{"KJJ $anot->[$j]{slovo}"};
                if($n_jako_koord>0)
                {
                    my $n_jako_cokoli = $stat{"USS $anot->[$j]{slovo}"};
                    for(my $k = $j-1; $k>=0 && $k<=$n && $k<$j; $k = $anot->[$k]{rodic_vzor})
                    {
                        ud("LOK $anot->[$i]{uznacka} L C $anot->[$k]{uznacka} P $vazba P",
                        $n_jako_koord/$n_jako_cokoli);
                    }
                }
                # Pokud má $j dítì napravo ode mì, skonèit.
                for(my $k = $i+1; $k<=$n; $k++)
                {
                    if($anot->[$k]{rodic_vzor}==$j)
                    {
                        $j = 0;
                        last;
                    }
                }
                $j = $anot->[$j]{rodic_vzor};
            } while($j<$i && $j>0);
        }
    }
    # Oprava chyby zpùsobené neopodstatnìnými pøístupy k prvkùm mimo pole.
    $#{$anot} = $n;
}



#------------------------------------------------------------------------------
# Pokud je vìta krátká, ulo¾í celý její strom.
#------------------------------------------------------------------------------
sub projit_kratkou_vetu
{
    my $anot = shift; #odkaz na pole hashù
    # Zkontrolovat, ¾e je vìta dostateènì krátká.
    if($#{$anot}>8)
    {
        return;
    }
    # Vytvoøit událost: morfologický vzor a strom.
    my $vzor;
    my $strom;
    my $i;
    for($i = 1; $i<=$#{$anot}; $i++)
    {
        if($i>1)
        {
            $vzor .= "~";
            $strom .= ",";
        }
        $vzor .= $anot->[$i]{uznacka};
        $strom .= $anot->[$i]{rodic_vzor};
    }
    # Ulo¾it vìtu a její strom mezi události.
    ud("VET $vzor $strom");
}



#------------------------------------------------------------------------------
# Zapamatuje si výskyt nìèeho (událost). V pøípadì, ¾e nìkterý prvek události
# (napø. morfologická znaèka øídícího uzlu) je nejednoznaèný (tj. skládá se
# z více hodnot oddìlených svislítkem), nahradí událost nìkolika jednoznaènými
# událostmi a ka¾dé z nich pøiøadí pomìrnou èást výskytu.
#------------------------------------------------------------------------------
sub ud
{
    my $ud = shift;
    my $n = shift;
    $n = 1 if($n eq "");
    # Rozdìlit alternativy do samostatných událostí.
    my @alt; # seznam alternativních událostí
    if(!$main::konfig{morfologicke_alternativy})
    {
        $alt[0] = $ud;
    }
    else
    {
        @alt = model::rozepsat_alternativy($ud);
    }
    # Ka¾dé dílèí události zapoèítat pomìrnou èást výskytu.
    my $dil = $n/($#alt+1);
    for(my $i = 0; $i<=$#alt; $i++)
    {
        $stat{$alt[$i]} += $dil;
        # Koordinace zapoèítat dvakrát, je to jakési primitivní zvý¹ení jejich
        # váhy.
        if($alt[$i] =~ m/^KZZ/)
        {
            $stat{$alt[$i]} += 2*$dil;
        }
    }
}



#------------------------------------------------------------------------------
# Najde k uzlu jeho øídící uzel a vrátí jeho index. Pokud øídící uzel øídí
# koordinaci, vrátí místo nìj index prvního èlena této koordinace ve vìtì.
# Je na volajícím, aby vztah interpretoval jako koordinaci (závislý uzel má
# afun _Co), nebo jako závislost na koordinaci (závislý uzel má jiný afun).
#
# Pou¾ívá globální pole @anot.
#------------------------------------------------------------------------------
sub zjistit_vazbu
{
    my $z = shift;
    my $anot = \@main::anot;
    my $r = $anot->[$z]{rodic_vzor};
    my $i;
    if($anot->[$r]{afun}!~m/Coord/)
    {
        # Obyèejná závislost.
        return $r;
    }
    else
    {
        # Koordinace nebo závislost na koordinaci.
        for($i = 1; $i<=$#{$anot}; $i++)
        {
            if($anot->[$i]{rodic_vzor}==$r && $anot->[$i]{afun}=~m/_Co/ && $i!=$z)
            {
                # Ale pozor, mohla by to být dal¹í vnoøená koordinace!
                if($anot->[$i]{afun}=~m/Coord/)
                {
                    $r = $i;
                    $i = 0;
                }
                else
                {
                    return $i;
                }
            }
        }
        # Pokud z nìjakého dùvodu nebyl nalezen jiný èlen koordinace, vrátit
        # pøece jenom index koordinaèní spojky.
        return $r;
    }
}



#------------------------------------------------------------------------------
# Ulo¾í natrénované statistiky.
#------------------------------------------------------------------------------
sub ulozit
{
    vypsat("prubeh", parse::cas()." Ukládá se statistika.\n");
    # Kvùli efektivitì se ha¹ovací tabulka pøedává odkazem (volání
    # ulozit(\%stat)). Ve volané funkci se na ni pak dá dostat dvìma zpùsoby:
    # na celou tabulku najednou $%statref a na prvek $statref->{"ahoj"}.
    my $statref = $_[0];
    my $soubor = $_[1];
    my @stat = keys(%$statref);
    my $n = $#stat+1;
    vypsat("prubeh", parse::cas()." Statistika obsahuje $n událostí.\n");
    #    open(SOUBOR, ">$soubor");
    $n = 1 if($n==0); # kvùli dìlení pøi hlá¹ení pokroku
    for(my $i = 0; $i<=$#stat; $i++)
    {
        vypsat("stat", "$stat[$i]\t$statref->{$stat[$i]}\n");
    }
    #    close(SOUBOR);
}



#------------------------------------------------------------------------------
# Pro danou dvojici r-z zjistí, zda na r je¹tì visí jiný uzel se stejnou
# znaèkou jako z.
#------------------------------------------------------------------------------
sub ma_sourozence_stejneho_druhu
{
    my $anot = shift;
    my $r = shift;
    my $z = shift;
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($i!=$z && $anot->[$i]{rodic_vzor}==$r && $anot->[$i]{uznacka} eq $anot->[$z]{uznacka})
        {
            return 1;
        }
    }
    return 0;
}
