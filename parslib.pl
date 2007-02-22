#!/usr/bin/perl
# Knihovn� funkce parseru pot�ebn� jak p�i tr�ninku, tak p�i anal�ze.
use vystupy;



# P�e��st konfigura�n� soubor.
my $konfig_log;
open(SOUBOR, "parser.ini");
while(<SOUBOR>)
{
    # V�echny ��dky konfigura�n�ho souboru si zat�m pamatovat, aby bylo pozd�ji mo�n� vypsat je do logu.
    # Nem��eme je vypsat hned, proto�e zp�sob vypisov�n� je konfigurac� tak� ovlivn�n.
    $konfig_log .= $_;
    # Smazat z konfigura�n�ho souboru koment��e.
    s/#.*//;
    # Zbytek m� tvar "prom�nn� = hodnota".
    if(m/(\w+)\s*=\s*(.*)/)
    {
        $konfig{$1} = $2;
    }
}
close(SOUBOR);
# Konfiguraci ze souboru lze p�eb�t konfigurac� z p��kazov�ho ��dku.
# Jednou budu um�t asi cokoliv typu "--atribut hodnota", ale zat�m um�m jedin�: "-q" znamen� "ticho=1".
for(my $i = 0; $i<=$#ARGV; $i++)
{
    if($ARGV[$i] eq "-q")
    {
        $konfig{"ticho"} = 1;
    }
}
# Zaznamenat konfiguraci do logu.
# (Nemohlo se to ud�lat rovnou, proto�e samo zapisov�n� do logu je konfigurac� tak� ovlivn�no.)
# Zalo�it hlavn� z�znam o parametrech v�po�tu.
vypsat("konfig", ""); # zajistit zalozeni cisla instance
vypsat("konfig", "V�po�et ��slo $vystupy::cislo_instance byl spu�t�n v ".cas($::starttime)." na po��ta�i $ENV{HOST} jako proces ��slo $$.\n");
vypsat("konfig", "\n$konfig_log\n");



###############################################################################
# Proch�zen� dat
###############################################################################
sub transformovat_koordinace { }


#------------------------------------------------------------------------------
# Projde tr�novac� nebo testovac� data a na ka�dou v�tu zavol� funkci
# zpracovat_vetu(). Tato funkce je callback, tj. mus� b�t definov�na u toho,
# kdo po��dal o projit� dat.
# Parametrem je cesta k soubor�m s daty. M��e obsahovat z�stupn� znaky.
# Zat�m se pou��v� glob�ln� pole @soubory, proto�e zpracovat_vetu() v train.pl
# chce seznam soubor� zn�t. M�lo by se to ale rozd�lit. Vstupem je
# $konfig{train}. A glob�ln� $isoubor a $ord.
#------------------------------------------------------------------------------
sub projit_data
{
    my $maska = $_[0];
    vypsat("prubeh", "Maska pro jm�na soubor� s daty: $maska\n");
    @soubory = glob($maska);
    vypsat("prubeh", "Nalezeno ".($#soubory+1)." soubor�.\n");
    my %stav; # r�zn� informace o tom, kde v datech se nach�z�me
    vymazat_vetu(\%stav, \@anot);
    for($isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
        open(SOUBOR, $soubory[$isoubor]);
        vypsat("prubeh", "Otvira se soubor $soubory[$isoubor]\n");
        while(<SOUBOR>)
        {
            # Zapamatovat si za��tek dokumentu.
            # <doc file="s/inf/j/1994/cmpr9406" id="001">
            if(m/<doc\s+file=\"(.*?)\"\s+id=\"(.*?)\">/)
            {
                my $novy_identifikator_dokumentu = "$1/$2";
                skoncila_veta(\%stav, \@anot);
                if($novy_identifikator_dokumentu ne $stav{dokid})
                {
                    $stav{predel} = "D";
                    $stav{pred_dokid} = $stav{dokid};
                    $stav{dokid} = $novy_identifikator_dokumentu;
                    $stav{pred_doksoubor} = $stav{doksoubor};
                    $stav{doksoubor} = $soubory[$isoubor];
                }
            }
            # Zapamatovat si za��tek odstavce.
            # <p n=1>
            elsif(m/<p\s+n=(\d+)>/)
            {
                my $nove_cislo_odstavce = $1;
                skoncila_veta(\%stav, \@anot);
                # Ze zna�ky za��tku dokumentu automaticky vypl�v� i za��tek odstavce.
                if($stav{predel} ne "D")
                {
                    if($nove_cislo_odstavce!=$stav{odstid})
                    {
                        $stav{predel} = "P";
                        $stav{pred_odstid} = $stav{odstid};
                        $stav{odstid} = $nove_cislo_odstavce;
                    }
                }
            }
            elsif(m/^<s id="(.*?)">/)
            {
                $stav{vetid} = $1;
                skoncila_veta(\%stav, \@anot);
            }
            elsif(m/<D>/)
            {
                # Glob�ln� prom�nn�!
                $bezmezery = 1;
            }
            elsif(m/^<[fd][ >]/)
            {
                zpracovat_slovo();
                # Glob�ln� prom�nn�!
                $bezmezery = 0;
            }
        }
        close(SOUBOR);
    }
    if($ord>0)
    {
        # Nastavit p��znak posledn� v�ty, aby funkce zpracovat_vetu() provedla
        # naposledy i v�echny akce, kter� d�l� v�dy jednou za �as.
        $posledni_veta = 1;
        skoncila_veta("K", \@anot);
    }
}



#------------------------------------------------------------------------------
# Uzlov� bod, vol� se v�dy, kdy� mus� skon�it v�ta, pokud tedy n�jak� v�bec
# za�ala. Vol� se na za��tku dokumentu, odstavce a v�ty a na konci dat.
#------------------------------------------------------------------------------
sub skoncila_veta
{
    my $stav = shift; # r�zn� informace o tom, kde v datech se nach�z�me
    my $anot = shift; # odkaz na pole hash� s informacemi o slovech v�ty (0 je ko�en)
    if($#{$anot}>0)
    {
        # Upravit zna�ku koncov� interpunkce (to nem��eme ud�lat, dokud
        # nev�me, �e doty�n� slovo je posledn�).
        if($anot->[$#slova]{uznacka}=~m/^Z/)
        {
            $slova[$#slova] .= "K";
            $anot->[$#slova]{slovo} .= "K";
            $anot->[$#slova]{heslo} .= "K";
            $anot->[$#slova]{uznacka} .= "K";
        }
        # Zd�dit morfologick� zna�ky u koordinac� a apozic.
        zjistit_znacky_podstromu();
        # Prov�st vlastn� zpracov�n� definovan� aplikac�.
        zpracovat_vetu($stav, $anot);
        # P�ipravit se na �ten� dal�� v�ty.
        vymazat_vetu($stav, $anot);
        return 1;
    }
    else
    {
        return 0;
    }
}



#------------------------------------------------------------------------------
# Vyma�e v�echny glob�ln� prom�nn� popisuj�c� v�tu, kter� vznikly v procedu�e
# zpracovat_slovo. Typicky se vol� na za��tku procedury zpracovat_vetu, aby
# bylo kam na��tat dal�� v�tu. Tato funkce tak� rovnou vypln� n�kter� �daje o
# ko�eni, proto�e ty jsou ve v�ech v�t�ch stejn�, ale z dat se je nedozv�me.
#------------------------------------------------------------------------------
sub vymazat_vetu
{
    my $stav = shift; # r�zn� informace o tom, kde v datech se nach�z�me
    my $anot = shift; # odkaz na pole hash� s informacemi o slovech v�ty (0 je ko�en)
    $stav->{predel} = "S"; # D pro dokument, P pro odstavec, S pro v�tu (default), K pro posledn� v�tu
    # Informace o slovech.
    splice(@slova);
    splice(@{$anot});
    $slova[0] = "#";
    $anot->[0]{slovo} = "#";
    # R�zn� informace.
    $anot->[0]{heslo} = "#";
    $anot->[0]{znacka} = "Z#-------------";
    $anot->[0]{uznacka} = "#";
    # Index naposledy p�e�ten�ho slova.
    $ord = 0;
    # Informace o vztaz�ch.
    splice(@struktura);
    $struktura[0] = -1;
    $anot->[0]{rodic_vzor} = -1;
    splice(@afun);
    $afun[0] = "AuxS";
    $anot->[0]{afun} = "AuxS";
    # Informace o v�t�.
    $sloveso = 0; # Zda v�ta obsahuje sloveso.
    $vynechat_vetu = 0;
}



#------------------------------------------------------------------------------
# Vr�t� aktu�ln� �as jako �et�zec s polo�kami odd�len�mi dvojte�kou. D�lka
# �et�zce je v�dy stejn� (8 znak�), co� lze vyu��t p�i sloupcov�m form�tov�n�.
#------------------------------------------------------------------------------
sub cas
{
    my($h, $m, $s);
    ($s, $m, $h) = localtime(time());
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}



#------------------------------------------------------------------------------
# Vyp�e dobu, po kterou program b�el. K tomu pot�ebuje dostat �asov� otisky
# za��tku a konce.
#------------------------------------------------------------------------------
sub vypsat_delku_trvani_programu
{
    my $starttime = $_[0];
    my $stoptime = $_[1];
    my $soubor = $_[2];
    if($soubor eq "")
    {
        $soubor = "konfig";
    }
    my $cas = $stoptime-$starttime;
    my $hod = int($cas/3600);
    my $min = int(($cas%3600)/60);
    my $sek = $cas%60;
    vypsat($soubor, "V�po�et skon�il v ".cas($stoptime).".\n");
    vypsat($soubor, sprintf("Program b�el %02d:%02d:%02d hodin.\n", $hod, $min, $sek));
}



###############################################################################
# Anotace slova
###############################################################################



#------------------------------------------------------------------------------
# Na�te slovo ze vstupu.
# @slova ... slovni tvary <f>
# %{$anot[$i]} ... jednotlive anotace
#  (Ne vsechny polozky se uz plni a pouzivaji, ale kvuli pojmenovavaci koncepci
#  jsou zde uvedeny.)
#  mezera ... 1, pokud slovo ma byt oddeleno mezerou od predchazejiciho, 0 jinak. Na zacatku vety vzdy 1.
#  slovo ... slovni tvar, na rozdil od $slova[$i] neupravovany (velka pismena, "K" za koncovou interpunkci)
#  heslo - zkracene o poznamky za podtrzitkem, ale rozliseni vyznamu pomlckou a cislem zachovano
#     heslo ... heslo ze zvoleneho zdroje (<MMl>, <MDl>, <l>)
#     lexkat ... poznamka za podtrzitkem, ze stejneho zdroje jako heslo
#     mozna_hesla ... hesla ze slovniku <MMl>
#     heslo_clovek ... heslo prirazene clovekem <l>
#     heslo_mdla ... heslo podle lematizatoru a <MDl src="a">
#     heslo_mdlb ... heslo podle lematizatoru b <MDl src="b">
#  znacka - morfologicka, neupravovana!
#     znacka ... morfologicka znacka ze zvoleneho zdroje (<MMt>, <MDt>, <t>)
#     mozne_znacky ... znacky ze slovniku <MMt>
#     znacka_clovek ... znacka prirazena clovekem <t>
#     znacka_mdta ... znacka podle taggeru a <MDt src="a">
#     znacka_mdtb ... znacka podle taggeru b <MDt src="b">
#     uznacka ... ze zvoleneho zdroje, ale upravena (jsou-li upravy povolene)
#     zdznacka ... zdedena znacka (koren koordinace dedi od clenu)
#  sznacka - povrchove syntakticka, tj. analyticka funkce
#     sznacka ... znacka prirazena clovekem <A>
#  rodic - index rodice
#     rodic_clovek ... rodic prirazeny clovekem <g>
#     rodic_mdgdz ... rodic prirazeny parserem dz <MDg src="dz">
#     rodic_mdg(.*) ... rodic prirazeny parserem $1 <MDg src="$1">
#  NIZE UVEDENE KLICE A PROMENNE JSOU ZASTARALE, URCENE K VYMRENI
#------------------------------------------------------------------------------
sub zpracovat_slovo
{
    $mzdroj = "MD"; # MD, MM nebo nic
    $ord++;
    #==========================================================================
    # Mezera p�ed slovem (CSTS zna�ka <D>).
    #==========================================================================
    $anot[$ord]{mezera} = !$bezmezery;
    #==========================================================================
    # P�e��st slovn� tvar.
    #==========================================================================
    m/<[fd]( [^>]*)?>([^<]+)/;
    $slova[$ord] = $2;
    $slova[$ord] =~ tr/A�BC�D�E��FGHI�JKLMN�O�PQR�S�T�U��VWXY�Z�/a�bc�d�e��fghi�jklmn�o�pqr�s�t�u��vwxy�z�/;
    $anot[$ord]{slovo} = $slova[$ord];
    #==========================================================================
    # P�e��st heslov� tvar.
    #==========================================================================
    m/<$konfig{mzdroj0}l[^>]*>([^<]+)/;
    #     heslo ... heslo ze zvoleneho zdroje (<MMl>, <MDl>, <l>)
    #     lexkat ... poznamka za podtrzitkem, ze stejneho zdroje jako heslo
    $anot[$ord]{heslo} = $1;
    $anot[$ord]{heslo} =~ s/_(.*)$//;
    $anot[$ord]{lexkat} = $1;
    #==========================================================================
    # P�e��st morfologickou zna�ku.
    #==========================================================================
    #  znacka - morfologicka, neupravovana!
    #     znacka ... morfologicka znacka ze zvoleneho zdroje (<MMt>, <MDt>, <t>)
    #     mozne_znacky ... znacky ze slovniku <MMt>
    #     znacka_clovek ... znacka prirazena clovekem <t>
    #     znacka_mdta ... znacka podle taggeru a <MDt src="a">
    #     znacka_mdtb ... znacka podle taggeru b <MDt src="b">
    #     uznacka ... ze zvoleneho zdroje, ale upravena (jsou-li upravy povolene)
    #     zdznacka ... zdedena znacka (koren koordinace dedi od clenu)
    # P�e��st seznam mo�n�ch zna�ek ze slovn�ku.
    $anot[$ord]{mozne_znacky} = "";
    my $schranka = $_;
    while($schranka =~ s/<MMt[^>]*>(...............)//)
    {
        $anot[$ord]{mozne_znacky} .= "|$1";
    }
    $anot[$ord]{mozne_znacky} =~ s/^\|//;
    # P�e��st zna�ky p�i�azen� �lov�kem a ob�ma taggery.
    if($schranka =~ m/<t>(...............)/)
    {
        $anot[$ord]{znacka_clovek} = $1;
    }
    if($schranka =~ m/<MDt.*?src="a".*?>(...............)/)
    {
        $anot[$ord]{znacka_mdta} = $1;
    }
    if($schranka =~ m/<MDt.*?src="b".*?>(...............)/)
    {
        $anot[$ord]{znacka_mdtb} = $1;
    }
    # Vybrat zna�ku ze zdroje po�adovan�ho v konfiguraci.
    if($konfig{mzdroj0} eq "MM")
    {
        $anot[$ord]{znacka} = $anot[$ord]{mozne_znacky};
    }
    elsif($konfig{mzdroj0} eq "")
    {
        $anot[$ord]{znacka} = $anot[$ord]{znacka_clovek};
    }
    elsif($konfig{mzdroj0} eq "MD")
    {
        if($konfig{mzdroj1} eq "a")
        {
            $anot[$ord]{znacka} = $anot[$ord]{znacka_mdta};
        }
        elsif($konfig{mzdroj1} eq "b")
        {
            $anot[$ord]{znacka} = $anot[$ord]{znacka_mdtb};
        }
    }
    #==========================================================================
    # Upravit morfologickou zna�ku.
    #==========================================================================
    if($konfig{upravovat_mzn})
    {
        $anot[$ord]{uznacka} = join("|", sort(map
        {
            upravit_mznacku($_, $anot[$ord]{lexkat}, $anot[$ord]{heslo}, $slova[$ord]);
        }
        (split(/\|/, $anot[$ord]{znacka}))));
    }
    else
    {
        $anot[$ord]{uznacka} = join("|", sort(split(/\|/, $anot[$ord]{znacka})));
    }
    # Odstranit p��padn� duplik�ty (kv�li tomu jsme zna�ky t��dili).
    while($anot[$ord]{uznacka} =~ s/(..)\|\1/$1/g) {}
    #==========================================================================
    # Zjistit syntaktickou strukturu a syntaktickou zna�ku.
    #==========================================================================
    if(m/<g>(\d+)/)
    {
        $struktura[$ord] = $1;
        # Nov�j�� p��stup: ve�ker� anotace krom� slova sam�ho jsou v @anot.
        $anot[$ord]{rodic_vzor} = $struktura[$ord];
    }
    if(m/<A>([^<]+)/)
    {
        $afun[$ord] = $1;
        $anot[$ord]{afun} = $afun[$ord];
        if($afun[$ord]=~m/$konfig{"vynech"}/)
        {
            $vynechat_vetu = 1;
        }
    }
    # Dal�� syntaktick� anotace ulo�it do obecn�ho pole hash�.
    if(m/<MDg src="(.*?)">(\d+)/)
    {
        $anot[$ord]{"mdg".$1} = $2;
    }
}



#------------------------------------------------------------------------------
# P�e�te ze vstupn�ho ��dku anotaci jednoho druhu. V�dy vr�t� pole, i kdyby
# neexistovaly alternativn� anotace t�ho� druhu.
#------------------------------------------------------------------------------
sub zjistit_anotaci
{
    # Vstupn� ��dek t�kaj�c� se jednoho slova.
    my $radek = $_[0];
    # Identifikace. Nap�. "<MDt w="0.5" src="a">" se chytne na "MDt src=a".
    # Identifikace nemus� fungovat dob�e, obsahuje-li v�ce ne� jeden atribut.
    my $ident = $_[1];
    # P�ipravit regul�rn� v�raz, podle kter�ho anotaci pozn�me.
    # Tato funkce se bude volat velmi �asto, proto cachovat ji� zn�m� regul�rn�
    # v�razy.
    my $regex;
    if(exists($anot_regex{$ident}))
    {
        $regex = $anot_regex{$ident};
    }
    else
    {
        $regex = $ident;
        # Obalit hodnotu atributu voliteln�mi uvozovkami, pokud tam nejsou.
        $regex =~ s/(\w+)=(\w+)/$1=(?:$2|\"$2\"|\'$2\')/;
        # Dovolit dal�� atributy a mezery.
        $regex =~ s/\s+/(?: [^>]*)? /g;
        # Obalit cel� skobi�kami, p�idat past na vlastn� anotaci.
        $regex = "<$regex>([^<\r\n]*)";
        # Ulo�it vytvo�en� regul�rn� v�raz do cache.
        $anot_regex{$ident} = $regex;
    }
    # Pochytat v�echny v�skyty anotace.
    my @hodnoty;
    my $i = 0;
    while($radek =~ s/$regex//)
    {
        $hodnoty[$i++] = $1;
    }
    return @hodnoty;
}



#------------------------------------------------------------------------------
# Uprav� morfologickou zna�ku. Vol� se p�i �ten� zna�ky, tedy z funkce
# zpracovat_slovo(). Zapisuje do glob�ln� prom�nn� $sloveso. Kontrolu v�skytu
# slovesa je dobr� d�lat tady, proto�e jedno slovo m��e m�t v�ce zna�ek a jen
# n�kter� z nich mohou b�t slovesn�.
#------------------------------------------------------------------------------
sub upravit_mznacku()
{
    my $znacka = $_[0];
    my $lznacka = $_[1]; # stylistick� a v�znamov� kategorie
    my $heslo = $_[2];
    my $slovo = $_[3];
    #==========================================================================
    # Kontrola v�skytu slovesa (kv�li z�vislostem na ko�eni).
    if($znacka =~ m/^V/)
    {
        $sloveso = 1;
    }
    #==========================================================================
    # �adovou ��slovku pova�ovat za p��davn� jm�no.
    $znacka =~ s/^Cr/AA/;
    # Zkr�tit zna�ku na dva znaky (slovn� druh a p�d nebo poddruh).
    $znacka =~ m/^(.)(.)..(.)/;
    $znacka = $3=="-" ? $1.$2 : $1.$3;
    $znacka .= $osoba;
    # Machinace se zna�kami.
    if($znacka=~m/^N/ && $lznacka=~m/Y/)
    {
        $znacka =~ s/^N/NY/;
    }
    # Lexikalizace zna�ek pro interpunkci.
    elsif($znacka eq "Z:")
    {
        $znacka = "Z".$slovo;
        # Zbavit se b�n�j��ch zvl�tn�ch znak� ve zna�ce, aby se s n� l�pe zach�zelo jako s textov�m atomem.
        # POZOR, sni�uje to �sp�nost, i kdy� jen malinko! Z�ejm� se n�kde v k�du odkazuju p��mo na konkr�tn� zna�ky!
        #        $znacka =~ s/&percnt;/prc/;
        #        $znacka =~ s/&verbar;/vrt/;
        #        $znacka =~ s/&(.*?);/$1/;
        #        $znacka =~ s/;/sem/;
        #        $znacka =~ s/,/com/;
        #        $znacka =~ s/:/col/;
        #        $znacka =~ s/-/dsh/;
        #        $znacka =~ s/\./prd/;
        #        $znacka =~ s/!/exc/;
        #        $znacka =~ s/\?/que/;
        #        $znacka =~ s/=/equ/;
        #        $znacka =~ s/\+/plu/;
        #        $znacka =~ s/\//sla/;
        #        $znacka =~ s/\(/lpa/;
        #        $znacka =~ s/\)/rpa/;
    }
    # Selektivn� lexikalizace zna�ek.
    if($konfig{"selex"})
    {
        # Z�jmena
        if($znacka=~m/^P/)
        {
            # Zvratn� z�jmena "se" a "si".
            if($slovo=~m/(se|si)/)
            {
                $znacka = "P".$slovo;
            }
            # Vzta�n� z�jmena "kdo", "co", "kter�", "jak�", "��", "jen�".
            #     elsif($heslo=~m/^(kdo|co|kter|jak|��|jen�)/)
            else
            #     elsif($heslo=~m/^(j�|ty|on|my|vy|m�j|tv�j|jeho|jej�|n�|v�|jejich|sv�j|ten|tento|tenhle|onen|takov�|t��|tent��|s�m|kdo|co|kter|jak|��|jen�)/)
            {
                $znacka .= $heslo;
            }
        }
        elsif($znacka=~m/^V/)
        {
            # Pomocn� sloveso b�t lexikalizovat tvarem, ne heslem.
            # Je pot�eba rozli�it, kdy m� b�t naho�e a kdy dole.
            # Pochopiteln� je to opat�en� funk�n� jen v �e�tin�, ale jinde by nem�lo �kodit.
            if($heslo eq "b�t")
            {
                my $byt = $slovo;
                $byt =~ s/^ne//;
                $byt =~ s/ti$/t/;
                $byt =~ s/byl[aoiy]/byl/;
                $znacka = "V".$byt;
            }
        }
        elsif($znacka=~m/^D/)
        {
            # Seznam p��slovc�, kter� se vyskytla 100 a v�cekr�t.
            my @casta_prislovce =
            ("tak", "jak", "u�", "tak�", "ji�", "je�t�", "v�era", "tedy",
            "pak", "v�ce", "dnes", "pouze", "kde", "kdy", "nap��klad",
            "toti�", "p�edev��m", "velmi", "zat�m", "nyn�", "pr�v�", "st�le",
            "zejm�na", "zcela", "dosud", "stejn�", "t�m��", "letos", "d�le",
            "sice", "tu", "dokonce", "nav�c", "zde", "rovn�", "z�ejm�",
            "p�itom", "nap�", "v�bec", "tam", "�asto", "p��li�", "naopak",
            "z�rove�", "v�dy", "m�n�", "t�eba", "op�t", "loni", "sp�e",
            "snad", "dob�e", "pro�", "zhruba", "pozd�ji", "vlastn�", "mo�n�",
            "samoz�ejm�", "skute�n�", "znovu", "tehdy", "p�esto", "nakonec",
            "spolu", "pot�", "jinak", "proto", "d��ve", "p��mo", "v�c",
            "te�", "nikdy", "teprve", "v�t�inou", "p�ece", "jist�",
            "podobn�", "n�kdy", "hlavn�", "alespo�", "dost", "zase",
            "�dajn�", "sou�asn�", "postupn�", "celkem", "prakticky", "co",
            "hned", "dlouho", "nejv�ce", "hodn�", "ro�n�", "nad�le",
            "rychle", "potom", "nejm�n�", "trochu", "mnohem", "tady",
            "pom�rn�", "velice", "ned�vno", "v�razn�", "takto", "nikoli",
            "kr�tce", "pon�kud", "l�pe", "p�esn�", "opravdu", "p�ibli�n�",
            "t�ko", "pravd�podobn�", "podstatn�", "moc", "doma", "kone�n�",
            "daleko", "zvl�t�", "prost�", "spole�n�", "p�vodn�", "mj",
            "apod", "nov�", "sp�", "p��padn�", "p�edem", "naprosto", "d�l",
            "�pln�", "rozhodn�", "ve�er", "okam�it�", "denn�", "nikoliv",
            "obvykle", "kam", "atd");
            for(my $i = 0; $i<=$#casta_prislovce; $i++)
            {
                if($slovo eq $casta_prislovce[$i])
                {
                    $znacka = "D".$slovo;
                    last;
                }
            }
        }
        elsif($znacka=~m/^R/)
        {
            $znacka = "R".$heslo;
        }
        elsif($znacka=~m/^J/ && $slovo=~m/(�e|aby|zda)/)
        {
            $znacka = "J".$slovo;
            $znacka =~ s/zdali/zda/;
        }
    }
    return $znacka;
}



###############################################################################
# D�d�n� morfologick�ch zna�ek u koordinac� a apozic.
# Vztahuje se ke slov�m, ale zji��uje se a� po na�ten� cel� v�ty.
###############################################################################



#------------------------------------------------------------------------------
# Projde strom a zjist� ke ka�d�mu slovu morfologickou zna�ku reprezentuj�c�
# jeho podstrom. Tato zdola zd�d�n� zna�ka se nemus� shodovat se zna�kou ko�ene
# podstromu. Nap�. ko�eny koordinac� jsou obvykle sou�ad�c� spojky, tedy slova
# se zna�kou J^, ale cel� koordinace dostane zna�ku podle sv�ch �len�, tedy
# nap�. koordinace podstatn�ch jmen v 1. p�d� dostane zna�ku N1.
# Funkce �te glob�ln� pole @struktura, @afun a @anot. Pln� glob�ln� hash
# @anot[$i]{mznpodstrom} a @anot[$i]{coordmember}.
#------------------------------------------------------------------------------
sub zjistit_znacky_podstromu
{
    my ($i, $j);
    for($i = 0; $i<=$#slova; $i++)
    {
        $anot[$i]{coordmember} = 0;
    }
    for($i = 1; $i<=$#slova; $i++)
    {
        # Koordinace a apozice d�d� zna�ky sv�ch �len� (nikoli v�ech sv�ch
        # d�t�). Vno�en� koordinace a apozice se proch�zej� opakovan� (jednou
        # kv�li sv� morfologick� zna�ce a jednou nebo v�ckr�t kv�li zna�k�m
        # sv�ch nad��zen�ch), ale rezignuju na efektivitu v�po�tu ve prosp�ch
        # efektivity programov�n�: hlavn� kdy� to bude jednoduch� a snadno
        # roz�i�iteln�.
        #   if($afun[$i]=~m/^(Coord|Apos)/)
        if($afun[$i]=~m/^Coord/)
        {
            my @clenove = zjistit_skutecne_cleny_koordinace($i);
            for(my $j = 0; $j<=$#clenove; $j++)
            {
                # A� se bude d�dit i jinde ne� u koordinac� a apozic, bude asi
                # pot�eba tady br�t zd�d�nou zna�ku m�sto p�vodn�, to se pak
                # ale bude taky muset o�et�it, kter� d�d�n� prob�hne d��v.
                $anot[$i]{mznpodstrom} .= "|".$anot[$clenove[$j]]{uznacka};
                $anot[$clenove[$j]]{coordmember} = 1;
            }
            # Odstranit svisl�tko p�ed prvn� zna�kou.
            $anot[$i]{mznpodstrom} =~ s/^\|//;
        }
        else
        {
            $anot[$i]{mznpodstrom} = $anot[$i]{uznacka};
        }
    }
}



#------------------------------------------------------------------------------
# Vr�t� seznam index� �len� koordinace, nebo apozice. Jako parametr po�aduje
# index ko�ene doty�n� koordinace nebo apozice. Podstrom projde rekurzivn�,
# tak�e u vno�en�ch koordinac� nebo apozic vr�t� seznam jejich �len�, nikoli
# index jejich ko�ene (vhodn� pro posuzov�n� morfologick�ch zna�ek �len�).
# V� i o tom, �e u p�edlo�ek a pod�ad�c�ch spojek nen� informace o jejich
# �lenstv� v koordinac�ch nebo apozic�ch ulo�ena a �e je p�esunuta do syntak-
# tick� zna�ky jejich d�t�te. Pokud v�ak jejich d�t� skute�n� vykazuje p��slu�-
# nost ke koordinaci nebo apozici, funkce nevr�t� index tohoto d�t�te, ale
# index p�edlo�ky �i pod�ad�c� spojky, kter� ho ��d�.
#------------------------------------------------------------------------------
sub zjistit_skutecne_cleny_koordinace
{
    my $koren = $_[0];
    my $i;
    my @clenove;
    # Proj�t v�echny uzly stromu, hledat d�ti ko�ene.
    for($i = 1; $i<=$#slova; $i++)
    {
        # �leny koordinace mohou b�t n�kter� d�ti ko�ene.
        if($struktura[$i]==$koren)
        {
            # �len koordinace se pozn� podle syntaktick� zna�ky kon��c� na _Co.
            # �len apozice se pozn� podle syntaktick� zna�ky kon��c� na _Ap.
            if($afun[$i] =~ m/_(Co|Ap)$/)
            {
                # Pokud je �lenem vno�en� koordinace nebo apozice, zaj�maj� n�s
                # jej� �leny, ne jej� ko�en.
                if($afun[$i] =~ m/^(Coord|Apos)/)
                {
                    splice(@clenove, $#clenove+1, 0,
                    zjistit_skutecne_cleny_koordinace($i));
                }
                # Jinak p�idat do seznamu p��mo doty�n� d�t�.
                else
                {
                    $clenove[++$#clenove] = $i;
                }
            }
            # P�edlo�ky a pod�ad�c� spojky mohou b�t �leny koordinace nebo apo-
            # zice, ale nikdy nep�ib�raj� p��ponu _Co nebo _Ap. Tu m�sto toho
            # dostane jejich (obvykle jedin�) d�t�. Vyu�ijeme znalosti vnit�-
            # n�ho proveden� t�to funkce (zejm�na toho, �e nekontroluje, �e
            # ko�en koordinace nebo apozice m� s-zna�ku Coord, resp. Apos) a
            # nech�me rekurzivn� vyhledat v�echny �leny "koordinace ��zen�
            # p�edlo�kou (pod�ad�c� spojkou)".
            elsif($afun[$i] =~ m/Aux[PC]/)
            {
                # Zjistit, zda alespo� jedno d�t� p�edlo�ky m� s-zna�ku kon��c�
                # na _Co nebo _Ap.
                my @clenove_pod_predl = zjistit_skutecne_cleny_koordinace($i);
                # Pokud se takov� d�t� najde, je to d�kaz, �e tato v�tev je
                # �lenem koordinace a ne jej�m rozvit�m. Ale pro n�s, na rozd�l
                # od anot�tor� PDT, bude �lenem ko�en t�to v�tve, tedy
                # p�edlo�ka, ne jej� d�t�!
                if($#clenove_pod_predl>=0)
                {
                    push(@clenove, $i);
                }
            }
        }
    }
    return @clenove;
}



###############################################################################
# Subkategorizace
###############################################################################



#------------------------------------------------------------------------------
# Na�te seznam r�mc� ze souboru do hashe. Kl��em hashe je sloveso, hodnota je
# pole r�mc�, r�mec je pole �len�, �len je morfologick� zna�ka upraven� pro
# pot�eby r�mc�, p��padn� obohacen� o lemma. Jm�no vstupn�ho souboru a odkaz na
# c�lov� hash se p�ed�vaj� jako parametry.
#------------------------------------------------------------------------------
sub nacist_ramce
{
    my $jmeno_souboru = $_[0];
    my $hashref = $_[1];
    open(RAMCE, $jmeno_souboru)
    or die("Nelze otev��t soubor s r�mci $jmeno_souboru.\n");
    while(<RAMCE>)
    {
        # Odstranit konec ��dku.
        s/\r?\n$//;
        # Obvykl� tvar r�mce je "sloveso  mzn/szn~~mzn/szn", pop�.
        # "sloveso <INTR>".
        if(m/^(\S+)\s+<INTR>$/)
        {
            # Pr�zdn� r�mec nep�echodn�ho slovesa.
            my @cleny;
            push(@{$hashref->{$1}}, [@cleny]);
            # Nov� z��zen� r�mec bude pr�zdn� pole, tak�e jsme hotovi.
        }
        elsif(m/^(\S+)\s+(.*)$/)
        {
            # Prvn� ��st je sloveso, druh� ��st je r�mec.
            my $sloveso = $1;
            my $ramec = $2;
            my @cleny = split(/~~/, $ramec);
            push(@{$hashref->{$sloveso}}, [@cleny]);
        }
    }
    close(RAMCE);
}



#------------------------------------------------------------------------------
# Porovn� subkategoriza�n� zna�ku s morfologickou (redukovanou podle m�ho
# sch�matu). Subkategoriza�n� zna�ka vych�z� z morfologick� zna�ky, ale v n�k-
# ter�ch p��padech je upravena a n�kdy je obohacena o heslo.
#------------------------------------------------------------------------------
sub odpovida_skzn_mzn
{
    my $skzn = $_[0];
    my $mzn = $_[1];
    # Podstatn� jm�na jsou v obou p��padech stejn�.
    if($skzn =~ m/^N\d$/ && $mzn eq $skzn)
    {
        return 1;
    }
    # P�edlo�ky u mzn vynech�vaj� z�vorky a ��slo p�du.
    elsif($skzn =~ m/^R\d\((.*?)\)$/ && $mzn =~ m/^R$1$/)
    {
        return 1;
    }
    # Pod�ad�c� spojky u mzn vynech�vaj� z�vorky.
    elsif($skzn =~ m/^J,\((.*?)\)$/ && $mzn =~ m/^J,$1$/)
    {
        return 1;
    }
    # Slovesa v infinitivu maj� VINF m�sto Vf.
    elsif($skzn eq "VINF" && $mzn =~ m/^V(?:f|b�t)$/)
    {
        return 1;
    }
    # Zvratn� z�jmena maj� v obou syst�mech zvl�tn� zna�ku, v ka�d�m jinou.
    # Zvratn� z�jmena v�ak tak� mohou reprezentovat oby�ejn� p�edm�t.
    elsif($skzn =~ m/(PR|N)4/ && $mzn eq "Pse" ||
    $skzn eq m/(PR|N)3/ && $mzn eq "Psi")
    {
        return 1;
    }
    # Subkategoriza�n� pozice N\d m��e b�t napln�na i p��davn�m jm�nem,
    # z�jmenem nebo ��slovkou.
    elsif($skzn =~ m/N(\d)/ && $mzn =~ m/[NAPC]$1/)
    {
        return 1;
    }
    # U ostatn�ch slovn�ch druh� se zna�ky neli��.
    elsif($skzn eq $mzn)
    {
        return 1;
    }
    return 0;
}



#------------------------------------------------------------------------------
# Projde strom a zjist�, jak� d�ti m� konkr�tn� sloveso (pop�. jin� slovo).
# Potom projde seznam r�mc� tohoto slovesa a vybere r�mec, kter� nejl�pe sed�.
# R�mce posuzuje podle krit�ri� v n�sleduj�c�m po�ad�:
# 1. Po�et �len� r�mce, kter� ve strom� nejsou realizov�ny. Men�� m� p�ednost.
# 2. D�lka (celkov� po�et �len�) r�mce. Del�� m� p�ednost.
# Pokud zbyde v�ce r�mc�, mezi nimi� nelze pomoc� v��e uveden�ch krit�ri� roz-
# hodnout, funkce vr�t� v�echny takov� r�mce. Index slovesa ve strom� se p�e-
# d�v� jako parametr. Struktura stromu (pole index� rodi��) se p�ed�v� odkazem,
# nem��eme pou��t glob�ln� prom�nnou, proto�e nev�me kterou (nev�me, jestli se
# m� br�t vzorov� struktura (@struktura), nebo struktura vytv��en� parserem
# (@rodic)). Dal�� anotace v�ty se v�ak berou z glob�ln�ch prom�nn�ch (@slova,
# @anot), tak pozor! S tabulkou r�mc� je to jinak, ta se p�ed�v� odkazem.
#------------------------------------------------------------------------------
sub najit_odpovidajici_ramec
{
    my $i_sloveso = $_[0];
    my $o_strom = $_[1];
    my $o_ramce = $_[2];
    # Zjistit seznam d�t� slovesa v na�em strom�.
    my @deti;
    for(my $i = 0; $i<=$#{$o_strom}; $i++)
    {
        if($o_strom->[$i]==$i_sloveso)
        {
            $deti[++$#deti] = $i;
        }
    }
    # Proj�t r�mce slovesa a porovnat je s jeho d�tmi.
    my $o_ramce_s = $o_ramce->{$anot[$i_sloveso]{heslo}};
    my @n_zbylo;
    my $min_zbylo;
    my $i_min_zbylo;
    #    print("Chyst�m se porovn�vat r�mce slovesa \"$anot[$i_sloveso]{heslo}\".\n");
    #    print("Toto sloveso m� ".($#{$o_ramce_s}+1)." r�mc�.\n");
    for(my $i = 0; $i<=$#{$o_ramce_s}; $i++)
    {
        # Porovnat i-t� r�mec se skute�n�mi d�tmi slovesa ve strom�.
        # Zjistit, kolik �len� r�mce nem� realizaci mezi d�tmi.
        my @kopie_ramce = @{$o_ramce_s->[$i]};
        #   print(($i+1).". r�mec m� ".($#kopie_ramce+1)." �len�.\n");
        # Proj�t �leny r�mce a pro ka�d� hledat realizaci mezi d�tmi.
        #   my $dbgj = 0;
        for(my $j = 0; $j<=$#kopie_ramce; $j++)
        {
            #       print((++$dbgj).". �len ".($i+1).". r�mce je $kopie_ramce[$j].\n");
            # �len se skl�d� z upraven� m-zna�ky a ze s-zna�ky. Odstranit
            # s-zna�ku, m-zna�ku porovnat s m-zna�kou d�t�te.
            $kopie_ramce[$j] =~ s-^(.*?)/.*$-$1-;
            # Proj�t d�ti a hledat mezi nimi realizaci dan�ho �lenu.
            for(my $k = 0; $k<=$#deti; $k++)
            {
                # Jestli�e dan� d�t� je realizac� dan�ho �lenu, odstranit
                # �len z kopie r�mce a hledat dal�� �len.
                if(odpovida_skzn_mzn($kopie_ramce[$j], $anot[$deti[$k]]{znacka}))
                {
                    splice(@kopie_ramce, $j, 1);
                    $j--;
                    last;
                }
            }
        }
        # �leny, kter� v kopii r�mce zbyly, nena�ly realizaci. Zapamatovat si
        # jejich po�et a zjistit, jestli je rekordn� mal�.
        $n_zbylo[$i] = $#kopie_ramce+1;
        if($i==0 || $n_zbylo[$i]<$min_zbylo)
        {
            $min_zbylo = $n_zbylo[$i];
            $i_min_zbylo = $i;
        }
    }
    # Vr�tit prvn� r�mec, kter�mu zbylo nejm�n� nerealizovan�ch �len�.
    return @{$o_ramce_s->[$i_min_zbylo]};
}



#------------------------------------------------------------------------------
# Najde v�echna mo�n� sesazen� dvou r�mc� (p�rov�n� jejich �len�). Mo�n� je
# takov� sesazen�, ve kter�m jsou sp�rov�ny pouze �leny se stejnou zna�kou.
# N�kter� �leny v�ak mohou z�stat nesp�rov�ny, p�esto�e jejich potenci�ln�
# prot�j�ek existuje.
#
# Vstupem jsou odkazy na dv� pole prvk�, typicky morfologick�ch zna�ek, ve
# stejn� sad�! (Pokud r�mec A pou��val jin� zna�ky ne� r�mec B, mus� se p�ev�st
# je�t� p�ed pokusem o sesazen�.) Pole nemusej� b�t stejn� dlouh�.
#
# V�stupem je odkaz na pole sesazen�, kter� m� n�sleduj�c�strukturu:
#
# Stav �lenu r�mce = "", pokud je�t� nebyl sp�rov�n, jinak index jeho prot�j�ku
# ve druh�m r�mci. Stav r�mce = pole stav� �len� r�mce. Stav sesazov�n� =
# dvou�lenn� pole [0..1] stav� r�mc�. Nad t�m v��m pole alternativn�ch
# sesazen�, resp. stav� sesazen�: jsou dv�, jedno uchov�v� stavy po minul�m
# kole, ve druh�m se objevuj� alternativy prodlou�en� (a rozv�tven�) pr�v� o
# jeden p�r nebo nesp�rovateln� �len.
#------------------------------------------------------------------------------
sub sesadit_ramce
{
    my $o_a = $_[0];
    my $o_b = $_[1];
    my ($i, $j, $k, $l, $m);
    my @sesaz;
    # Existuje nejm�n� jedno sesazen�, to obsahuje n osam�l�ch prvk� a ��dn�
    # p�ry.
    $sesaz[0][0][0] = "";
    $sesaz[0][1][0] = "";
    # Proj�t prvky pole A.
    for($i = 0; $i<=$#{$o_a}; $i++)
    {
        # Proj�t prvky pole B, hledat obrazy i-t�ho prvku A.
        for($j = 0; $j<=$#{$o_b}; $j++)
        {
            # Zjistit, zda j-t� prvek B odpov�d� i-t�mu prvku A.
            if($o_a->[$i] eq $o_b->[$j])
            {
                # Proj�t rozpracovan� sesazen� a zjistit, do kter�ch jde
                # p�idat nov� nalezen� p�r.
                for($k = 0; $k<=$#sesaz; $k++)
                {
                    # Zjistit, zda je v dan�m sesazen� voln� j-t� B.
                    if($sesaz[$k][1][$j] eq "")
                    {
                        # Naklonovat toto sesazen�. Ponechat variantu bez
                        # nov�ho p�ru a p�idat variantu s nov�m p�rem.
                        $#sesaz++;
                        for($l = 0; $l<=1; $l++)
                        {
                            for($m = 0; $m<=$#{$sesaz[$k][$l]}; $m++)
                            {
                                $sesaz[$#sesaz][$l][$m] = $sesaz[$k][$l][$m];
                            }
                        }
                        $sesaz[$#sesaz][0][$i] = $j;
                        $sesaz[$#sesaz][1][$j] = $i;
                    }
                }
            }
        }
    }
    return \@sesaz;
}



###############################################################################
# R�zn�
###############################################################################



#------------------------------------------------------------------------------
# Zjist� dopl�kov� parametry z�vislosti.
# �te glob�ln� prom�nn� @slova a $sloveso.
#------------------------------------------------------------------------------
sub zjistit_smer_a_delku
{
    my $r = $_[0];
    my $z = $_[1];
    my $smer;
    my $delka;
    my($j0, $j1, $j);
    if($r==0)
    {
        # U ko�ene n�s nezaj�m� sm�r, ale zaj�m� n�s existence slovesa.
        $smer = $sloveso ? "V" : "N";
    }
    else
    {
        # Zjistit sm�r z�vislosti (doprava nebo doleva).
        $smer = $r<$z ? "P" : "L";
    }
    # Zjistit d�lku z�vislosti (daleko nebo bl�zko (v sousedstv�)).
    $delka = abs($r-$z)>1 ? "D" : "B";
    # Roz���it d�lku o informaci, zda se mezi $r a $z nach�z� ��rka.
    if($delka eq "D")
    {
        if($smer eq "L")
        {
            $j0 = $z+1;
            $j1 = $r-1;
        }
        else
        {
            $j0 = $r+1;
            $j1 = $z-1;
        }
        for($j = $j0; $j<=$j1; $j++)
        {
            if($slova[$j] eq ",")
            {
                $delka = ",";
                last;
            }
        }
    }
    return $smer, $delka;
}



#------------------------------------------------------------------------------
# P�evede (neredukovanou) morfologickou zna�ku na subkategoriza�n�.
#------------------------------------------------------------------------------
sub prevest_mznacku_na_vazbu
{
    my $mznacka = $_[0];
    my $heslo = $_[1];
    # Z�kladem vazby je slovn� druh. Podstatn� jm�na, p��davn� jm�na, z�jmena
    # a ��slovky v�ak pova�ujeme za jedin� slovn� druh. V�jimkou jsou ur�it�
    # v�skyty zvratn�ch z�jmen "se" a "si" (vlastn� jen ty, v nich� vystupuj�
    # jako zvratn� ��stice. Nikdy v�ak nemaj� morfologickou zna�ku ��stice.
    my $vazba = substr($mznacka, 0, 1);
    if($vazba eq "P" && $heslo =~ m/^(se|si)/)
    {
        $vazba = PR;
    }
    else
    {
        $vazba =~ s/[APC]/N/;
    }
    # P�es pod�ad�c� spojky vis� na slovesech z�visl� klauze (�e, aby...)
    if(substr($mznacka, 0, 2) eq "J,")
    {
        $vazba = "JS";
    }
    # Pokud vis� na slovese jin� ur�it� sloveso, jde o klauzi (kter�...)
    # nebo o p��mou �e�.
    if($mznacka =~ m/^V[^f]/)
    {
        $vazba = "S";
    }
    # Pokud vis� na slovese infinitiv, chceme to vyj�d�it z�eteln�ji.
    if(substr($mznacka, 0, 2) eq "Vf")
    {
        $vazba = "VINF";
    }
    # P��slovce byla zna�ena DB (i pokud jejich m-zna�ka je Dg).
    if($vazba eq "D")
    {
        $vazba = "DB";
    }
    # Je-li relevantn� p�d, p�idat ho (m��e nastat u v��e uveden�ch a u
    # p�edlo�ek.
    my $pad = substr($mznacka, 4, 1);
    if($pad ne "-")
    {
        $vazba .= $pad;
    }
    # U p�edlo�ek a pod�ad�c�ch spojek p�idat do z�vorky heslo.
    # Tot� plat� i o slovech "jak" a "pro�", kter� jsou sice ve slovn�ku
    # vedena jako p��slovce, ale anot�to�i je ob�as pov�sili jako AuxC.
    # Kv�li t�to nekonzistenci se tu mus� objevit jazykov� z�visl� seznam.
    if($vazba =~ m/^(R|JS)/ ||
    $vazba eq "DB" && $heslo =~ m/^(jak|pro�)(?:[-_].*)?$/)
    {
        # Z hesla odstranit p��padn� rozli�en� v�znam� za poml�kou.
        $heslo =~ s/-.*//;
        $vazba .= "($heslo)";
    }
    return $vazba;
}
