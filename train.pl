#!/usr/bin/perl
# Natr�nuje statistiky z treebanku a ulo�� je.
use parse;
use csts;
use model; # kv�li zjistit_smer_a_delku()
use vystupy;
use ntice;



$starttime = time();
parse::precist_konfig("parser.ini", \%konfig);



# Na��st seznam subkategoriza�n�ch r�mc� sloves.
# Pot�ebujeme ho, abychom mohli po��tat, kolikr�t se kter� m-zna�ka vyskytla
# jako povinn�, a kolikr�t jako voln� dopln�n�.
if($konfig{valence})
{
    $konfig{nacteny_subkategorizacni_slovnik} = subkat::cist($konfig{subcat}); # vr�t� odkaz na hash se subkategoriza�n�m slovn�kem
}



# Kv�li sn�en� pam�ov�ch n�rok� lze statistick� model rozd�lit do d�l�.
# D�ly se ��sluj� od jedni�ky.
$i_dil = 1;
$konfig{hook_zacatek_cteni} = sub
{
    my $maska = shift;
    my $soubory = shift;
    vypsat("prubeh", "Maska pro jm�na soubor� s daty: $maska\n");
    vypsat("prubeh", "Nalezeno ".($#{$soubory}+1)." soubor�.\n");
};
csts::projit_data($konfig{train}, \%konfig);
# Poslat mi mail, �e tr�nink je u konce. Mus�me do mailu d�t n�jak� existuj�c�
# soubor. Sta�il by mi sice pr�zdn� mail jen s p�edm�tem zpr�vy, ale pokud bych
# k tomu cht�l vyu��t existuj�c� mechanismy, vznikl by mi t�m na disku pr�zdn�
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
# Projde v�tu a zapamatuje si vztahy v n�.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s �daji o aktu�ln�m dokumentu, odstavci a v�t�
    my $anot = shift; # pole hash� o jednotliv�ch slovech
    @anot = @{$anot}; # zat�m se ukl�d� jako glob�ln� prom�nn� v main
    # P�ed zpracov�n�m prvn� v�ty souboru ohl�sit nov� soubor.
    if($stav_cteni->{novy_soubor})
    {
        my ($sek, $min, $hod) = localtime(time());
        my $jmeno_souboru_do_hlaseni = $stav_cteni->{soubor};
        $jmeno_souboru_do_hlaseni =~ s-^.*/([^/]*)$-$1-;
        $jmeno_souboru_do_hlaseni =~ s/\.(?:csts|amm)$//i;
        vypsat("prubeh", parse::cas()." Otev�r� se soubor $jmeno_souboru_do_hlaseni\n");
    }
    # Nau�it se n-tice zna�ek, kter� le�� vedle sebe a tvo�� komponentu stromu.
    for(my $i = 2; $i<=10; $i++)
    {
#        ntice::ucit($i);
    }
    # Vynechat v�ty se z�vadn�m obsahem (prom�nn� $vynechat_vetu se nastavuje
    # p�i na��t�n� slova).
    unless($vynechat_vetu)
    {
        # Ohl�sit na v�stup ��slo zpracov�van� v�ty.
        $veta++;
        if($veta-$ohlasena_veta==100 || $stav_cteni->{posledni_veta})
        {
            my $n_udalosti = int(keys(%stat));
            vypsat("prubeh", parse::cas()." Zpracov�v� se v�ta $veta.\n");
            $ohlasena_veta = $veta;
            # Jestli�e jsme u� p�e�etli ur�it� po�et ud�lost�, ulo�it dosud
            # nasb�ranou statistiku, vypr�zdnit pam� a od t�to v�ty za��t
            # nanovo.
            if($konfig{split}>0 && $n_udalosti>=$konfig{split} || $stav_cteni->{posledni_veta})
            {
                # Jm�no souboru se statistikou.
                my $jmeno = $konfig{prac}."/".$konfig{stat};
                if($konfig{split}>0)
                {
                    vypsat("prubeh", parse::cas()." Konec $i_dil. d�lu.\n");
                    $jmeno .= $i_dil;
                }
                # Ulo�it dosud nasb�ranou statistiku.
                ulozit(\%stat, $jmeno);
                unless($stav_cteni->{posledni_veta})
                {
                    # Uvolnit pam� pro nov� d�l.
                    vypsat("prubeh", parse::cas()." Uvol�uje se pam�.\n");
                    undef(%stat);
                }
                $i_dil++;
            }
        }
        # Zapamatovat si nejdel�� v�tu.
        if($#{$anot}>$maxn_slov)
        {
            $maxn_slov = $#{$anot};
        }
        if($#{$anot}>0) # Pokud neza��n�me ��st prvn� v�tu.
        {
            #!!!
            # Alternuj�c� ��sti k�du.
            my @alt;
            $alt[0] = 1; # coordmember je (0) dite rodice se spravnym afunem (1) i vzdalenejsi potomek (treba pod predlozkou), ale zato clen (pokud je tedy dite korene koordinace, ale neni jeji clen, neni coordmember)
            $alt[1] = 0; # ke koordinacim pridat apozice
            $alt[2] = 1; # v beznych zavislostech zdedene znacky
            $alt[3] = 0; # zaznamenavat koordinacni udalosti
            # (jinak se zaznamenavaji pouze zavislosti)
            #!!!
            # Dokud existuje mo�nost, �e p�i proch�zen� koordinac� se budou
            # upravovat $anot->[$i]{znacka} a $anot->[$i]{afun}, musej� se koordinace zpracov�vat p�ed
            # z�vislostmi, ve kter�ch se tohle vyu�ije. A� se bude spol�hat jen
            # na zd�d�n� zna�ky, bude mo�n� po�ad� oto�it.
            if($konfig{koordinace})
            {
                projit_koordinace($anot, \@alt);
            }
            # Proj�t v�tu a posb�rat statistiky.
            for(my $i = 1; $i<=$#{$anot}; $i++)
            {
                zjistit_udalosti_slovo($i, $anot->[$i]{rodic_vzor}, \@alt, $anot);
            }
            # Spo��tat lok�ln� konflikty.
            spocitat_lokalni_konflikty($anot);
            # U kr�tk�ch v�t si zapamatovat cel� strom.
            projit_kratkou_vetu($anot);
        }
    }
}



#------------------------------------------------------------------------------
# Zjist� tr�novac� ud�losti o jednom slov� (to neznamen�, �e kv�li n�mu nebude
# pot�ebovat proj�t v�echna ostatn� slova v�ty).
#------------------------------------------------------------------------------
sub zjistit_udalosti_slovo
{
    my $z = shift;
    my $r = shift;
    my $alt = shift; # jen odkaz na pole
    my $anot = shift; # jen odkaz na pole
    # Vynechat uzly, jejich� rodi� ��d� koordinaci. Bu� jsou �leny koordinace a
    # jejich vztah k rodi�i nen� z�vislost. Nebo z�visej� na koordinaci, ta by
    # ale m�sto zna�ky sou�ad�c� spojky m�la b�t reprezentov�na zna�kou
    # typick�ho �lena, tak�e z�vislost na koordinaci vy�aduje zvl�tn�
    # zach�zen�.
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
    # Odli�it �leny koordinac� od z�visl�ch uzl�.
    if(!$coordmember)
    {
        if($konfig{koordinace})
        {
            # Vynechat uzly, kter� samy ��d� koordinaci. I v��i sv�m nad��zen�m
            # by koordinace m�la b�t reprezentov�na n���m jin�m ne� zna�kou
            # sou�ad�c� spojky.
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
        # Dopl�kov� parametry: sm�r hrany a vzd�lenost.
        my $rs = $anot->[$r]{slovo};
        my $zs = $anot->[$z]{slovo};
        my $rz;
        my $zz;
        # Pou��t vlastn�, nebo zd�d�n� zna�ky?
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
        # Pokusn� voliteln� roz���en�: m� uzel sourozence stejn�ho druhu?
        my $zarlivost = $konfig{zarlivost} ? (ma_sourozence_stejneho_druhu($anot, $r, $z) ? " N" : " Z") : "";
        ud("OSS $rs $zs $smer $delka");
        ud("OZZ $rz $zz $smer $delka$zarlivost");
        ###!!! N�sleduj�c� druhy ud�lost� se moment�ln� nevyu��vaj� p�i parsingu,
        # tak nem� smysl s nimi prodlu�ovat u�en� a nafukovat statistiku.
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
# Projde v�tu a zaeviduje ud�losti souvisej�c� s koordinacemi.
# Parametry: @anot. Do zna�ek a afun� zapisuje!
# $alt_coordmember: 1 = �len koordinace se pozn� nov�m zp�sobem
# $alt_apos: 1 = ke koordinac�m p�idat apozice
# $alt_znvkor: 1 = ud�losti KZZ se sestavuj� podle zd�d�n�ch zna�ek v ko�eni;
# tot� plat� pro morfologickou(�) zna�ku(y), kter�(�) reprezentuje(�) koordi-
# naci v jej�ch z�vislostn�ch vztaz�ch s okol�m.
#------------------------------------------------------------------------------
sub projit_koordinace
{
    my $anot = shift; # odkaz na pole hash�
    my $alt = shift; # odkaz na pole
    my $alt_znvkor = shift;
    # Proj�t koordinace a posb�rat statistiky o nich.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Zapamatovat si v�skyty ka�d�ho slova, aby bylo mo�n� po��tat,
        # v kolika procentech toto slovo ��dilo koordinaci.
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
            # Zapamatovat si pro ka�d� slovo, kolikr�t ��dilo koord.
            ud("KJJ $anot->[$i]{slovo}");
            my $n_clenu; # Po�et �len� koordinace.
            my @koortypy; # Pot�eba jen kdy� !$alt->[3].
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
                    # Zapamatovat si pro ka�d� heslo, kolikr�t ��dilo
                    # v�ce�etnou koordinaci.
                    if(++$n_clenu==3)
                    {
                        ud("KJ3 $anot->[$i]{slovo}");
                    }
                    if($alt->[3])
                    {
                        # Zna�ky v�ech �len� koordinace jsou posb�ran� u
                        # ko�ene.
                        my $mz = $anot->[$j]{mznpodstrom};
                        my $oz = $anot->[$i]{mznpodstrom};
                        # Vyhodit z nich prvn� v�skyt moj� zna�ky - zastupuje
                        # mne sama. Nem��eme to ud�lat pomoc� regul�rn�ch
                        # v�raz�, proto�e bychom museli zne�kodnit nejen
                        # svisl�tka, ale i z�vorky a jin� znaky ve zna�k�ch.
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
                        # Nyn� u� lze ohl�sit koordina�n� ud�lost. Rozn�soben�
                        # zb�vaj�c�ch zna�ek s t�mi m�mi zajist� p��mo
                        # procedura ud().
                        ud("KZZ $mz $oz");
                    }
                    else
                    {
                        # Proj�t v�echny dosud zji�t�n� �leny a sp�rovat je se
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
                # Zru�it koordinaci, aby byl vid�t typ �len�.
                $anot->[$i]{afun} = "zpracovana koordinace";
                $anot->[$i]{uznacka} = $koortypy[0];
            }
        }
    }
}



#------------------------------------------------------------------------------
# Kontextov� tr�nov�n�.
# Projde v�tu a pro ka�d� slovo si zapamatuje jeho skute�n� zav�en�
# v konkurenci s ka�d�m mo�n�m jin�m zav�en�m v okol�.
#------------------------------------------------------------------------------
sub spocitat_lokalni_konflikty
{
    my $anot = shift; # odkaz na pole hash�
    # Bohu�el je asi n�kde v t�to funkci chyba: asi se p�istupuje k prvk�m za
    # sou�asnou hranic� pole @anot. T�mp�dem se nem��eme spolehnout na d�lku
    # pole a ��dit s jej� pomoc� cykly. Pokud chybu neoprav�me, bude bezpe�n�j��
    # hned na za��tku d�lku v�ty zafixovat a na konci ji vr�tit.
    my $n = $#{$anot};
    for(my $i = 1; $i<=$n; $i++)
    {
        # Pokud je slovo zav�eno doleva, zapamatovat si pora�en� konkurenty napravo.
        if($anot->[$i]{rodic_vzor}<$i)
        {
            # Jde o z�vislost, nebo koordinaci?
            my $vazba = ($anot->[$i]{afun}=~m/_Co/ ? "C " : "").$anot->[zjistit_vazbu($i)]{uznacka};
            # Proj�t konkurenty.
            my $j = $i+1;
            do {
                # Zapamatovat si konkuren�n� z�vislost.
                ud("LOK $anot->[$i]{uznacka} L $vazba P $anot->[$j]{uznacka} L");
                # Pokud $j ��d� kooridnaci, zapamatovat si ji tak�.
                if($anot->[$j]{afun}=~m/Coord/)
                {
                    for(my $k = $j+1; $k<=$n; $k++)
                    {
                        if($anot->[$k]{rodic_vzor}==$j && $anot->[$k]{afun}=~m/_Co$/ &&
                        $anot->[$k]{afun}!~m/Coord/) # Slo�en� koordinace je lep��
                        # vynechat ne� spr�vn� proch�zet.
                        {
                            ud("LOK $anot->[$i]{uznacka} L $vazba P C $anot->[$k]{uznacka} L");
                            last;
                        }
                    }
                }
                # Pokud $j ne��d� koordinaci, ale teoreticky by mohlo, proto�e
                # u� jsme ho d��ve vid�li v pozici koordina�n� spojky,
                # zapamatovat si i v�echny potenci�ln� koordinace.
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
                # Pokud m� $j d�t� nalevo ode m�, skon�it.
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
        # Pokud je zav�eno doprava, zapamatovat si pora�en� konkurenty nalevo.
        else
        {
            # Jde o z�vislost, nebo koordinaci?
            my $vazba = ($anot->[$i]{afun}=~m/_Co/ ? "C " : "").$anot->[zjistit_vazbu($i)]{uznacka};
            # Proj�t konkurenty.
            my $j = $i-1;
            do {
                # Zapamatovat si konkuren�n� z�vislost.
                ud("LOK $anot->[$i]{uznacka} L $anot->[$j]{uznacka} P $vazba P");
                # Pokud $j ��d� kooridnaci, zapamatovat si ji tak�.
                if($anot->[$j]{afun}=~m/Coord/)
                {
                    for(my $k = $j-1; $k>0 && $k<=$n; $k--)
                    {
                        if($anot->[$k]{rodic_vzor}==$j && $anot->[$k]{afun}=~m/_Co$/ &&
                        $anot->[$k]{afun}!~m/Coord/) # Slo�en� koordinace je lep��
                        # vynechat ne� spr�vn� proch�zet.
                        {
                            ud("LOK $anot->[$i]{uznacka} L C $anot->[$k]{uznacka} P $vazba P");
                            last;
                        }
                    }
                }
                # Pokud $j ne��d� koordinaci, ale teoreticky by mohlo, proto�e
                # u� jsme ho d��ve vid�li v pozici koordina�n� spojky,
                # zapamatovat si i v�echny potenci�ln� koordinace.
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
                # Pokud m� $j d�t� napravo ode m�, skon�it.
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
    # Oprava chyby zp�soben� neopodstatn�n�mi p��stupy k prvk�m mimo pole.
    $#{$anot} = $n;
}



#------------------------------------------------------------------------------
# Pokud je v�ta kr�tk�, ulo�� cel� jej� strom.
#------------------------------------------------------------------------------
sub projit_kratkou_vetu
{
    my $anot = shift; #odkaz na pole hash�
    # Zkontrolovat, �e je v�ta dostate�n� kr�tk�.
    if($#{$anot}>8)
    {
        return;
    }
    # Vytvo�it ud�lost: morfologick� vzor a strom.
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
    # Ulo�it v�tu a jej� strom mezi ud�losti.
    ud("VET $vzor $strom");
}



#------------------------------------------------------------------------------
# Zapamatuje si v�skyt n��eho (ud�lost). V p��pad�, �e n�kter� prvek ud�losti
# (nap�. morfologick� zna�ka ��d�c�ho uzlu) je nejednozna�n� (tj. skl�d� se
# z v�ce hodnot odd�len�ch svisl�tkem), nahrad� ud�lost n�kolika jednozna�n�mi
# ud�lostmi a ka�d� z nich p�i�ad� pom�rnou ��st v�skytu.
#------------------------------------------------------------------------------
sub ud
{
    my $ud = shift;
    my $n = shift;
    $n = 1 if($n eq "");
    # Rozd�lit alternativy do samostatn�ch ud�lost�.
    my @alt; # seznam alternativn�ch ud�lost�
    if(!$main::konfig{morfologicke_alternativy})
    {
        $alt[0] = $ud;
    }
    else
    {
        @alt = model::rozepsat_alternativy($ud);
    }
    # Ka�d� d�l�� ud�losti zapo��tat pom�rnou ��st v�skytu.
    my $dil = $n/($#alt+1);
    for(my $i = 0; $i<=$#alt; $i++)
    {
        $stat{$alt[$i]} += $dil;
        # Koordinace zapo��tat dvakr�t, je to jak�si primitivn� zv��en� jejich
        # v�hy.
        if($alt[$i] =~ m/^KZZ/)
        {
            $stat{$alt[$i]} += 2*$dil;
        }
    }
}



#------------------------------------------------------------------------------
# Najde k uzlu jeho ��d�c� uzel a vr�t� jeho index. Pokud ��d�c� uzel ��d�
# koordinaci, vr�t� m�sto n�j index prvn�ho �lena t�to koordinace ve v�t�.
# Je na volaj�c�m, aby vztah interpretoval jako koordinaci (z�visl� uzel m�
# afun _Co), nebo jako z�vislost na koordinaci (z�visl� uzel m� jin� afun).
#
# Pou��v� glob�ln� pole @anot.
#------------------------------------------------------------------------------
sub zjistit_vazbu
{
    my $z = shift;
    my $anot = \@main::anot;
    my $r = $anot->[$z]{rodic_vzor};
    my $i;
    if($anot->[$r]{afun}!~m/Coord/)
    {
        # Oby�ejn� z�vislost.
        return $r;
    }
    else
    {
        # Koordinace nebo z�vislost na koordinaci.
        for($i = 1; $i<=$#{$anot}; $i++)
        {
            if($anot->[$i]{rodic_vzor}==$r && $anot->[$i]{afun}=~m/_Co/ && $i!=$z)
            {
                # Ale pozor, mohla by to b�t dal�� vno�en� koordinace!
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
        # Pokud z n�jak�ho d�vodu nebyl nalezen jin� �len koordinace, vr�tit
        # p�ece jenom index koordina�n� spojky.
        return $r;
    }
}



#------------------------------------------------------------------------------
# Ulo�� natr�novan� statistiky.
#------------------------------------------------------------------------------
sub ulozit
{
    vypsat("prubeh", parse::cas()." Ukl�d� se statistika.\n");
    # Kv�li efektivit� se ha�ovac� tabulka p�ed�v� odkazem (vol�n�
    # ulozit(\%stat)). Ve volan� funkci se na ni pak d� dostat dv�ma zp�soby:
    # na celou tabulku najednou $%statref a na prvek $statref->{"ahoj"}.
    my $statref = $_[0];
    my $soubor = $_[1];
    my @stat = keys(%$statref);
    my $n = $#stat+1;
    vypsat("prubeh", parse::cas()." Statistika obsahuje $n ud�lost�.\n");
    #    open(SOUBOR, ">$soubor");
    $n = 1 if($n==0); # kv�li d�len� p�i hl�en� pokroku
    for(my $i = 0; $i<=$#stat; $i++)
    {
        vypsat("stat", "$stat[$i]\t$statref->{$stat[$i]}\n");
    }
    #    close(SOUBOR);
}



#------------------------------------------------------------------------------
# Pro danou dvojici r-z zjist�, zda na r je�t� vis� jin� uzel se stejnou
# zna�kou jako z.
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
