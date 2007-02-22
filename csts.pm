# Funkce pro na��t�n� lingvisticky anotovan�ch text� ve form�tu CSTS.
# - na�te podstatn� informace o slovu z jednoho ��dku CSTS (funkce zpracovat_slovo())
#   - u� p�i na��t�n� n�kter� data zpracuje, nap�. p�iprav� upravenou morfologickou zna�ku
# - um� proj�t celou mno�inu soubor� na disku (pomoc� glob masky; funkce projit_data()),
#   postupn� je otv�rat, na��tat slova a po zkompletov�n� ka�d� v�ty zavolat funkci
#   zpracovat_vetu(), kterou v�ak tento modul nedefinuje - mus� si ji definovat ten,
#   kdo modul vyu��v�, a to v prostoru main::. Funkce dostane od modulu csts t�i
#   parametry:
#   - odkaz na hash s informacemi o aktu�ln�m dokumentu, odstavci a v�t�;
#   - odkaz na pole slov v�ty a
#   - odkaz na pole hash� s anotacemi slov.
package csts;



###############################################################################
# Anotace slova
###############################################################################



#------------------------------------------------------------------------------
# Zpracuje prom�nnou $_ jako ��dek CSTS, obsahuj�c� informace o pr�v� jednom
# slov�. Vr�t� hash s informacemi o slov�, ur�en� k za�azen� do pole @anot.
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
    my $konfig = shift; # odkaz na hash
    my %anot; # v�stupn� hash
    #==========================================================================
    # Index slova ve v�t� (CSTS zna�ka <r>; nemus� nutn� odpov�dat skute�n�mu
    # po�ad� slova ve v�t� a na tektogramatick� rovin� ani nemus� b�t celo��-
    # seln�).
    #==========================================================================
    if(m/<r>(\d+)/)
    {
        $anot{ord} = $1;
    }
    #==========================================================================
    # Mezera p�ed slovem (CSTS zna�ka <D>).
    #==========================================================================
    $anot{mezera} = !$bezmezery;
    #==========================================================================
    # P�e��st slovn� tvar.
    #==========================================================================
    m/<[fd]( [^>]*)?>([^<]+)/;
    $anot{slovo} = $2;
    $anot{slovo} =~ tr/A�BC�D�E��FGHI�JKLMN�O�PQR�S�T�U��VWXY�Z�/a�bc�d�e��fghi�jklmn�o�pqr�s�t�u��vwxy�z�/;
    #==========================================================================
    # P�e��st heslov� tvar.
    #==========================================================================
    m/<$konfig->{mzdroj0}l[^>]*>([^<]+)/;
    #     heslo ... heslo ze zvoleneho zdroje (<MMl>, <MDl>, <l>)
    #     lexkat ... poznamka za podtrzitkem, ze stejneho zdroje jako heslo
    $anot{heslo} = $1;
    $anot{heslo} =~ s/_(.*)$//;
    $anot{lexkat} = $1;
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
    $anot{mozne_znacky} = "";
    my $schranka = $_;
    while($schranka =~ s/<MMt[^>]*>(...............)//)
    {
        $anot{mozne_znacky} .= "|$1";
    }
    $anot{mozne_znacky} =~ s/^\|//;
    # P�e��st zna�ky p�i�azen� �lov�kem a ob�ma taggery.
    if($schranka =~ m/<t>(...............)/)
    {
        $anot{znacka_clovek} = $1;
    }
    if($schranka =~ m/<MDt[^>]*?src="a"[^>]*?>(...............)/)
    {
        $anot{znacka_mdta} = $1;
    }
    if($schranka =~ m/<MDt[^>]*?src="b"[^>]*?>(...............)/)
    {
        $anot{znacka_mdtb} = $1;
    }
    # Vybrat zna�ku ze zdroje po�adovan�ho v konfiguraci.
    if($konfig->{mzdroj0} eq "MM")
    {
        $anot{znacka} = $anot{mozne_znacky};
    }
    elsif($konfig->{mzdroj0} eq "")
    {
        $anot{znacka} = $anot{znacka_clovek};
    }
    elsif($konfig->{mzdroj0} eq "MD")
    {
        if($konfig->{mzdroj1} eq "a")
        {
            $anot{znacka} = $anot{znacka_mdta};
        }
        elsif($konfig->{mzdroj1} eq "b")
        {
            $anot{znacka} = $anot{znacka_mdtb};
        }
    }
    #==========================================================================
    # Upravit morfologickou zna�ku.
    #==========================================================================
    if($konfig->{upravovat_mzn})
    {
        $anot{uznacka} = join("|", sort(map
        {
            upravit_mznacku($_, $anot{lexkat}, $anot{heslo}, $anot{slovo}, $konfig);
        }
        (split(/\|/, $anot{znacka}))));
    }
    else
    {
        $anot{uznacka} = join("|", sort(split(/\|/, $anot{znacka})));
    }
    # Odstranit p��padn� duplik�ty (kv�li tomu jsme zna�ky t��dili).
    while($anot{uznacka} =~ s/([^\|]+)\|\1/$1/g) {}
    #==========================================================================
    # Zjistit syntaktickou strukturu a syntaktickou zna�ku.
    #==========================================================================
    if(m/<g>(\d+)/)
    {
        $anot{rodic_vzor} = $1;
    }
    if(m/<A>([^<]+)/)
    {
        $anot{afun} = $1;
        if($anot{afun}=~m/$konfig->{"vynech"}/)
        {
            $vynechat_vetu = 1;
        }
    }
    # Dal�� syntaktick� anotace ulo�it do obecn�ho pole hash�.
    if(m/<MDg src="(.*?)">(\d+)/)
    {
        $anot{"mdg".$1} = $2;
    }
    return \%anot;
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
    my $znacka = shift; # p�vodn� pozi�n� zna�ka z PDT (15 znak�)
    my $lznacka = shift; # stylistick� a v�znamov� kategorie (z Haji�ova lemmatu za podtr��tkem)
    my $heslo = shift; # ��st lemmatu p�ed podtr��tkem (ale v�etn� p�. poml�ky a ��sla)
    my $slovo = shift; # slovn� tvar
    my $konfig = shift; # odkaz na hash s konfigurac�
    # Pou��t baltimorskou redukci zna�ek, je-li to po�adov�no.
    if($konfig->{upravovat_mzn}==1)
    {
        return upravit_mznacku_baltimore($znacka);
    }
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
    }
    # Selektivn� lexikalizace zna�ek.
    if($konfig->{selex})
    {
        # Z�jmena
        if($konfig->{selex_zajmena} && $znacka=~m/^P/)
        {
            # Zvratn� z�jmena "se" a "si".
            if($slovo=~m/(se|si)/)
            {
                $znacka = "P".$slovo;
            }
            else
            {
                $znacka .= $heslo;
            }
        }
        elsif($znacka=~m/^V/)
        {
            # Pomocn� sloveso b�t lexikalizovat tvarem, ne heslem.
            # Je pot�eba rozli�it, kdy m� b�t naho�e a kdy dole.
            # Pochopiteln� je to opat�en� funk�n� jen v �e�tin�, ale jinde by nem�lo �kodit.
            if($konfig->{selex_byt} && $heslo eq "b�t")
            {
                my $byt = $slovo;
                $byt =~ s/^ne//;
                $byt =~ s/ti$/t/;
                $byt =~ s/byl[aoiy]/byl/;
                $znacka = "V".$byt;
            }
        }
        elsif($konfig->{selex_prislovce_100} && $znacka=~m/^D/)
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
        elsif($konfig->{selex_predlozky} && $znacka=~m/^R/)
        {
            $znacka = "R".$heslo;
        }
        elsif($konfig->{selex_podradici_spojky} && $znacka=~m/^J/ && $slovo=~m/(�e|aby|zda)/)
        {
            $znacka = "J".$slovo;
            $znacka =~ s/zdali/zda/;
        }
    }
    return $znacka;
}



#------------------------------------------------------------------------------
# Uprav� morfologickou zna�ku p�ibli�n� tak, jak jsem to d�lal v Baltimoru.
# Tenkr�t jsem na to m�l funkci, kter� manipulovala s jednotliv�mi mluvnick�mi
# kategoriemi. Dnes m�m pouze seznam neredukovan�ch zna�ek a jejich redukova-
# n�ch prot�j�k�. Chyb� v n�m v�ak manipulace se zna�kami interpunkce, kter�
# byly naopak u� tehdy selektivn� lexikalizov�ny, a tak� n�kter� zm�ny, kter�
# vedly na neexistuj�c� zna�ku, tak�e program, kter�m jsem si pozd�ji vyr�b�l
# konverzn� slovn��ek, u� si s nimi neum�l poradit.
#------------------------------------------------------------------------------
sub upravit_mznacku_baltimore()
{
    my $znacka = shift; # p�vodn� pozi�n� zna�ka z PDT (15 znak�)
    # Jestli�e dosud nebyl na�ten p�evodn� slovn��ek, na��st ho.
    unless(exists($redukce_baltimore{"NNMSX-----A----"}))
    {
        open(SLOVNIK, "vyzkum/znacky/stara_redukce_pozicnich.txt")
            or die("Nelze otevrit soubor vyzkum/znacky/stara_redukce_pozicnich.txt: $!\n");
        while(<SLOVNIK>)
        {
            if(m/^(\S+) (\S+)/)
            {
                $redukce_baltimore{$1} = $2;
            }
        }
        close(SLOVNIK);
    }
    if(exists($redukce_baltimore{$znacka}))
    {
        return $redukce_baltimore{$znacka};
    }
    else
    {
        return $znacka;
    }
}



###############################################################################
# Proch�zen� dat
###############################################################################



#------------------------------------------------------------------------------
# Projde tr�novac� nebo testovac� data a na ka�dou v�tu zavol� funkci
# zpracovat_vetu(). Tato funkce je callback, tj. mus� b�t definov�na u toho,
# kdo po��dal o projit� dat.
# Parametrem je cesta k soubor�m s daty. M��e obsahovat z�stupn� znaky.
# Zat�m se pou��v� glob�ln� pole @soubory, proto�e zpracovat_vetu() v train.pl
# chce seznam soubor� zn�t. M�lo by se to ale rozd�lit. Glob�ln� $isoubor.
#------------------------------------------------------------------------------
sub projit_data
{
    my $maska = shift; # cesta ke vstupn�m soubor�m, s maskou (nap�. *.csts)
    my $konfig = shift; # odkaz na hash s konfigurac�
    @soubory = glob($maska);
    # Vygenerovat ud�lost "za��tek �ten� sady soubor�".
    if(exists($konfig->{hook_zacatek_cteni}))
    {
        &{$konfig->{hook_zacatek_cteni}}($maska, \@soubory);
    }
    my %stav; # r�zn� informace o tom, kde v datech se nach�z�me
    vymazat_vetu(\%stav, \@anot);
    for(my $isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
        # Nepl�st se $stav{doksoubor}, ten uchov�v� jm�no souboru, ve kter�m za�al aktu�ln� dokument.
        $stav{soubor} = $soubory[$isoubor];
        $stav{novy_soubor} = 1; # Vynuluje se po prvn� v�t� souboru.
        open(SOUBOR, $soubory[$isoubor]) or die("Nelze otevrit soubor $soubory[$isoubor]: $!\n");
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
            elsif(m/^<s(?: id="(.*?)")?>/)
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
                push(@anot, zpracovat_slovo($konfig));
                # Glob�ln� prom�nn�!
                $bezmezery = 0;
            }
        }
        close(SOUBOR);
    }
    if($#anot>0)
    {
        # Nastavit p��znak posledn� v�ty, aby funkce zpracovat_vetu() provedla
        # naposledy i v�echny akce, kter� d�l� v�dy jednou za �as.
        $stav{posledni_veta} = 1;
        skoncila_veta(\%stav, \@anot);
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
        if($anot->[$#{$anot}]{uznacka}=~m/^Z/)
        {
            $anot->[$#{$anot}]{slovo} .= "K";
            $anot->[$#{$anot}]{heslo} .= "K";
            $anot->[$#{$anot}]{uznacka} .= "K";
        }
        # Zd�dit morfologick� zna�ky u koordinac� a apozic.
        zjistit_znacky_podstromu($anot);
        # Prov�st vlastn� zpracov�n� definovan� aplikac�.
        main::zpracovat_vetu($stav, $anot);
        # P�ipravit se na �ten� dal�� v�ty.
        vymazat_vetu($stav, $anot);
        return 1;
    }
    else
    {
        return 0;
    }
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
# Funkce �te glob�ln� pole @anot. Pln� glob�ln� hash @anot[$i]{mznpodstrom} a
# @anot[$i]{coordmember}.
#------------------------------------------------------------------------------
sub zjistit_znacky_podstromu
{
    my $anot = shift; # odkaz na pole hash�
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        $anot->[$i]{coordmember} = 0;
    }
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Koordinace a apozice d�d� zna�ky sv�ch �len� (nikoli v�ech sv�ch
        # d�t�). Vno�en� koordinace a apozice se proch�zej� opakovan� (jednou
        # kv�li sv� morfologick� zna�ce a jednou nebo v�ckr�t kv�li zna�k�m
        # sv�ch nad��zen�ch), ale rezignuju na efektivitu v�po�tu ve prosp�ch
        # efektivity programov�n�: hlavn� kdy� to bude jednoduch� a snadno
        # roz�i�iteln�.
#        if($anot->[$i]{afun}=~m/^(Coord|Apos)/)
        if($anot->[$i]{afun}=~m/^Coord/)
        {
            my @clenove = zjistit_skutecne_cleny_koordinace($anot, $i);
            for(my $j = 0; $j<=$#clenove; $j++)
            {
                # A� se bude d�dit i jinde ne� u koordinac� a apozic, bude asi
                # pot�eba tady br�t zd�d�nou zna�ku m�sto p�vodn�, to se pak
                # ale bude taky muset o�et�it, kter� d�d�n� prob�hne d��v.
                $anot->[$i]{mznpodstrom} .= "|".$anot->[$clenove[$j]]{uznacka};
                $anot->[$clenove[$j]]{coordmember} = 1;
            }
            # Odstranit svisl�tko p�ed prvn� zna�kou.
            $anot->[$i]{mznpodstrom} =~ s/^\|//;
        }
        else
        {
            $anot->[$i]{mznpodstrom} = $anot->[$i]{uznacka};
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
    my $anot = shift; # odkaz na pole hash�
    my $koren = shift; # index ko�ene koordinace
    my @clenove;
    # Proj�t v�echny uzly stromu, hledat d�ti ko�ene.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # �leny koordinace mohou b�t n�kter� d�ti ko�ene.
        if($anot->[$i]{rodic_vzor}==$koren)
        {
            # �len koordinace se pozn� podle syntaktick� zna�ky kon��c� na _Co.
            # �len apozice se pozn� podle syntaktick� zna�ky kon��c� na _Ap.
            if($anot->[$i]{afun} =~ m/_(Co|Ap)$/)
            {
                # Pokud je �lenem vno�en� koordinace nebo apozice, zaj�maj� n�s
                # jej� �leny, ne jej� ko�en.
                if($anot->[$i]{afun} =~ m/^(Coord|Apos)/)
                {
                    splice(@clenove, $#clenove+1, 0,
                    zjistit_skutecne_cleny_koordinace($anot, $i));
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
            elsif($anot->[$i]{afun} =~ m/Aux[PC]/)
            {
                # Zjistit, zda alespo� jedno d�t� p�edlo�ky m� s-zna�ku kon��c�
                # na _Co nebo _Ap.
                my @clenove_pod_predl = zjistit_skutecne_cleny_koordinace($anot, $i);
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
    # Jestli�e to byla prvn� v�ta souboru, o p��t� v�t� u� se nesm� tvrdit tot�.
    $stav->{novy_soubor} = 0;
    splice(@{$anot});
    $anot->[0]{slovo} = "#";
    $anot->[0]{heslo} = "#";
    $anot->[0]{znacka} = "Z#-------------";
    $anot->[0]{uznacka} = "#";
    $anot->[0]{rodic_vzor} = -1;
    $anot->[0]{afun} = "AuxS";
    # Informace o v�t�.
    $sloveso = 0; # Zda v�ta obsahuje sloveso.
    $vynechat_vetu = 0;
}



#------------------------------------------------------------------------------
# Strom je v souboru reprezentov�n ��seln�mi odkazy od z�visl�ho uzlu k ��d�c�-
# mu. Takto lze ov�em zapsat i struktury, kter� nejsou stromy. Pokud se boj�me,
# �e na��tan� data mohou b�t nekorektn�, tato funkce je zkontroluje.
#------------------------------------------------------------------------------
sub je_strom
{
    my $anot = shift;
    my $zdroj = shift; # pokud je v�ce struktur, kter� se m� kontrolovat?
    $zdroj = "rodic_vzor" if($zdroj eq "");
    # Zjistit, zda v�echny odkazy vedou na existuj�c� uzel, zda v�echny kon��
    # v nule, a netvo�� tud� cykly ani nejde o nesouvisl� les.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Kv�li cykl�m si evidovat v�echny uzly, kter�mi jsme pro�li na cest�
        # ke ko�eni. Do cyklu toti� m��eme vstoupit a� u n�kter�ho p�edka!
        my @evidence;
        for(my $j = $i; $j>0; $j = $anot->[$j]{$zdroj})
        {
            if($anot->[$j]{$zdroj} !~ m/^\d+$/ ||
               $anot->[$j]{$zdroj}<0 ||
               $anot->[$j]{$zdroj}>$#{$anot} ||
               $evidence[$j])
            {
                return 0;
            }
            $evidence[$j] = 1;
        }
    }
    return 1;
}



1;
