#!/usr/bin/perl
# Knihovní funkce parseru potøebné jak pøi tréninku, tak pøi analýze.
use vystupy;



# Pøeèíst konfiguraèní soubor.
my $konfig_log;
open(SOUBOR, "parser.ini");
while(<SOUBOR>)
{
    # V¹echny øádky konfiguraèního souboru si zatím pamatovat, aby bylo pozdìji mo¾né vypsat je do logu.
    # Nemù¾eme je vypsat hned, proto¾e zpùsob vypisování je konfigurací také ovlivnìn.
    $konfig_log .= $_;
    # Smazat z konfiguraèního souboru komentáøe.
    s/#.*//;
    # Zbytek má tvar "promìnná = hodnota".
    if(m/(\w+)\s*=\s*(.*)/)
    {
        $konfig{$1} = $2;
    }
}
close(SOUBOR);
# Konfiguraci ze souboru lze pøebít konfigurací z pøíkazového øádku.
# Jednou budu umìt asi cokoliv typu "--atribut hodnota", ale zatím umím jediné: "-q" znamená "ticho=1".
for(my $i = 0; $i<=$#ARGV; $i++)
{
    if($ARGV[$i] eq "-q")
    {
        $konfig{"ticho"} = 1;
    }
}
# Zaznamenat konfiguraci do logu.
# (Nemohlo se to udìlat rovnou, proto¾e samo zapisování do logu je konfigurací také ovlivnìno.)
# Zalo¾it hlavní záznam o parametrech výpoètu.
vypsat("konfig", ""); # zajistit zalozeni cisla instance
vypsat("konfig", "Výpoèet èíslo $vystupy::cislo_instance byl spu¹tìn v ".cas($::starttime)." na poèítaèi $ENV{HOST} jako proces èíslo $$.\n");
vypsat("konfig", "\n$konfig_log\n");



###############################################################################
# Procházení dat
###############################################################################
sub transformovat_koordinace { }


#------------------------------------------------------------------------------
# Projde trénovací nebo testovací data a na ka¾dou vìtu zavolá funkci
# zpracovat_vetu(). Tato funkce je callback, tj. musí být definována u toho,
# kdo po¾ádal o projití dat.
# Parametrem je cesta k souborùm s daty. Mù¾e obsahovat zástupné znaky.
# Zatím se pou¾ívá globální pole @soubory, proto¾e zpracovat_vetu() v train.pl
# chce seznam souborù znát. Mìlo by se to ale rozdìlit. Vstupem je
# $konfig{train}. A globální $isoubor a $ord.
#------------------------------------------------------------------------------
sub projit_data
{
    my $maska = $_[0];
    vypsat("prubeh", "Maska pro jména souborù s daty: $maska\n");
    @soubory = glob($maska);
    vypsat("prubeh", "Nalezeno ".($#soubory+1)." souborù.\n");
    my %stav; # rùzné informace o tom, kde v datech se nacházíme
    vymazat_vetu(\%stav, \@anot);
    for($isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
        open(SOUBOR, $soubory[$isoubor]);
        vypsat("prubeh", "Otvira se soubor $soubory[$isoubor]\n");
        while(<SOUBOR>)
        {
            # Zapamatovat si zaèátek dokumentu.
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
            # Zapamatovat si zaèátek odstavce.
            # <p n=1>
            elsif(m/<p\s+n=(\d+)>/)
            {
                my $nove_cislo_odstavce = $1;
                skoncila_veta(\%stav, \@anot);
                # Ze znaèky zaèátku dokumentu automaticky vyplývá i zaèátek odstavce.
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
                # Globální promìnná!
                $bezmezery = 1;
            }
            elsif(m/^<[fd][ >]/)
            {
                zpracovat_slovo();
                # Globální promìnná!
                $bezmezery = 0;
            }
        }
        close(SOUBOR);
    }
    if($ord>0)
    {
        # Nastavit pøíznak poslední vìty, aby funkce zpracovat_vetu() provedla
        # naposledy i v¹echny akce, které dìlá v¾dy jednou za èas.
        $posledni_veta = 1;
        skoncila_veta("K", \@anot);
    }
}



#------------------------------------------------------------------------------
# Uzlový bod, volá se v¾dy, kdy¾ musí skonèit vìta, pokud tedy nìjaká vùbec
# zaèala. Volá se na zaèátku dokumentu, odstavce a vìty a na konci dat.
#------------------------------------------------------------------------------
sub skoncila_veta
{
    my $stav = shift; # rùzné informace o tom, kde v datech se nacházíme
    my $anot = shift; # odkaz na pole hashù s informacemi o slovech vìty (0 je koøen)
    if($#{$anot}>0)
    {
        # Upravit znaèku koncové interpunkce (to nemù¾eme udìlat, dokud
        # nevíme, ¾e dotyèné slovo je poslední).
        if($anot->[$#slova]{uznacka}=~m/^Z/)
        {
            $slova[$#slova] .= "K";
            $anot->[$#slova]{slovo} .= "K";
            $anot->[$#slova]{heslo} .= "K";
            $anot->[$#slova]{uznacka} .= "K";
        }
        # Zdìdit morfologické znaèky u koordinací a apozic.
        zjistit_znacky_podstromu();
        # Provést vlastní zpracování definované aplikací.
        zpracovat_vetu($stav, $anot);
        # Pøipravit se na ètení dal¹í vìty.
        vymazat_vetu($stav, $anot);
        return 1;
    }
    else
    {
        return 0;
    }
}



#------------------------------------------------------------------------------
# Vyma¾e v¹echny globální promìnné popisující vìtu, které vznikly v proceduøe
# zpracovat_slovo. Typicky se volá na zaèátku procedury zpracovat_vetu, aby
# bylo kam naèítat dal¹í vìtu. Tato funkce také rovnou vyplní nìkteré údaje o
# koøeni, proto¾e ty jsou ve v¹ech vìtách stejné, ale z dat se je nedozvíme.
#------------------------------------------------------------------------------
sub vymazat_vetu
{
    my $stav = shift; # rùzné informace o tom, kde v datech se nacházíme
    my $anot = shift; # odkaz na pole hashù s informacemi o slovech vìty (0 je koøen)
    $stav->{predel} = "S"; # D pro dokument, P pro odstavec, S pro vìtu (default), K pro poslední vìtu
    # Informace o slovech.
    splice(@slova);
    splice(@{$anot});
    $slova[0] = "#";
    $anot->[0]{slovo} = "#";
    # Rùzné informace.
    $anot->[0]{heslo} = "#";
    $anot->[0]{znacka} = "Z#-------------";
    $anot->[0]{uznacka} = "#";
    # Index naposledy pøeèteného slova.
    $ord = 0;
    # Informace o vztazích.
    splice(@struktura);
    $struktura[0] = -1;
    $anot->[0]{rodic_vzor} = -1;
    splice(@afun);
    $afun[0] = "AuxS";
    $anot->[0]{afun} = "AuxS";
    # Informace o vìtì.
    $sloveso = 0; # Zda vìta obsahuje sloveso.
    $vynechat_vetu = 0;
}



#------------------------------------------------------------------------------
# Vrátí aktuální èas jako øetìzec s polo¾kami oddìlenými dvojteèkou. Délka
# øetìzce je v¾dy stejná (8 znakù), co¾ lze vyu¾ít pøi sloupcovém formátování.
#------------------------------------------------------------------------------
sub cas
{
    my($h, $m, $s);
    ($s, $m, $h) = localtime(time());
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}



#------------------------------------------------------------------------------
# Vypí¹e dobu, po kterou program bì¾el. K tomu potøebuje dostat èasové otisky
# zaèátku a konce.
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
    vypsat($soubor, "Výpoèet skonèil v ".cas($stoptime).".\n");
    vypsat($soubor, sprintf("Program bì¾el %02d:%02d:%02d hodin.\n", $hod, $min, $sek));
}



###############################################################################
# Anotace slova
###############################################################################



#------------------------------------------------------------------------------
# Naète slovo ze vstupu.
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
    # Mezera pøed slovem (CSTS znaèka <D>).
    #==========================================================================
    $anot[$ord]{mezera} = !$bezmezery;
    #==========================================================================
    # Pøeèíst slovní tvar.
    #==========================================================================
    m/<[fd]( [^>]*)?>([^<]+)/;
    $slova[$ord] = $2;
    $slova[$ord] =~ tr/AÁBCÈDÏEÉÌFGHIÍJKLMNÒOÓPQRØS©T«UÚÙVWXYÝZ®/aábcèdïeéìfghiíjklmnòoópqrøs¹t»uúùvwxyýz¾/;
    $anot[$ord]{slovo} = $slova[$ord];
    #==========================================================================
    # Pøeèíst heslový tvar.
    #==========================================================================
    m/<$konfig{mzdroj0}l[^>]*>([^<]+)/;
    #     heslo ... heslo ze zvoleneho zdroje (<MMl>, <MDl>, <l>)
    #     lexkat ... poznamka za podtrzitkem, ze stejneho zdroje jako heslo
    $anot[$ord]{heslo} = $1;
    $anot[$ord]{heslo} =~ s/_(.*)$//;
    $anot[$ord]{lexkat} = $1;
    #==========================================================================
    # Pøeèíst morfologickou znaèku.
    #==========================================================================
    #  znacka - morfologicka, neupravovana!
    #     znacka ... morfologicka znacka ze zvoleneho zdroje (<MMt>, <MDt>, <t>)
    #     mozne_znacky ... znacky ze slovniku <MMt>
    #     znacka_clovek ... znacka prirazena clovekem <t>
    #     znacka_mdta ... znacka podle taggeru a <MDt src="a">
    #     znacka_mdtb ... znacka podle taggeru b <MDt src="b">
    #     uznacka ... ze zvoleneho zdroje, ale upravena (jsou-li upravy povolene)
    #     zdznacka ... zdedena znacka (koren koordinace dedi od clenu)
    # Pøeèíst seznam mo¾ných znaèek ze slovníku.
    $anot[$ord]{mozne_znacky} = "";
    my $schranka = $_;
    while($schranka =~ s/<MMt[^>]*>(...............)//)
    {
        $anot[$ord]{mozne_znacky} .= "|$1";
    }
    $anot[$ord]{mozne_znacky} =~ s/^\|//;
    # Pøeèíst znaèky pøiøazené èlovìkem a obìma taggery.
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
    # Vybrat znaèku ze zdroje po¾adovaného v konfiguraci.
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
    # Upravit morfologickou znaèku.
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
    # Odstranit pøípadné duplikáty (kvùli tomu jsme znaèky tøídili).
    while($anot[$ord]{uznacka} =~ s/(..)\|\1/$1/g) {}
    #==========================================================================
    # Zjistit syntaktickou strukturu a syntaktickou znaèku.
    #==========================================================================
    if(m/<g>(\d+)/)
    {
        $struktura[$ord] = $1;
        # Novìj¹í pøístup: ve¹keré anotace kromì slova samého jsou v @anot.
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
    # Dal¹í syntaktické anotace ulo¾it do obecného pole hashù.
    if(m/<MDg src="(.*?)">(\d+)/)
    {
        $anot[$ord]{"mdg".$1} = $2;
    }
}



#------------------------------------------------------------------------------
# Pøeète ze vstupního øádku anotaci jednoho druhu. V¾dy vrátí pole, i kdyby
# neexistovaly alternativní anotace tého¾ druhu.
#------------------------------------------------------------------------------
sub zjistit_anotaci
{
    # Vstupní øádek týkající se jednoho slova.
    my $radek = $_[0];
    # Identifikace. Napø. "<MDt w="0.5" src="a">" se chytne na "MDt src=a".
    # Identifikace nemusí fungovat dobøe, obsahuje-li více ne¾ jeden atribut.
    my $ident = $_[1];
    # Pøipravit regulární výraz, podle kterého anotaci poznáme.
    # Tato funkce se bude volat velmi èasto, proto cachovat ji¾ známé regulární
    # výrazy.
    my $regex;
    if(exists($anot_regex{$ident}))
    {
        $regex = $anot_regex{$ident};
    }
    else
    {
        $regex = $ident;
        # Obalit hodnotu atributu volitelnými uvozovkami, pokud tam nejsou.
        $regex =~ s/(\w+)=(\w+)/$1=(?:$2|\"$2\"|\'$2\')/;
        # Dovolit dal¹í atributy a mezery.
        $regex =~ s/\s+/(?: [^>]*)? /g;
        # Obalit celé skobièkami, pøidat past na vlastní anotaci.
        $regex = "<$regex>([^<\r\n]*)";
        # Ulo¾it vytvoøený regulární výraz do cache.
        $anot_regex{$ident} = $regex;
    }
    # Pochytat v¹echny výskyty anotace.
    my @hodnoty;
    my $i = 0;
    while($radek =~ s/$regex//)
    {
        $hodnoty[$i++] = $1;
    }
    return @hodnoty;
}



#------------------------------------------------------------------------------
# Upraví morfologickou znaèku. Volá se pøi ètení znaèky, tedy z funkce
# zpracovat_slovo(). Zapisuje do globální promìnné $sloveso. Kontrolu výskytu
# slovesa je dobré dìlat tady, proto¾e jedno slovo mù¾e mít více znaèek a jen
# nìkteré z nich mohou být slovesné.
#------------------------------------------------------------------------------
sub upravit_mznacku()
{
    my $znacka = $_[0];
    my $lznacka = $_[1]; # stylistické a významové kategorie
    my $heslo = $_[2];
    my $slovo = $_[3];
    #==========================================================================
    # Kontrola výskytu slovesa (kvùli závislostem na koøeni).
    if($znacka =~ m/^V/)
    {
        $sloveso = 1;
    }
    #==========================================================================
    # Øadovou èíslovku pova¾ovat za pøídavné jméno.
    $znacka =~ s/^Cr/AA/;
    # Zkrátit znaèku na dva znaky (slovní druh a pád nebo poddruh).
    $znacka =~ m/^(.)(.)..(.)/;
    $znacka = $3=="-" ? $1.$2 : $1.$3;
    $znacka .= $osoba;
    # Machinace se znaèkami.
    if($znacka=~m/^N/ && $lznacka=~m/Y/)
    {
        $znacka =~ s/^N/NY/;
    }
    # Lexikalizace znaèek pro interpunkci.
    elsif($znacka eq "Z:")
    {
        $znacka = "Z".$slovo;
        # Zbavit se bì¾nìj¹ích zvlá¹tních znakù ve znaèce, aby se s ní lépe zacházelo jako s textovým atomem.
        # POZOR, sni¾uje to úspì¹nost, i kdy¾ jen malinko! Zøejmì se nìkde v kódu odkazuju pøímo na konkrétní znaèky!
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
    # Selektivní lexikalizace znaèek.
    if($konfig{"selex"})
    {
        # Zájmena
        if($znacka=~m/^P/)
        {
            # Zvratná zájmena "se" a "si".
            if($slovo=~m/(se|si)/)
            {
                $znacka = "P".$slovo;
            }
            # Vzta¾ná zájmena "kdo", "co", "který", "jaký", "èí", "jen¾".
            #     elsif($heslo=~m/^(kdo|co|kter|jak|èí|jen¾)/)
            else
            #     elsif($heslo=~m/^(já|ty|on|my|vy|mùj|tvùj|jeho|její|ná¹|vá¹|jejich|svùj|ten|tento|tenhle|onen|takový|tý¾|tentý¾|sám|kdo|co|kter|jak|èí|jen¾)/)
            {
                $znacka .= $heslo;
            }
        }
        elsif($znacka=~m/^V/)
        {
            # Pomocné sloveso být lexikalizovat tvarem, ne heslem.
            # Je potøeba rozli¹it, kdy má být nahoøe a kdy dole.
            # Pochopitelnì je to opatøení funkèní jen v èe¹tinì, ale jinde by nemìlo ¹kodit.
            if($heslo eq "být")
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
            # Seznam pøíslovcí, která se vyskytla 100 a vícekrát.
            my @casta_prislovce =
            ("tak", "jak", "u¾", "také", "ji¾", "je¹tì", "vèera", "tedy",
            "pak", "více", "dnes", "pouze", "kde", "kdy", "napøíklad",
            "toti¾", "pøedev¹ím", "velmi", "zatím", "nyní", "právì", "stále",
            "zejména", "zcela", "dosud", "stejnì", "témìø", "letos", "dále",
            "sice", "tu", "dokonce", "navíc", "zde", "rovnì¾", "zøejmì",
            "pøitom", "napø", "vùbec", "tam", "èasto", "pøíli¹", "naopak",
            "zároveò", "v¾dy", "ménì", "tøeba", "opìt", "loni", "spí¹e",
            "snad", "dobøe", "proè", "zhruba", "pozdìji", "vlastnì", "mo¾ná",
            "samozøejmì", "skuteènì", "znovu", "tehdy", "pøesto", "nakonec",
            "spolu", "poté", "jinak", "proto", "døíve", "pøímo", "víc",
            "teï", "nikdy", "teprve", "vìt¹inou", "pøece", "jistì",
            "podobnì", "nìkdy", "hlavnì", "alespoò", "dost", "zase",
            "údajnì", "souèasnì", "postupnì", "celkem", "prakticky", "co",
            "hned", "dlouho", "nejvíce", "hodnì", "roènì", "nadále",
            "rychle", "potom", "nejménì", "trochu", "mnohem", "tady",
            "pomìrnì", "velice", "nedávno", "výraznì", "takto", "nikoli",
            "krátce", "ponìkud", "lépe", "pøesnì", "opravdu", "pøibli¾nì",
            "tì¾ko", "pravdìpodobnì", "podstatnì", "moc", "doma", "koneènì",
            "daleko", "zvlá¹tì", "prostì", "spoleènì", "pùvodnì", "mj",
            "apod", "novì", "spí¹", "pøípadnì", "pøedem", "naprosto", "dál",
            "úplnì", "rozhodnì", "veèer", "okam¾itì", "dennì", "nikoliv",
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
        elsif($znacka=~m/^J/ && $slovo=~m/(¾e|aby|zda)/)
        {
            $znacka = "J".$slovo;
            $znacka =~ s/zdali/zda/;
        }
    }
    return $znacka;
}



###############################################################################
# Dìdìní morfologických znaèek u koordinací a apozic.
# Vztahuje se ke slovùm, ale zji¹»uje se a¾ po naètení celé vìty.
###############################################################################



#------------------------------------------------------------------------------
# Projde strom a zjistí ke ka¾dému slovu morfologickou znaèku reprezentující
# jeho podstrom. Tato zdola zdìdìná znaèka se nemusí shodovat se znaèkou koøene
# podstromu. Napø. koøeny koordinací jsou obvykle souøadící spojky, tedy slova
# se znaèkou J^, ale celá koordinace dostane znaèku podle svých èlenù, tedy
# napø. koordinace podstatných jmen v 1. pádì dostane znaèku N1.
# Funkce ète globální pole @struktura, @afun a @anot. Plní globální hash
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
        # Koordinace a apozice dìdí znaèky svých èlenù (nikoli v¹ech svých
        # dìtí). Vnoøené koordinace a apozice se procházejí opakovanì (jednou
        # kvùli své morfologické znaèce a jednou nebo víckrát kvùli znaèkám
        # svých nadøízených), ale rezignuju na efektivitu výpoètu ve prospìch
        # efektivity programování: hlavnì kdy¾ to bude jednoduché a snadno
        # roz¹iøitelné.
        #   if($afun[$i]=~m/^(Coord|Apos)/)
        if($afun[$i]=~m/^Coord/)
        {
            my @clenove = zjistit_skutecne_cleny_koordinace($i);
            for(my $j = 0; $j<=$#clenove; $j++)
            {
                # A¾ se bude dìdit i jinde ne¾ u koordinací a apozic, bude asi
                # potøeba tady brát zdìdìnou znaèku místo pùvodní, to se pak
                # ale bude taky muset o¹etøit, které dìdìní probìhne døív.
                $anot[$i]{mznpodstrom} .= "|".$anot[$clenove[$j]]{uznacka};
                $anot[$clenove[$j]]{coordmember} = 1;
            }
            # Odstranit svislítko pøed první znaèkou.
            $anot[$i]{mznpodstrom} =~ s/^\|//;
        }
        else
        {
            $anot[$i]{mznpodstrom} = $anot[$i]{uznacka};
        }
    }
}



#------------------------------------------------------------------------------
# Vrátí seznam indexù èlenù koordinace, nebo apozice. Jako parametr po¾aduje
# index koøene dotyèné koordinace nebo apozice. Podstrom projde rekurzivnì,
# tak¾e u vnoøených koordinací nebo apozic vrátí seznam jejich èlenù, nikoli
# index jejich koøene (vhodné pro posuzování morfologických znaèek èlenù).
# Ví i o tom, ¾e u pøedlo¾ek a podøadících spojek není informace o jejich
# èlenství v koordinacích nebo apozicích ulo¾ena a ¾e je pøesunuta do syntak-
# tické znaèky jejich dítìte. Pokud v¹ak jejich dítì skuteènì vykazuje pøíslu¹-
# nost ke koordinaci nebo apozici, funkce nevrátí index tohoto dítìte, ale
# index pøedlo¾ky èi podøadící spojky, která ho øídí.
#------------------------------------------------------------------------------
sub zjistit_skutecne_cleny_koordinace
{
    my $koren = $_[0];
    my $i;
    my @clenove;
    # Projít v¹echny uzly stromu, hledat dìti koøene.
    for($i = 1; $i<=$#slova; $i++)
    {
        # Èleny koordinace mohou být nìkteré dìti koøene.
        if($struktura[$i]==$koren)
        {
            # Èlen koordinace se pozná podle syntaktické znaèky konèící na _Co.
            # Èlen apozice se pozná podle syntaktické znaèky konèící na _Ap.
            if($afun[$i] =~ m/_(Co|Ap)$/)
            {
                # Pokud je èlenem vnoøená koordinace nebo apozice, zajímají nás
                # její èleny, ne její koøen.
                if($afun[$i] =~ m/^(Coord|Apos)/)
                {
                    splice(@clenove, $#clenove+1, 0,
                    zjistit_skutecne_cleny_koordinace($i));
                }
                # Jinak pøidat do seznamu pøímo dotyèné dítì.
                else
                {
                    $clenove[++$#clenove] = $i;
                }
            }
            # Pøedlo¾ky a podøadící spojky mohou být èleny koordinace nebo apo-
            # zice, ale nikdy nepøibírají pøíponu _Co nebo _Ap. Tu místo toho
            # dostane jejich (obvykle jediné) dítì. Vyu¾ijeme znalosti vnitø-
            # ního provedení této funkce (zejména toho, ¾e nekontroluje, ¾e
            # koøen koordinace nebo apozice má s-znaèku Coord, resp. Apos) a
            # necháme rekurzivnì vyhledat v¹echny èleny "koordinace øízené
            # pøedlo¾kou (podøadící spojkou)".
            elsif($afun[$i] =~ m/Aux[PC]/)
            {
                # Zjistit, zda alespoò jedno dítì pøedlo¾ky má s-znaèku konèící
                # na _Co nebo _Ap.
                my @clenove_pod_predl = zjistit_skutecne_cleny_koordinace($i);
                # Pokud se takové dítì najde, je to dùkaz, ¾e tato vìtev je
                # èlenem koordinace a ne jejím rozvitím. Ale pro nás, na rozdíl
                # od anotátorù PDT, bude èlenem koøen této vìtve, tedy
                # pøedlo¾ka, ne její dítì!
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
# Naète seznam rámcù ze souboru do hashe. Klíèem hashe je sloveso, hodnota je
# pole rámcù, rámec je pole èlenù, èlen je morfologická znaèka upravená pro
# potøeby rámcù, pøípadnì obohacená o lemma. Jméno vstupního souboru a odkaz na
# cílový hash se pøedávají jako parametry.
#------------------------------------------------------------------------------
sub nacist_ramce
{
    my $jmeno_souboru = $_[0];
    my $hashref = $_[1];
    open(RAMCE, $jmeno_souboru)
    or die("Nelze otevøít soubor s rámci $jmeno_souboru.\n");
    while(<RAMCE>)
    {
        # Odstranit konec øádku.
        s/\r?\n$//;
        # Obvyklý tvar rámce je "sloveso  mzn/szn~~mzn/szn", popø.
        # "sloveso <INTR>".
        if(m/^(\S+)\s+<INTR>$/)
        {
            # Prázdný rámec nepøechodného slovesa.
            my @cleny;
            push(@{$hashref->{$1}}, [@cleny]);
            # Novì zøízený rámec bude prázdné pole, tak¾e jsme hotovi.
        }
        elsif(m/^(\S+)\s+(.*)$/)
        {
            # První èást je sloveso, druhá èást je rámec.
            my $sloveso = $1;
            my $ramec = $2;
            my @cleny = split(/~~/, $ramec);
            push(@{$hashref->{$sloveso}}, [@cleny]);
        }
    }
    close(RAMCE);
}



#------------------------------------------------------------------------------
# Porovná subkategorizaèní znaèku s morfologickou (redukovanou podle mého
# schématu). Subkategorizaèní znaèka vychází z morfologické znaèky, ale v nìk-
# terých pøípadech je upravena a nìkdy je obohacena o heslo.
#------------------------------------------------------------------------------
sub odpovida_skzn_mzn
{
    my $skzn = $_[0];
    my $mzn = $_[1];
    # Podstatná jména jsou v obou pøípadech stejná.
    if($skzn =~ m/^N\d$/ && $mzn eq $skzn)
    {
        return 1;
    }
    # Pøedlo¾ky u mzn vynechávají závorky a èíslo pádu.
    elsif($skzn =~ m/^R\d\((.*?)\)$/ && $mzn =~ m/^R$1$/)
    {
        return 1;
    }
    # Podøadící spojky u mzn vynechávají závorky.
    elsif($skzn =~ m/^J,\((.*?)\)$/ && $mzn =~ m/^J,$1$/)
    {
        return 1;
    }
    # Slovesa v infinitivu mají VINF místo Vf.
    elsif($skzn eq "VINF" && $mzn =~ m/^V(?:f|být)$/)
    {
        return 1;
    }
    # Zvratná zájmena mají v obou systémech zvlá¹tní znaèku, v ka¾dém jinou.
    # Zvratná zájmena v¹ak také mohou reprezentovat obyèejný pøedmìt.
    elsif($skzn =~ m/(PR|N)4/ && $mzn eq "Pse" ||
    $skzn eq m/(PR|N)3/ && $mzn eq "Psi")
    {
        return 1;
    }
    # Subkategorizaèní pozice N\d mù¾e být naplnìna i pøídavným jménem,
    # zájmenem nebo èíslovkou.
    elsif($skzn =~ m/N(\d)/ && $mzn =~ m/[NAPC]$1/)
    {
        return 1;
    }
    # U ostatních slovních druhù se znaèky neli¹í.
    elsif($skzn eq $mzn)
    {
        return 1;
    }
    return 0;
}



#------------------------------------------------------------------------------
# Projde strom a zjistí, jaké dìti má konkrétní sloveso (popø. jiné slovo).
# Potom projde seznam rámcù tohoto slovesa a vybere rámec, který nejlépe sedí.
# Rámce posuzuje podle kritérií v následujícím poøadí:
# 1. Poèet èlenù rámce, které ve stromì nejsou realizovány. Men¹í má pøednost.
# 2. Délka (celkový poèet èlenù) rámce. Del¹í má pøednost.
# Pokud zbyde více rámcù, mezi nimi¾ nelze pomocí vý¹e uvedených kritérií roz-
# hodnout, funkce vrátí v¹echny takové rámce. Index slovesa ve stromì se pøe-
# dává jako parametr. Struktura stromu (pole indexù rodièù) se pøedává odkazem,
# nemù¾eme pou¾ít globální promìnnou, proto¾e nevíme kterou (nevíme, jestli se
# má brát vzorová struktura (@struktura), nebo struktura vytváøená parserem
# (@rodic)). Dal¹í anotace vìty se v¹ak berou z globálních promìnných (@slova,
# @anot), tak pozor! S tabulkou rámcù je to jinak, ta se pøedává odkazem.
#------------------------------------------------------------------------------
sub najit_odpovidajici_ramec
{
    my $i_sloveso = $_[0];
    my $o_strom = $_[1];
    my $o_ramce = $_[2];
    # Zjistit seznam dìtí slovesa v na¹em stromì.
    my @deti;
    for(my $i = 0; $i<=$#{$o_strom}; $i++)
    {
        if($o_strom->[$i]==$i_sloveso)
        {
            $deti[++$#deti] = $i;
        }
    }
    # Projít rámce slovesa a porovnat je s jeho dìtmi.
    my $o_ramce_s = $o_ramce->{$anot[$i_sloveso]{heslo}};
    my @n_zbylo;
    my $min_zbylo;
    my $i_min_zbylo;
    #    print("Chystám se porovnávat rámce slovesa \"$anot[$i_sloveso]{heslo}\".\n");
    #    print("Toto sloveso má ".($#{$o_ramce_s}+1)." rámcù.\n");
    for(my $i = 0; $i<=$#{$o_ramce_s}; $i++)
    {
        # Porovnat i-tý rámec se skuteènými dìtmi slovesa ve stromì.
        # Zjistit, kolik èlenù rámce nemá realizaci mezi dìtmi.
        my @kopie_ramce = @{$o_ramce_s->[$i]};
        #   print(($i+1).". rámec má ".($#kopie_ramce+1)." èlenù.\n");
        # Projít èleny rámce a pro ka¾dý hledat realizaci mezi dìtmi.
        #   my $dbgj = 0;
        for(my $j = 0; $j<=$#kopie_ramce; $j++)
        {
            #       print((++$dbgj).". èlen ".($i+1).". rámce je $kopie_ramce[$j].\n");
            # Èlen se skládá z upravené m-znaèky a ze s-znaèky. Odstranit
            # s-znaèku, m-znaèku porovnat s m-znaèkou dítìte.
            $kopie_ramce[$j] =~ s-^(.*?)/.*$-$1-;
            # Projít dìti a hledat mezi nimi realizaci daného èlenu.
            for(my $k = 0; $k<=$#deti; $k++)
            {
                # Jestli¾e dané dítì je realizací daného èlenu, odstranit
                # èlen z kopie rámce a hledat dal¹í èlen.
                if(odpovida_skzn_mzn($kopie_ramce[$j], $anot[$deti[$k]]{znacka}))
                {
                    splice(@kopie_ramce, $j, 1);
                    $j--;
                    last;
                }
            }
        }
        # Èleny, které v kopii rámce zbyly, nena¹ly realizaci. Zapamatovat si
        # jejich poèet a zjistit, jestli je rekordnì malý.
        $n_zbylo[$i] = $#kopie_ramce+1;
        if($i==0 || $n_zbylo[$i]<$min_zbylo)
        {
            $min_zbylo = $n_zbylo[$i];
            $i_min_zbylo = $i;
        }
    }
    # Vrátit první rámec, kterému zbylo nejménì nerealizovaných èlenù.
    return @{$o_ramce_s->[$i_min_zbylo]};
}



#------------------------------------------------------------------------------
# Najde v¹echna mo¾ná sesazení dvou rámcù (párování jejich èlenù). Mo¾né je
# takové sesazení, ve kterém jsou spárovány pouze èleny se stejnou znaèkou.
# Nìkteré èleny v¹ak mohou zùstat nespárovány, pøesto¾e jejich potenciální
# protìj¹ek existuje.
#
# Vstupem jsou odkazy na dvì pole prvkù, typicky morfologických znaèek, ve
# stejné sadì! (Pokud rámec A pou¾íval jiné znaèky ne¾ rámec B, musí se pøevést
# je¹tì pøed pokusem o sesazení.) Pole nemusejí být stejnì dlouhá.
#
# Výstupem je odkaz na pole sesazení, které má následující strukturu:
#
# Stav èlenu rámce = "", pokud je¹tì nebyl spárován, jinak index jeho protìj¹ku
# ve druhém rámci. Stav rámce = pole stavù èlenù rámce. Stav sesazování =
# dvouèlenné pole [0..1] stavù rámcù. Nad tím v¹ím pole alternativních
# sesazení, resp. stavù sesazení: jsou dvì, jedno uchovává stavy po minulém
# kole, ve druhém se objevují alternativy prodlou¾ené (a rozvìtvené) právì o
# jeden pár nebo nespárovatelný èlen.
#------------------------------------------------------------------------------
sub sesadit_ramce
{
    my $o_a = $_[0];
    my $o_b = $_[1];
    my ($i, $j, $k, $l, $m);
    my @sesaz;
    # Existuje nejménì jedno sesazení, to obsahuje n osamìlých prvkù a ¾ádné
    # páry.
    $sesaz[0][0][0] = "";
    $sesaz[0][1][0] = "";
    # Projít prvky pole A.
    for($i = 0; $i<=$#{$o_a}; $i++)
    {
        # Projít prvky pole B, hledat obrazy i-tého prvku A.
        for($j = 0; $j<=$#{$o_b}; $j++)
        {
            # Zjistit, zda j-tý prvek B odpovídá i-tému prvku A.
            if($o_a->[$i] eq $o_b->[$j])
            {
                # Projít rozpracovaná sesazení a zjistit, do kterých jde
                # pøidat novì nalezený pár.
                for($k = 0; $k<=$#sesaz; $k++)
                {
                    # Zjistit, zda je v daném sesazení volné j-té B.
                    if($sesaz[$k][1][$j] eq "")
                    {
                        # Naklonovat toto sesazení. Ponechat variantu bez
                        # nového páru a pøidat variantu s novým párem.
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
# Rùzné
###############################################################################



#------------------------------------------------------------------------------
# Zjistí doplòkové parametry závislosti.
# Ète globální promìnné @slova a $sloveso.
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
        # U koøene nás nezajímá smìr, ale zajímá nás existence slovesa.
        $smer = $sloveso ? "V" : "N";
    }
    else
    {
        # Zjistit smìr závislosti (doprava nebo doleva).
        $smer = $r<$z ? "P" : "L";
    }
    # Zjistit délku závislosti (daleko nebo blízko (v sousedství)).
    $delka = abs($r-$z)>1 ? "D" : "B";
    # Roz¹íøit délku o informaci, zda se mezi $r a $z nachází èárka.
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
