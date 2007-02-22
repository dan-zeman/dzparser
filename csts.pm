# Funkce pro naèítání lingvisticky anotovaných textù ve formátu CSTS.
# - naète podstatné informace o slovu z jednoho øádku CSTS (funkce zpracovat_slovo())
#   - u¾ pøi naèítání nìkterá data zpracuje, napø. pøipraví upravenou morfologickou znaèku
# - umí projít celou mno¾inu souborù na disku (pomocí glob masky; funkce projit_data()),
#   postupnì je otvírat, naèítat slova a po zkompletování ka¾dé vìty zavolat funkci
#   zpracovat_vetu(), kterou v¹ak tento modul nedefinuje - musí si ji definovat ten,
#   kdo modul vyu¾ívá, a to v prostoru main::. Funkce dostane od modulu csts tøi
#   parametry:
#   - odkaz na hash s informacemi o aktuálním dokumentu, odstavci a vìtì;
#   - odkaz na pole slov vìty a
#   - odkaz na pole hashù s anotacemi slov.
package csts;



###############################################################################
# Anotace slova
###############################################################################



#------------------------------------------------------------------------------
# Zpracuje promìnnou $_ jako øádek CSTS, obsahující informace o právì jednom
# slovì. Vrátí hash s informacemi o slovì, urèený k zaøazení do pole @anot.
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
    my %anot; # výstupní hash
    #==========================================================================
    # Index slova ve vìtì (CSTS znaèka <r>; nemusí nutnì odpovídat skuteènému
    # poøadí slova ve vìtì a na tektogramatické rovinì ani nemusí být celoèí-
    # selný).
    #==========================================================================
    if(m/<r>(\d+)/)
    {
        $anot{ord} = $1;
    }
    #==========================================================================
    # Mezera pøed slovem (CSTS znaèka <D>).
    #==========================================================================
    $anot{mezera} = !$bezmezery;
    #==========================================================================
    # Pøeèíst slovní tvar.
    #==========================================================================
    m/<[fd]( [^>]*)?>([^<]+)/;
    $anot{slovo} = $2;
    $anot{slovo} =~ tr/AÁBCÈDÏEÉÌFGHIÍJKLMNÒOÓPQRØS©T«UÚÙVWXYÝZ®/aábcèdïeéìfghiíjklmnòoópqrøs¹t»uúùvwxyýz¾/;
    #==========================================================================
    # Pøeèíst heslový tvar.
    #==========================================================================
    m/<$konfig->{mzdroj0}l[^>]*>([^<]+)/;
    #     heslo ... heslo ze zvoleneho zdroje (<MMl>, <MDl>, <l>)
    #     lexkat ... poznamka za podtrzitkem, ze stejneho zdroje jako heslo
    $anot{heslo} = $1;
    $anot{heslo} =~ s/_(.*)$//;
    $anot{lexkat} = $1;
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
    $anot{mozne_znacky} = "";
    my $schranka = $_;
    while($schranka =~ s/<MMt[^>]*>(...............)//)
    {
        $anot{mozne_znacky} .= "|$1";
    }
    $anot{mozne_znacky} =~ s/^\|//;
    # Pøeèíst znaèky pøiøazené èlovìkem a obìma taggery.
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
    # Vybrat znaèku ze zdroje po¾adovaného v konfiguraci.
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
    # Upravit morfologickou znaèku.
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
    # Odstranit pøípadné duplikáty (kvùli tomu jsme znaèky tøídili).
    while($anot{uznacka} =~ s/([^\|]+)\|\1/$1/g) {}
    #==========================================================================
    # Zjistit syntaktickou strukturu a syntaktickou znaèku.
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
    # Dal¹í syntaktické anotace ulo¾it do obecného pole hashù.
    if(m/<MDg src="(.*?)">(\d+)/)
    {
        $anot{"mdg".$1} = $2;
    }
    return \%anot;
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
    my $znacka = shift; # pùvodní pozièní znaèka z PDT (15 znakù)
    my $lznacka = shift; # stylistické a významové kategorie (z Hajièova lemmatu za podtr¾ítkem)
    my $heslo = shift; # èást lemmatu pøed podtr¾ítkem (ale vèetnì pø. pomlèky a èísla)
    my $slovo = shift; # slovní tvar
    my $konfig = shift; # odkaz na hash s konfigurací
    # Pou¾ít baltimorskou redukci znaèek, je-li to po¾adováno.
    if($konfig->{upravovat_mzn}==1)
    {
        return upravit_mznacku_baltimore($znacka);
    }
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
    }
    # Selektivní lexikalizace znaèek.
    if($konfig->{selex})
    {
        # Zájmena
        if($konfig->{selex_zajmena} && $znacka=~m/^P/)
        {
            # Zvratná zájmena "se" a "si".
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
            # Pomocné sloveso být lexikalizovat tvarem, ne heslem.
            # Je potøeba rozli¹it, kdy má být nahoøe a kdy dole.
            # Pochopitelnì je to opatøení funkèní jen v èe¹tinì, ale jinde by nemìlo ¹kodit.
            if($konfig->{selex_byt} && $heslo eq "být")
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
        elsif($konfig->{selex_predlozky} && $znacka=~m/^R/)
        {
            $znacka = "R".$heslo;
        }
        elsif($konfig->{selex_podradici_spojky} && $znacka=~m/^J/ && $slovo=~m/(¾e|aby|zda)/)
        {
            $znacka = "J".$slovo;
            $znacka =~ s/zdali/zda/;
        }
    }
    return $znacka;
}



#------------------------------------------------------------------------------
# Upraví morfologickou znaèku pøibli¾nì tak, jak jsem to dìlal v Baltimoru.
# Tenkrát jsem na to mìl funkci, která manipulovala s jednotlivými mluvnickými
# kategoriemi. Dnes mám pouze seznam neredukovaných znaèek a jejich redukova-
# ných protìj¹kù. Chybí v nìm v¹ak manipulace se znaèkami interpunkce, které
# byly naopak u¾ tehdy selektivnì lexikalizovány, a také nìkteré zmìny, které
# vedly na neexistující znaèku, tak¾e program, kterým jsem si pozdìji vyrábìl
# konverzní slovníèek, u¾ si s nimi neumìl poradit.
#------------------------------------------------------------------------------
sub upravit_mznacku_baltimore()
{
    my $znacka = shift; # pùvodní pozièní znaèka z PDT (15 znakù)
    # Jestli¾e dosud nebyl naèten pøevodní slovníèek, naèíst ho.
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
# Procházení dat
###############################################################################



#------------------------------------------------------------------------------
# Projde trénovací nebo testovací data a na ka¾dou vìtu zavolá funkci
# zpracovat_vetu(). Tato funkce je callback, tj. musí být definována u toho,
# kdo po¾ádal o projití dat.
# Parametrem je cesta k souborùm s daty. Mù¾e obsahovat zástupné znaky.
# Zatím se pou¾ívá globální pole @soubory, proto¾e zpracovat_vetu() v train.pl
# chce seznam souborù znát. Mìlo by se to ale rozdìlit. Globální $isoubor.
#------------------------------------------------------------------------------
sub projit_data
{
    my $maska = shift; # cesta ke vstupním souborùm, s maskou (napø. *.csts)
    my $konfig = shift; # odkaz na hash s konfigurací
    @soubory = glob($maska);
    # Vygenerovat událost "zaèátek ètení sady souborù".
    if(exists($konfig->{hook_zacatek_cteni}))
    {
        &{$konfig->{hook_zacatek_cteni}}($maska, \@soubory);
    }
    my %stav; # rùzné informace o tom, kde v datech se nacházíme
    vymazat_vetu(\%stav, \@anot);
    for(my $isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
        # Neplést se $stav{doksoubor}, ten uchovává jméno souboru, ve kterém zaèal aktuální dokument.
        $stav{soubor} = $soubory[$isoubor];
        $stav{novy_soubor} = 1; # Vynuluje se po první vìtì souboru.
        open(SOUBOR, $soubory[$isoubor]) or die("Nelze otevrit soubor $soubory[$isoubor]: $!\n");
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
            elsif(m/^<s(?: id="(.*?)")?>/)
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
                push(@anot, zpracovat_slovo($konfig));
                # Globální promìnná!
                $bezmezery = 0;
            }
        }
        close(SOUBOR);
    }
    if($#anot>0)
    {
        # Nastavit pøíznak poslední vìty, aby funkce zpracovat_vetu() provedla
        # naposledy i v¹echny akce, které dìlá v¾dy jednou za èas.
        $stav{posledni_veta} = 1;
        skoncila_veta(\%stav, \@anot);
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
        if($anot->[$#{$anot}]{uznacka}=~m/^Z/)
        {
            $anot->[$#{$anot}]{slovo} .= "K";
            $anot->[$#{$anot}]{heslo} .= "K";
            $anot->[$#{$anot}]{uznacka} .= "K";
        }
        # Zdìdit morfologické znaèky u koordinací a apozic.
        zjistit_znacky_podstromu($anot);
        # Provést vlastní zpracování definované aplikací.
        main::zpracovat_vetu($stav, $anot);
        # Pøipravit se na ètení dal¹í vìty.
        vymazat_vetu($stav, $anot);
        return 1;
    }
    else
    {
        return 0;
    }
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
# Funkce ète globální pole @anot. Plní globální hash @anot[$i]{mznpodstrom} a
# @anot[$i]{coordmember}.
#------------------------------------------------------------------------------
sub zjistit_znacky_podstromu
{
    my $anot = shift; # odkaz na pole hashù
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        $anot->[$i]{coordmember} = 0;
    }
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Koordinace a apozice dìdí znaèky svých èlenù (nikoli v¹ech svých
        # dìtí). Vnoøené koordinace a apozice se procházejí opakovanì (jednou
        # kvùli své morfologické znaèce a jednou nebo víckrát kvùli znaèkám
        # svých nadøízených), ale rezignuju na efektivitu výpoètu ve prospìch
        # efektivity programování: hlavnì kdy¾ to bude jednoduché a snadno
        # roz¹iøitelné.
#        if($anot->[$i]{afun}=~m/^(Coord|Apos)/)
        if($anot->[$i]{afun}=~m/^Coord/)
        {
            my @clenove = zjistit_skutecne_cleny_koordinace($anot, $i);
            for(my $j = 0; $j<=$#clenove; $j++)
            {
                # A¾ se bude dìdit i jinde ne¾ u koordinací a apozic, bude asi
                # potøeba tady brát zdìdìnou znaèku místo pùvodní, to se pak
                # ale bude taky muset o¹etøit, které dìdìní probìhne døív.
                $anot->[$i]{mznpodstrom} .= "|".$anot->[$clenove[$j]]{uznacka};
                $anot->[$clenove[$j]]{coordmember} = 1;
            }
            # Odstranit svislítko pøed první znaèkou.
            $anot->[$i]{mznpodstrom} =~ s/^\|//;
        }
        else
        {
            $anot->[$i]{mznpodstrom} = $anot->[$i]{uznacka};
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
    my $anot = shift; # odkaz na pole hashù
    my $koren = shift; # index koøene koordinace
    my @clenove;
    # Projít v¹echny uzly stromu, hledat dìti koøene.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Èleny koordinace mohou být nìkteré dìti koøene.
        if($anot->[$i]{rodic_vzor}==$koren)
        {
            # Èlen koordinace se pozná podle syntaktické znaèky konèící na _Co.
            # Èlen apozice se pozná podle syntaktické znaèky konèící na _Ap.
            if($anot->[$i]{afun} =~ m/_(Co|Ap)$/)
            {
                # Pokud je èlenem vnoøená koordinace nebo apozice, zajímají nás
                # její èleny, ne její koøen.
                if($anot->[$i]{afun} =~ m/^(Coord|Apos)/)
                {
                    splice(@clenove, $#clenove+1, 0,
                    zjistit_skutecne_cleny_koordinace($anot, $i));
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
            elsif($anot->[$i]{afun} =~ m/Aux[PC]/)
            {
                # Zjistit, zda alespoò jedno dítì pøedlo¾ky má s-znaèku konèící
                # na _Co nebo _Ap.
                my @clenove_pod_predl = zjistit_skutecne_cleny_koordinace($anot, $i);
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
    # Jestli¾e to byla první vìta souboru, o pøí¹tí vìtì u¾ se nesmí tvrdit toté¾.
    $stav->{novy_soubor} = 0;
    splice(@{$anot});
    $anot->[0]{slovo} = "#";
    $anot->[0]{heslo} = "#";
    $anot->[0]{znacka} = "Z#-------------";
    $anot->[0]{uznacka} = "#";
    $anot->[0]{rodic_vzor} = -1;
    $anot->[0]{afun} = "AuxS";
    # Informace o vìtì.
    $sloveso = 0; # Zda vìta obsahuje sloveso.
    $vynechat_vetu = 0;
}



#------------------------------------------------------------------------------
# Strom je v souboru reprezentován èíselnými odkazy od závislého uzlu k øídící-
# mu. Takto lze ov¹em zapsat i struktury, které nejsou stromy. Pokud se bojíme,
# ¾e naèítaná data mohou být nekorektní, tato funkce je zkontroluje.
#------------------------------------------------------------------------------
sub je_strom
{
    my $anot = shift;
    my $zdroj = shift; # pokud je více struktur, která se má kontrolovat?
    $zdroj = "rodic_vzor" if($zdroj eq "");
    # Zjistit, zda v¹echny odkazy vedou na existující uzel, zda v¹echny konèí
    # v nule, a netvoøí tudí¾ cykly ani nejde o nesouvislý les.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Kvùli cyklùm si evidovat v¹echny uzly, kterými jsme pro¹li na cestì
        # ke koøeni. Do cyklu toti¾ mù¾eme vstoupit a¾ u nìkterého pøedka!
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
