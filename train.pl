#!/usr/bin/perl
# Natrénuje statistiky z treebanku a uloží je.
use utf8;
use Getopt::Long;
use parse;
use csts;
use model; # kvůli zjistit_smer_a_delku()
use vystupy;
use ntice;



$starttime = time();
my $inisoubor = "parser.ini"; # jméno souboru s konfigurací
# train.pl --i parser2.ini
GetOptions('ini=s' => \$inisoubor);
parse::precist_konfig($inisoubor, \%konfig);



# Načíst seznam subkategorizačních rámců sloves.
# Potřebujeme ho, abychom mohli počítat, kolikrát se která m-značka vyskytla
# jako povinné, a kolikrát jako volné doplnění.
if($konfig{valence})
{
    $konfig{nacteny_subkategorizacni_slovnik} = subkat::cist($konfig{subcat}); # vrátí odkaz na hash se subkategorizačním slovníkem
}



# Kvůli snížení paměťových nároků lze statistický model rozdělit do dílů.
# Díly se číslují od jedničky.
$i_dil = 1;
$konfig{hook_zacatek_cteni} = sub
{
    my $maska = shift;
    my $soubory = shift;
    vypsat("prubeh", "Maska pro jména souborů s daty: $maska\n");
    vypsat("prubeh", "Nalezeno ".($#{$soubory}+1)." souborů.\n");
};
csts::projit_data($konfig{train}, \%konfig, \&zpracovat_vetu);
vypsat("prubeh", "Počet vět  = $veta\n");
vypsat("prubeh", "Počet slov = $slovo\n");
# Teď ještě natrénovat modely n-tic. Nemohli jsme to dělat všechno při jednom
# průchodu dat, protože by nám nemusela stačit paměť. N-tic sice přežije jen
# kolem 7000, ale během trénování jich musíme mít v paměti přes 5000000.
if($konfig{ntice})
{
    %stat = ();
    $veta = 0;
    $slovo = 0;
    $ohlasena_veta = 0;
    csts::projit_data($konfig{train}, \%konfig, \&zpracovat_vetu_ntice);
    ntice::vypsat_do_stat();
}
# Poslat mi mail, že trénink je u konce. Musíme do mailu dát nějaký existující
# soubor. Stačil by mi sice prázdný mail jen s předmětem zprávy, ale pokud bych
# k tomu chtěl využít existující mechanismy, vznikl by mi tím na disku prázdný
# soubor.
if($vystupy::cislo_instance)
{
    vystupy::kopirovat_do_mailu("konfig", "Trenink $vystupy::cislo_instance skoncil");
}

# Konec.
$stoptime = time();
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "konfig");
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "vysledky") if($konfig{rezim} eq "debug");



###############################################################################
# PODPROGRAMY
###############################################################################



#------------------------------------------------------------------------------
# Projde větu a zapamatuje si vztahy v ní.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a větě
    my $anot = shift; # pole hashů o jednotlivých slovech
    # Před zpracováním první věty souboru ohlásit nový soubor.
    # (Test, zda jsme na začátku souboru, je uvnitř.)
    vypsat_jmeno_souboru($stav_cteni);
    # Vynechat věty se závadným obsahem (proměnná $vynechat_vetu se nastavuje
    # při načítání slova) a věty nad rámec požadovaného rozsahu.
    return if($vynechat_vetu || $konfig{max_trenovacich_vet} && $veta>=$konfig{max_trenovacich_vet});
    # Ohlásit na výstup číslo zpracovávané věty.
    $veta++ if($#{$anot}>0);
    $slovo += $#{$anot};
    $ohlasena_veta = ohlasit_vetu($stav_cteni, $ohlasena_veta, $veta);
    # Zapamatovat si nejdelší větu.
    if($#{$anot}>$maxn_slov)
    {
        $maxn_slov = $#{$anot};
    }
    if($#{$anot}>0) # Pokud nezačínáme číst první větu.
    {
        #!!!
        # Alternující části kódu.
        my @alt;
        $alt[0] = 1; # coordmember je (0) dite rodice se spravnym afunem (1) i vzdalenejsi potomek (treba pod predlozkou), ale zato clen (pokud je tedy dite korene koordinace, ale neni jeji clen, neni coordmember)
        $alt[1] = 0; # ke koordinacim pridat apozice
        $alt[2] = 1; # v beznych zavislostech zdedene znacky
        $alt[3] = 0; # zaznamenavat koordinacni udalosti
        # (jinak se zaznamenavaji pouze zavislosti)
        #!!!
        # Dokud existuje možnost, že při procházení koordinací se budou
        # upravovat $anot->[$i]{znacka} a $anot->[$i]{afun}, musejí se koordinace zpracovávat před
        # závislostmi, ve kterých se tohle využije. Až se bude spoléhat jen
        # na zděděné značky, bude možné pořadí otočit.
        if($konfig{koordinace})
        {
            projit_koordinace($anot, \@alt);
        }
        # Projít větu a posbírat statistiky.
        for(my $i = 1; $i<=$#{$anot}; $i++)
        {
            zjistit_udalosti_slovo($i, $anot->[$i]{rodic_vzor}, \@alt, $anot);
        }
        # Spočítat lokální konflikty.
        spocitat_lokalni_konflikty($anot);
        # Zjistit rámce všech řídících uzlů (včetně volitelných doplnění).
        projit_ramce($anot);
        # U krátkých vět si zapamatovat celý strom.
        projit_kratkou_vetu($anot);
    }
    # Uložit statistiku, jestliže je tohle poslední věta, popř. poslední, která se vejde do omezení.
    $i_dil = ulozit_statistiku_pokud_je_to_potreba($stav_cteni, $veta, $i_dil);
}



#------------------------------------------------------------------------------
# Projde větu, najde v ní n-tice a zapamatuje si je.
#------------------------------------------------------------------------------
sub zpracovat_vetu_ntice
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a větě
    my $anot = shift; # pole hashů o jednotlivých slovech
    # Před zpracováním první věty souboru ohlásit nový soubor.
    # (Test, zda jsme na začátku souboru, je uvnitř.)
    vypsat_jmeno_souboru($stav_cteni);
    # Vynechat věty se závadným obsahem (proměnná $vynechat_vetu se nastavuje
    # při načítání slova) a věty nad rámec požadovaného rozsahu.
    return if($vynechat_vetu || $konfig{max_trenovacich_vet} && $veta>=$konfig{max_trenovacich_vet});
    # Ohlásit na výstup číslo zpracovávané věty.
    $veta++ if($#{$anot}>0);
    $slovo += $#{$anot};
    $ohlasena_veta = ohlasit_vetu($stav_cteni, $ohlasena_veta, $veta, "N-tice: ");
    for(my $n = 2; $n<=10; $n++)
    {
        ntice::ucit($n, $anot);
    }
}



#------------------------------------------------------------------------------
# Vypíše do průběhu jméno souboru, který právě čteme.
#------------------------------------------------------------------------------
sub vypsat_jmeno_souboru
{
    my $stav_cteni = shift;
    if($stav_cteni->{novy_soubor})
    {
        my ($sek, $min, $hod) = localtime(time());
        my $jmeno_souboru_do_hlaseni = $stav_cteni->{soubor};
        $jmeno_souboru_do_hlaseni =~ s-^.*/([^/]*)$-$1-;
        $jmeno_souboru_do_hlaseni =~ s/\.(?:csts|amm)$//i;
        vypsat("prubeh", parse::cas()." Otevírá se soubor $jmeno_souboru_do_hlaseni\n");
    }
}



#------------------------------------------------------------------------------
# Vypíše do průběhu číslo věty, kterou právě zpracováváme. Vrátí číslo věty,
# pokud ji ohlásil, jinak vrátí číslo naposledy ohlášené věty.
#------------------------------------------------------------------------------
sub ohlasit_vetu
{
    my $stav_cteni = shift;
    my $ohlasena_veta = shift;
    my $veta = shift;
    my $prubeh = shift;
    if($veta-$ohlasena_veta==100 ||
       $stav_cteni->{posledni_veta} ||
       ($konfig{max_trenovacich_vet} && $veta==$konfig{max_trenovacich_vet}))
    {
        vypsat("prubeh", parse::cas()." ${prubeh}Zpracovává se věta $veta.\n");
        $ohlasena_veta = $veta;
    }
    return $ohlasena_veta;
}



#------------------------------------------------------------------------------
# Zjistit, zda je potřeba uložit statistiku, a v případě potřeby to udělá.
#------------------------------------------------------------------------------
sub ulozit_statistiku_pokud_je_to_potreba
{
    my $stav_cteni = shift;
    my $veta = shift; # číslo zpracovávané věty
    my $i_dil = shift;
    # %stat: globální proměnná
    my $konfig = \%main::konfig;
    # Jestliže jsme už přečetli určitý počet událostí, uložit dosud nasbíranou
    # statistiku, vyprázdnit paměť a od příští věty začít nanovo.
    my $n_udalosti = int(keys(%stat));
    if($konfig->{split}>0 && $n_udalosti>=$konfig->{split} ||
       $konfig->{max_trenovacich_vet} && $veta==$konfig->{max_trenovacich_vet} ||
       $stav_cteni->{posledni_veta})
    {
        # Jméno souboru se statistikou.
        my $jmeno = $konfig->{prac}."/".$konfig->{stat};
        if($konfig->{split})
        {
            vypsat("prubeh", parse::cas()." Konec $i_dil. dílu.\n");
            $jmeno .= $i_dil;
        }
        # Uložit dosud nasbíranou statistiku.
        ulozit(\%stat, $jmeno);
        unless($stav_cteni->{posledni_veta})
        {
            # Uvolnit paměť pro nový díl.
            vypsat("prubeh", parse::cas()." Uvolňuje se paměť.\n");
            undef(%stat);
        }
        $i_dil++;
    }
    return $i_dil;
}



#------------------------------------------------------------------------------
# Zjistí trénovací události o jednom slově (to neznamená, že kvůli němu nebude
# potřebovat projít všechna ostatní slova věty).
#------------------------------------------------------------------------------
sub zjistit_udalosti_slovo
{
    my $z = shift;
    my $r = shift;
    my $alt = shift; # jen odkaz na pole
    my $anot = shift; # jen odkaz na pole
    # Vynechat uzly, jejichž rodič řídí koordinaci. Buď jsou členy koordinace a
    # jejich vztah k rodiči není závislost. Nebo závisejí na koordinaci, ta by
    # ale místo značky souřadící spojky měla být reprezentována značkou
    # typického člena, takže závislost na koordinaci vyžaduje zvláštní
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
    # Odlišit členy koordinací od závislých uzlů.
    if(!$coordmember)
    {
        if($konfig{koordinace})
        {
            # Vynechat uzly, které samy řídí koordinaci. I vůči svým nadřízeným
            # by koordinace měla být reprezentována něčím jiným než značkou
            # souřadící spojky.
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
        # Doplňkové parametry: směr hrany a vzdálenost.
        my $rs = $anot->[$r]{slovo};
        my $zs = $anot->[$z]{slovo};
        my $rz;
        my $zz;
        # Použít vlastní, nebo zděděné značky?
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
        my ($smer, $delka) = model::zjistit_smer_a_delku($anot, $r, $z);
        # Pokusné volitelné rozšíření: má uzel sourozence stejného druhu?
        my $zarlivost = $konfig{zarlivost} ? (ma_sourozence_stejneho_druhu($anot, $r, $z) ? " N" : " Z") : "";
        ud("OSS $rs $zs $smer $delka");
        ud("OZZ $rz $zz $smer $delka$zarlivost");
        ud("OSZ $rs $zz $smer $delka");
        ud("OZS $rz $zs $smer $delka");
        ud("ZSS $rs $zs");
        ud("ZZZ $rz $zz");
        ud("ZSZ $rs $zz");
        ud("ZZS $rz $zs");
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
# Projde větu a zaeviduje události související s koordinacemi.
# Parametry: @anot. Do značek a afunů zapisuje!
# $alt_coordmember: 1 = člen koordinace se pozná novým způsobem
# $alt_apos: 1 = ke koordinacím přidat apozice
# $alt_znvkor: 1 = události KZZ se sestavují podle zděděných značek v kořeni;
# totéž platí pro morfologickou(é) značku(y), která(é) reprezentuje(í) koordi-
# naci v jejích závislostních vztazích s okolím.
#------------------------------------------------------------------------------
sub projit_koordinace
{
    my $anot = shift; # odkaz na pole hashů
    my $alt = shift; # odkaz na pole
    my $alt_znvkor = shift;
    # Projít koordinace a posbírat statistiky o nich.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Zapamatovat si výskyty každého slova, aby bylo možné počítat,
        # v kolika procentech toto slovo řídilo koordinaci.
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
            # Zapamatovat si pro každé slovo, kolikrát řídilo koord.
            ud("KJJ $anot->[$i]{slovo}");
            my $n_clenu; # Počet členů koordinace.
            my @koortypy; # Potřeba jen když !$alt->[3].
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
                    # Zapamatovat si pro každé heslo, kolikrát řídilo
                    # vícečetnou koordinaci.
                    if(++$n_clenu==3)
                    {
                        ud("KJ3 $anot->[$i]{slovo}");
                    }
                    if($alt->[3])
                    {
                        # Značky všech členů koordinace jsou posbírané u
                        # kořene.
                        my $mz = $anot->[$j]{mznpodstrom};
                        my $oz = $anot->[$i]{mznpodstrom};
                        # Vyhodit z nich první výskyt mojí značky - zastupuje
                        # mne sama. Nemůžeme to udělat pomocí regulárních
                        # výrazů, protože bychom museli zneškodnit nejen
                        # svislítka, ale i závorky a jiné znaky ve značkách.
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
                        # Nyní už lze ohlásit koordinační událost. Roznásobení
                        # zbývajících značek s těmi mými zajistí přímo
                        # procedura ud().
                        ud("KZZ $mz $oz");
                    }
                    else
                    {
                        # Projít všechny dosud zjištěné členy a spárovat je se
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
                # Zrušit koordinaci, aby byl vidět typ členů.
                $anot->[$i]{afun} = "zpracovana koordinace";
                $anot->[$i]{uznacka} = $koortypy[0];
            }
        }
    }
}



#------------------------------------------------------------------------------
# Kontextové trénování.
# Projde větu a pro každé slovo si zapamatuje jeho skutečné zavěšení
# v konkurenci s každým možným jiným zavěšením v okolí.
#------------------------------------------------------------------------------
sub spocitat_lokalni_konflikty
{
    my $anot = shift; # odkaz na pole hashů
    # Bohužel je asi někde v této funkci chyba: asi se přistupuje k prvkům za
    # současnou hranicí pole @anot. Tímpádem se nemůžeme spolehnout na délku
    # pole a řídit s její pomocí cykly. Pokud chybu neopravíme, bude bezpečnější
    # hned na začátku délku věty zafixovat a na konci ji vrátit.
    my $n = $#{$anot};
    for(my $i = 1; $i<=$n; $i++)
    {
        # Pokud je slovo zavěšeno doleva, zapamatovat si poražené konkurenty napravo.
        if($anot->[$i]{rodic_vzor}<$i)
        {
            # Jde o závislost, nebo koordinaci?
            my $vazba = ($anot->[$i]{afun}=~m/_Co/ ? "C " : "").$anot->[zjistit_vazbu($anot, $i)]{uznacka};
            # Projít konkurenty.
            my $j = $i+1;
            do {
                # Zapamatovat si konkurenční závislost.
                ud("LOK $anot->[$i]{uznacka} L $vazba P $anot->[$j]{uznacka} L");
                # Pokud $j řídí kooridnaci, zapamatovat si ji také.
                if($anot->[$j]{afun}=~m/Coord/)
                {
                    for(my $k = $j+1; $k<=$n; $k++)
                    {
                        if($anot->[$k]{rodic_vzor}==$j && $anot->[$k]{afun}=~m/_Co$/ &&
                        $anot->[$k]{afun}!~m/Coord/) # Složené koordinace je lepší
                        # vynechat než správně procházet.
                        {
                            ud("LOK $anot->[$i]{uznacka} L $vazba P C $anot->[$k]{uznacka} L");
                            last;
                        }
                    }
                }
                # Pokud $j neřídí koordinaci, ale teoreticky by mohlo, protože
                # už jsme ho dříve viděli v pozici koordinační spojky,
                # zapamatovat si i všechny potenciální koordinace.
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
                # Pokud má $j dítě nalevo ode mě, skončit.
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
        # Pokud je zavěšeno doprava, zapamatovat si poražené konkurenty nalevo.
        else
        {
            # Jde o závislost, nebo koordinaci?
            my $vazba = ($anot->[$i]{afun}=~m/_Co/ ? "C " : "").$anot->[zjistit_vazbu($anot, $i)]{uznacka};
            # Projít konkurenty.
            my $j = $i-1;
            do {
                # Zapamatovat si konkurenční závislost.
                ud("LOK $anot->[$i]{uznacka} L $anot->[$j]{uznacka} P $vazba P");
                # Pokud $j řídí kooridnaci, zapamatovat si ji také.
                if($anot->[$j]{afun}=~m/Coord/)
                {
                    for(my $k = $j-1; $k>0 && $k<=$n; $k--)
                    {
                        if($anot->[$k]{rodic_vzor}==$j && $anot->[$k]{afun}=~m/_Co$/ &&
                        $anot->[$k]{afun}!~m/Coord/) # Složené koordinace je lepší
                        # vynechat než správně procházet.
                        {
                            ud("LOK $anot->[$i]{uznacka} L C $anot->[$k]{uznacka} P $vazba P");
                            last;
                        }
                    }
                }
                # Pokud $j neřídí koordinaci, ale teoreticky by mohlo, protože
                # už jsme ho dříve viděli v pozici koordinační spojky,
                # zapamatovat si i všechny potenciální koordinace.
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
                # Pokud má $j dítě napravo ode mě, skončit.
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
    # Oprava chyby způsobené neopodstatněnými přístupy k prvkům mimo pole.
    $#{$anot} = $n;
}



#------------------------------------------------------------------------------
# Projde větu a zapamatuje si rámce všech řídících uzlů. Nepokouší se oddělit
# povinná doplnění od volitelných, to se bude muset dělat až s celou statisti-
# kou najednou.
#------------------------------------------------------------------------------
sub projit_ramce
{
    my $anot = shift; # odkaz na pole hashů
    my @ramce;
    # Projít závislé uzly a zapsat je do rámců jejich řídících uzlů.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        my $rodic = $anot->[$i]{rodic_vzor};
        $rodic = "" if($rodic<0); # Pojistka. Dělám to takhle kvůli snaze dosáhnout statistiky identické s 013.
        push(@{$ramce[$rodic]}, $anot->[$i]{mznpodstrom});
    }
    # Projít nasbírané rámce a seřadit jejich členy podle abecedy.
    # Tím se zajistí nezávislost rámců na slovosledu.
    for(my $i = 0; $i<=$#ramce; $i++)
    {
        @{$ramce[$i]} = sort(@{$ramce[$i]});
        # Normalizovaný rámec ihned uložit do evidence.
        my $heslo = $anot->[$i]{heslo};
        # Oddělit příčestí trpná od ostatních tvarů sloves.
        $heslo .= "-trp" if($anot->[$i]{mznpodstrom} =~ m/V[S4]/);
        # Členy rámce spojit vlnovkou, ta se v žádné značce nevyskytuje.
        my $udalost = "RAM $heslo ".join("~", @{$ramce[$i]});
        ud($udalost);
    }
}



#------------------------------------------------------------------------------
# Pokud je věta krátká, uloží celý její strom.
#------------------------------------------------------------------------------
sub projit_kratkou_vetu
{
    my $anot = shift; #odkaz na pole hashů
    # Zkontrolovat, že je věta dostatečně krátká.
    if($#{$anot}>8)
    {
        return;
    }
    # Vytvořit událost: morfologický vzor a strom.
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
    # Uložit větu a její strom mezi události.
    ud("VET $vzor $strom");
}



#------------------------------------------------------------------------------
# Zapamatuje si výskyt něčeho (událost). V případě, že některý prvek události
# (např. morfologická značka řídícího uzlu) je nejednoznačný (tj. skládá se
# z více hodnot oddělených svislítkem), nahradí událost několika jednoznačnými
# událostmi a každé z nich přiřadí poměrnou část výskytu.
#------------------------------------------------------------------------------
sub ud
{
    my @alt; # seznam alternativních událostí
    $alt[0] = $_[0];
    my $i;
    my $n = $_[1];
    $n = 1 if($n eq "");
    # Rozdělit alternativy do samostatných událostí.
    for($i = 0; $i<=$#alt; $i++)
    {
        while($alt[$i] =~ s/^(.*?)([^\s\|]+)\|(\S+)(.*)$/$1$2$4/)
        {
            $alt[++$#alt] = $1.$3.$4;
        }
    }
    # Každé dílčí události započítat poměrnou část výskytu.
    my $dil = $n/($#alt+1);
    for($i = 0; $i<=$#alt; $i++)
    {
        $stat{$alt[$i]} += $dil;
        # Koordinace započítat dvakrát, je to jakési primitivní zvýšení jejich
        # váhy.
        if($alt[$i] =~ m/^KZZ/)
        {
            $stat{$alt[$i]} += 2*$dil;
        }
    }
}



#------------------------------------------------------------------------------
# Najde k uzlu jeho řídící uzel a vrátí jeho index. Pokud řídící uzel řídí
# koordinaci, vrátí místo něj index prvního člena této koordinace ve větě.
# Je na volajícím, aby vztah interpretoval jako koordinaci (závislý uzel má
# afun _Co), nebo jako závislost na koordinaci (závislý uzel má jiný afun).
#------------------------------------------------------------------------------
sub zjistit_vazbu
{
    my $anot = shift;
    my $z = shift;
    my $r = $anot->[$z]{rodic_vzor};
    my $i;
    if($anot->[$r]{afun}!~m/Coord/)
    {
        # Obyčejná závislost.
        return $r;
    }
    else
    {
        # Koordinace nebo závislost na koordinaci.
        for($i = 1; $i<=$#{$anot}; $i++)
        {
            if($anot->[$i]{rodic_vzor}==$r && $anot->[$i]{afun}=~m/_Co/ && $i!=$z)
            {
                # Ale pozor, mohla by to být další vnořená koordinace!
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
        # Pokud z nějakého důvodu nebyl nalezen jiný člen koordinace, vrátit
        # přece jenom index koordinační spojky.
        return $r;
    }
}



#------------------------------------------------------------------------------
# Uloží natrénované statistiky.
#------------------------------------------------------------------------------
sub ulozit
{
    vypsat("prubeh", parse::cas()." Ukládá se statistika.\n");
    # Kvůli efektivitě se hašovací tabulka předává odkazem (volání
    # ulozit(\%stat)). Ve volané funkci se na ni pak dá dostat dvěma způsoby:
    # na celou tabulku najednou $%statref a na prvek $statref->{"ahoj"}.
    my $statref = shift;
    my @stat = keys(%$statref);
    my $n = $#stat+1;
    vypsat("prubeh", parse::cas()." Statistika obsahuje $n událostí.\n");
    $n = 1 if($n==0); # kvůli dělení při hlášení pokroku
    for(my $i = 0; $i<=$#stat; $i++)
    {
        vypsat("stat", "$stat[$i]\t$statref->{$stat[$i]}\n");
    }
}



#------------------------------------------------------------------------------
# Pro danou dvojici r-z zjistí, zda na r ještě visí jiný uzel se stejnou
# značkou jako z.
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
