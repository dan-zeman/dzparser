# Funkce pro načítání lingvisticky anotovaných textů ve formátu CSTS.
# - načte podstatné informace o slovu z jednoho řádku CSTS (funkce zpracovat_slovo())
#   - už při načítání některá data zpracuje, např. připraví upravenou morfologickou značku
# - umí projít celou množinu souborů na disku (pomocí glob masky; funkce projit_data()),
#   postupně je otvírat, načítat slova a po zkompletování každé věty zavolat funkci
#   zpracovat_vetu(), kterou však tento modul nedefinuje - musí si ji definovat ten,
#   kdo modul využívá, a to v prostoru main::. Funkce dostane od modulu csts tři
#   parametry:
#   - odkaz na hash s informacemi o aktuálním dokumentu, odstavci a větě;
#   - odkaz na pole slov věty a
#   - odkaz na pole hashů s anotacemi slov.
package csts;
use utf8;



###############################################################################
# Anotace slova
###############################################################################



#------------------------------------------------------------------------------
# Zpracuje proměnnou $_ jako řádek CSTS, obsahující informace o právě jednom
# slově. Vrátí hash s informacemi o slově, určený k zařazení do pole @anot.
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
    # Odstranit znak konce řádku, není součástí anotace.
    s/\r?\n$//;
    #==========================================================================
    # Index slova ve větě (CSTS značka <r>; nemusí nutně odpovídat skutečnému
    # pořadí slova ve větě a na tektogramatické rovině ani nemusí být celočí-
    # selný).
    #==========================================================================
    if(m/<r>(\d+)/)
    {
        $anot{ord} = $1;
    }
    #==========================================================================
    # Mezera před slovem (CSTS značka <D>).
    #==========================================================================
    $anot{mezera} = !$bezmezery;
    #==========================================================================
    # Přečíst slovní tvar.
    #==========================================================================
    if(m/<[fd]( [^>]*)?>([^<]*)/)
    {
        # Parser pracuje se slovním tvarem převedeným na malá písmena, ale musíme
        # si uložit i původní tvar, abychom ho mohli na výstup poslat nezprzněný.
        $anot{form} = $2;
        # Dekódovat entity (počítáme jen se třemi nejzákladnějšími, bez kterých se neobejdeme).
        $anot{form} =~ s/&lt;/</g;
        $anot{form} =~ s/&gt;/>/g;
        $anot{form} =~ s/&amp;/&/g;
        $anot{slovo} = lc($anot{form});
    }
    else
    {
        $anot{form} = $anot{slovo} = "";
    }
    #==========================================================================
    # Přečíst heslový tvar.
    #==========================================================================
    if(m/<$konfig->{mzdroj0}l[^>]*>([^<]*)/)
    {
        # Kvůli výstupu si zapamatovat i původní lemma, ze kterého nebyla
        # odtržena část za podtržítkem a ke kterému nebylo přidáno "K", pokud
        # jde o koncovou interpunkci.
        $anot{lemma} = $1;
        # Dekódovat entity (počítáme jen se třemi nejzákladnějšími, bez kterých se neobejdeme).
        $anot{lemma} =~ s/&lt;/</g;
        $anot{lemma} =~ s/&gt;/>/g;
        $anot{lemma} =~ s/&amp;/&/g;
        #     heslo ... heslo ze zvoleneho zdroje (<MMl>, <MDl>, <l>)
        #     lexkat ... poznamka za podtrzitkem, ze stejneho zdroje jako heslo
        $anot{heslo} = $anot{lemma};
        $anot{heslo} =~ s/_(.*)$//;
        $anot{lexkat} = $1;
    }
    else
    {
        $anot{heslo} = "";
        $anot{lexkat} = "";
    }
    #==========================================================================
    # Přečíst morfologickou značku.
    #==========================================================================
    #  znacka - morfologicka, neupravovana!
    #     znacka ... morfologicka znacka ze zvoleneho zdroje (<MMt>, <MDt>, <t>)
    #     mozne_znacky ... znacky ze slovniku <MMt>
    #     znacka_clovek ... znacka prirazena clovekem <t>
    #     znacka_mdta ... znacka podle taggeru a <MDt src="a">
    #     znacka_mdtb ... znacka podle taggeru b <MDt src="b">
    #     uznacka ... ze zvoleneho zdroje, ale upravena (jsou-li upravy povolene)
    #     zdznacka ... zdedena znacka (koren koordinace dedi od clenu)
    # Přečíst seznam možných značek ze slovníku.
    $anot{mozne_znacky} = "";
    my $schranka = $_;
    # Pozor, ne všechny korpusy mají přesně 15znakové značky!
#    while($schranka =~ s/<MMt[^>]*>(...............)//)
    while($schranka =~ s/<MMt[^>]*>([^<]*)//)
    {
        $anot{mozne_znacky} .= "|$1";
    }
    $anot{mozne_znacky} =~ s/^\|//;
    # Přečíst značky přiřazené člověkem a oběma taggery.
    # Pozor, ne všechny korpusy mají přesně 15znakové značky!
#    if($schranka =~ m/<t>(...............)/)
    if($schranka =~ m/<t>([^<]*)/)
    {
        $anot{znacka_clovek} = $1;
    }
    # Pozor, ne všechny korpusy mají přesně 15znakové značky!
#    if($schranka =~ m/<MDt.*?src="a".*?>(...............)/)
    if($schranka =~ m/<MDt.*?src="a".*?>([^<]*)/)
    {
        $anot{znacka_mdta} = $1;
    }
    # Pozor, ne všechny korpusy mají přesně 15znakové značky!
#    if($schranka =~ m/<MDt.*?src="b".*?>(...............)/)
    if($schranka =~ m/<MDt.*?src="b".*?>([^<]*)/)
    {
        $anot{znacka_mdtb} = $1;
    }
    # Vybrat značku ze zdroje požadovaného v konfiguraci.
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
    # Upravit morfologickou značku.
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
    # Odstranit případné duplikáty (kvůli tomu jsme značky třídili).
    while($anot{uznacka} =~ s/(..)\|\1/$1/g) {}
    #==========================================================================
    # Zjistit syntaktickou strukturu a syntaktickou značku.
    #==========================================================================
    if(m/<g>(\d+)/)
    {
        $anot{rodic_vzor} = $1;
    }
    if(m/<A>([^<]+)/)
    {
        $anot{afun} = $1;
        if($anot{afun} =~ m/$konfig->{vynech}/)
        {
            $vynechat_vetu = 1;
        }
    }
    # Další syntaktické anotace uložit do obecného pole hashů.
    $schranka = $_;
    while($schranka =~ s/<MDg src="([^"]*?)">(\d+)//)
    {
        $anot{"mdg".$1} = $2;
    }
    return \%anot;
}



#------------------------------------------------------------------------------
# Přečte ze vstupního řádku anotaci jednoho druhu. Vždy vrátí pole, i kdyby
# neexistovaly alternativní anotace téhož druhu.
#------------------------------------------------------------------------------
sub zjistit_anotaci
{
    # Vstupní řádek týkající se jednoho slova.
    my $radek = $_[0];
    # Identifikace. Např. "<MDt w="0.5" src="a">" se chytne na "MDt src=a".
    # Identifikace nemusí fungovat dobře, obsahuje-li více než jeden atribut.
    my $ident = $_[1];
    # Připravit regulární výraz, podle kterého anotaci poznáme.
    # Tato funkce se bude volat velmi často, proto cachovat již známé regulární
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
        # Dovolit další atributy a mezery.
        $regex =~ s/\s+/(?: [^>]*)? /g;
        # Obalit celé skobičkami, přidat past na vlastní anotaci.
        $regex = "<$regex>([^<\r\n]*)";
        # Uložit vytvořený regulární výraz do cache.
        $anot_regex{$ident} = $regex;
    }
    # Pochytat všechny výskyty anotace.
    my @hodnoty;
    my $i = 0;
    while($radek =~ s/$regex//)
    {
        $hodnoty[$i++] = $1;
    }
    return @hodnoty;
}



#------------------------------------------------------------------------------
# Upraví morfologickou značku. Volá se při čtení značky, tedy z funkce
# zpracovat_slovo(). Zapisuje do globální proměnné $sloveso. Kontrolu výskytu
# slovesa je dobré dělat tady, protože jedno slovo může mít více značek a jen
# některé z nich mohou být slovesné.
#------------------------------------------------------------------------------
sub upravit_mznacku()
{
    my $znacka = shift; # původní poziční značka z PDT (15 znaků)
    my $lznacka = shift; # stylistické a významové kategorie (z Hajičova lemmatu za podtržítkem)
    my $heslo = shift; # část lemmatu před podtržítkem (ale včetně př. pomlčky a čísla)
    my $slovo = shift; # slovní tvar
    my $konfig = shift; # odkaz na hash s konfigurací
    # Použít baltimorskou redukci značek, je-li to požadováno.
    if($konfig->{upravovat_mzn}==1)
    {
        return upravit_mznacku_baltimore($znacka);
    }
    #==========================================================================
    # Kontrola výskytu slovesa (kvůli závislostem na kořeni).
    if($znacka =~ m/^V/)
    {
        $sloveso = 1;
    }
    #==========================================================================
    # Řadovou číslovku považovat za přídavné jméno.
    $znacka =~ s/^Cr/AA/;
    # Zkrátit značku na dva znaky (slovní druh a pád nebo poddruh).
    $znacka =~ m/^(.)(.)..(.)/;
    $znacka = $3=="-" ? $1.$2 : $1.$3;
    $znacka .= $osoba;
    # Machinace se značkami.
    if($znacka=~m/^N/ && $lznacka=~m/Y/)
    {
        $znacka =~ s/^N/NY/;
    }
    # Lexikalizace značek pro interpunkci.
    elsif($znacka eq "Z:")
    {
        $znacka = "Z".$slovo;
    }
    # Selektivní lexikalizace značek.
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
            # Je potřeba rozlišit, kdy má být nahoře a kdy dole.
            # Pochopitelně je to opatření funkční jen v češtině, ale jinde by nemělo škodit.
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
            # Seznam příslovcí, která se vyskytla 100 a vícekrát.
            my @casta_prislovce =
            ("tak", "jak", "už", "také", "již", "ještě", "včera", "tedy",
            "pak", "více", "dnes", "pouze", "kde", "kdy", "například",
            "totiž", "především", "velmi", "zatím", "nyní", "právě", "stále",
            "zejména", "zcela", "dosud", "stejně", "téměř", "letos", "dále",
            "sice", "tu", "dokonce", "navíc", "zde", "rovněž", "zřejmě",
            "přitom", "např", "vůbec", "tam", "často", "příliš", "naopak",
            "zároveň", "vždy", "méně", "třeba", "opět", "loni", "spíše",
            "snad", "dobře", "proč", "zhruba", "později", "vlastně", "možná",
            "samozřejmě", "skutečně", "znovu", "tehdy", "přesto", "nakonec",
            "spolu", "poté", "jinak", "proto", "dříve", "přímo", "víc",
            "teď", "nikdy", "teprve", "většinou", "přece", "jistě",
            "podobně", "někdy", "hlavně", "alespoň", "dost", "zase",
            "údajně", "současně", "postupně", "celkem", "prakticky", "co",
            "hned", "dlouho", "nejvíce", "hodně", "ročně", "nadále",
            "rychle", "potom", "nejméně", "trochu", "mnohem", "tady",
            "poměrně", "velice", "nedávno", "výrazně", "takto", "nikoli",
            "krátce", "poněkud", "lépe", "přesně", "opravdu", "přibližně",
            "těžko", "pravděpodobně", "podstatně", "moc", "doma", "konečně",
            "daleko", "zvláště", "prostě", "společně", "původně", "mj",
            "apod", "nově", "spíš", "případně", "předem", "naprosto", "dál",
            "úplně", "rozhodně", "večer", "okamžitě", "denně", "nikoliv",
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
        elsif($konfig->{selex_podradici_spojky} && $znacka=~m/^J/ && $slovo=~m/(že|aby|zda)/)
        {
            $znacka = "J".$slovo;
            $znacka =~ s/zdali/zda/;
        }
    }
    return $znacka;
}



#------------------------------------------------------------------------------
# Upraví morfologickou značku přibližně tak, jak jsem to dělal v Baltimoru.
# Tenkrát jsem na to měl funkci, která manipulovala s jednotlivými mluvnickými
# kategoriemi. Dnes mám pouze seznam neredukovaných značek a jejich redukova-
# ných protějšků. Chybí v něm však manipulace se značkami interpunkce, které
# byly naopak už tehdy selektivně lexikalizovány, a také některé změny, které
# vedly na neexistující značku, takže program, kterým jsem si později vyráběl
# konverzní slovníček, už si s nimi neuměl poradit.
#------------------------------------------------------------------------------
sub upravit_mznacku_baltimore()
{
    my $znacka = shift; # původní poziční značka z PDT (15 znaků)
    # Jestliže dosud nebyl načten převodní slovníček, načíst ho.
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
# Projde trénovací nebo testovací data a na každou větu zavolá funkci
# zpracovat_vetu(). Tato funkce je callback, tj. musí být definována u toho,
# kdo požádal o projití dat.
# Parametrem je cesta k souborům s daty. Může obsahovat zástupné znaky.
# Zatím se používá globální pole @soubory, protože zpracovat_vetu() v train.pl
# chce seznam souborů znát. Mělo by se to ale rozdělit. Globální $isoubor.
#------------------------------------------------------------------------------
sub projit_data
{
    my $maska = shift; # cesta ke vstupním souborům, s maskou (např. *.csts)
    my $konfig = shift; # odkaz na hash s konfigurací
    my $zpracovat_vetu = shift; # odkaz na funkci pro zpracování věty
    if($zpracovat_vetu eq "")
    {
        $zpracovat_vetu = \&main::zpracovat_vetu;
    }
    my @soubory = glob($maska);
    # Vygenerovat událost "začátek čtení sady souborů".
    if(exists($konfig->{hook_zacatek_cteni}))
    {
        &{$konfig->{hook_zacatek_cteni}}($maska, \@soubory);
    }
    my %stav; # různé informace o tom, kde v datech se nacházíme
    my @anot; # pole hashů s anotacemi pro každé slovo aktuální věty
    vymazat_vetu(\%stav, \@anot);
    for(my $isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
        # Neplést se $stav{doksoubor}, ten uchovává jméno souboru, ve kterém začal aktuální dokument.
        $stav{soubor} = $soubory[$isoubor];
        # Odstranit z názvu souboru cestu a příponu.
        $stav{soubor} =~ s/^.*[\/\\]//;
        $stav{soubor} =~ s/\.csts$//;
        $stav{novy_soubor} = 1; # Vynuluje se po první větě souboru.
        # Aktualizovat číslo aktuální věty v rámci aktuálního souboru.
        $stav{cvvrs} = 1;
        if($soubory[$isoubor] eq "-")
        {
            *SOUBOR = *STDIN;
        }
        else
        {
            open(SOUBOR, $soubory[$isoubor]);
        }
        # Nastavit kódování vstupu. Raději nenastavovat žádné výchozí
        # kódování, když konfigurační soubor mlčí, protože jediný
        # kandidát by bylo UTF-8, ale vstup nemusí být dobře utvořené
        # UTF-8.
        if($konfig->{kodovani_data} ne "")
        {
            binmode(SOUBOR, ":encoding($konfig->{kodovani_data})");
        }
        while(<SOUBOR>)
        {
            # Zapamatovat si začátek dokumentu.
            # <doc file="s/inf/j/1994/cmpr9406" id="001">
            if(m/<doc\s+file=\"(.*?)\"\s+id=\"(.*?)\">/)
            {
                my $novy_identifikator_dokumentu = "$1/$2";
                skoncila_veta(\%stav, \@anot, $zpracovat_vetu);
                if($novy_identifikator_dokumentu ne $stav{dokid})
                {
                    $stav{predel} = "D";
                    $stav{pred_dokid} = $stav{dokid};
                    $stav{dokid} = $novy_identifikator_dokumentu;
                    $stav{pred_doksoubor} = $stav{doksoubor};
                    $stav{doksoubor} = $soubory[$isoubor];
                }
            }
            # Zapamatovat si začátek odstavce.
            # <p n=1>
            elsif(m/<p\s+n=(\d+)>/)
            {
                my $nove_cislo_odstavce = $1;
                skoncila_veta(\%stav, \@anot, $zpracovat_vetu);
                # Ze značky začátku dokumentu automaticky vyplývá i začátek odstavce.
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
            elsif(m/^<s(?: id=(?:"(.*?)"|([^\s>]*)))?>/)
            {
                $stav{vetid} = "$1$2";
                skoncila_veta(\%stav, \@anot, $zpracovat_vetu);
            }
            elsif(m/<D>/)
            {
                # Globální proměnná!
                $bezmezery = 1;
            }
            elsif(m/^<[fd][ >]/)
            {
                push(@anot, zpracovat_slovo($konfig));
                # Globální proměnná!
                $bezmezery = 0;
            }
        }
        unless($soubory[$isoubor] eq "-")
        {
            close(SOUBOR);
        }
    }
    # Nastavit příznak poslední věty, aby funkce zpracovat_vetu() provedla
    # naposledy i všechny akce, které dělá vždy jednou za čas.
    $stav{posledni_veta} = 1;
    skoncila_veta(\%stav, \@anot, $zpracovat_vetu);
}



#------------------------------------------------------------------------------
# Uzlový bod, volá se vždy, když musí skončit věta, pokud tedy nějaká vůbec
# začala. Volá se na začátku dokumentu, odstavce a věty a na konci dat.
#------------------------------------------------------------------------------
sub skoncila_veta
{
    my $stav = shift; # různé informace o tom, kde v datech se nacházíme
    my $anot = shift; # odkaz na pole hashů s informacemi o slovech věty (0 je kořen)
    my $zpracovat_vetu = shift; # odkaz na funkci pro zpracování věty
    if($zpracovat_vetu eq "")
    {
        $zpracovat_vetu = \&main::zpracovat_vetu;
    }
    # Může se stát, že uzly nebyly na vstupu seřazené podle ordu (<r>).
    # Zpracovatelské funkci to nedělá dobře, proto je teď raději seřadíme.
    @{$anot} = sort{$a->{ord}<=>$b->{ord}}(@{$anot});
    # Může se stát, že graf závislostí na vstupu není strom, protože obsahuje
    # cyklus. Zpracovatelská funkce by se kvůli tomu mohla zacyklit, proto
    # raději cykly kontrolujeme a odstraňujeme. Pro každý uzel zjistit, jestli
    # se z něj dá dojít do něj samého. Pokud ano, převěsit ho na kořen.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Nestačí hlídat, že se nevrátíme do $i. Někde výše může být cyklus, který
        # teprve čeká na opravu (protože leží napravo od nás), v něm bychom se
        # mohli chytit a kontrola by nikdy neskončila. Musíme vyvolat poplach,
        # jakmile narazíme na uzel, ve kterém už jsme byli, i když to není $i.
        my @stopy;
        for(my $j = $i; $j!=0; $j = $anot->[$j]{rodic_vzor})
        {
            $stopy[$j] = 1;
            if($stopy[$anot->[$j]{rodic_vzor}])
            {
                $anot->[$j]{rodic_vzor} = 0;
            }
        }
    }
    # Zpracovat větu.
    if($#{$anot}>0 || $stav->{posledni_veta})
    {
        # Upravit značku koncové interpunkce (to nemůžeme udělat, dokud
        # nevíme, že dotyčné slovo je poslední).
        if($anot->[$#{$anot}]{uznacka}=~m/^Z/)
        {
            $anot->[$#{$anot}]{slovo} .= "K";
            $anot->[$#{$anot}]{heslo} .= "K";
            $anot->[$#{$anot}]{uznacka} .= "K";
        }
        # Zdědit morfologické značky u koordinací a apozic.
        zjistit_znacky_podstromu($anot);
        # Provést vlastní zpracování definované aplikací.
        if($vynechat_vetu)
        {
            if($stav->{posledni_veta})
            {
                # Nesmí dojít ke skutečnému zpracování, jen ukončovací operace: tj. nepředat $anot.
                # Bohužel se pak dějí divné věci, takže zatím raději předat $anot a zpracovat navíc
                # jednu větu, která se zpracovat nemá.
                &{$zpracovat_vetu}($stav);
            }
        }
        else
        {
            &{$zpracovat_vetu}($stav, $anot);
        }
        # Připravit se na čtení další věty.
        vymazat_vetu($stav, $anot);
        return 1;
    }
    else
    {
        return 0;
    }
}



###############################################################################
# Dědění morfologických značek u koordinací a apozic.
# Vztahuje se ke slovům, ale zjišťuje se až po načtení celé věty.
###############################################################################



#------------------------------------------------------------------------------
# Projde strom a zjistí ke každému slovu morfologickou značku reprezentující
# jeho podstrom. Tato zdola zděděná značka se nemusí shodovat se značkou kořene
# podstromu. Např. kořeny koordinací jsou obvykle souřadící spojky, tedy slova
# se značkou J^, ale celá koordinace dostane značku podle svých členů, tedy
# např. koordinace podstatných jmen v 1. pádě dostane značku N1.
# Funkce čte globální pole @anot. Plní globální hash @anot[$i]{mznpodstrom} a
# @anot[$i]{coordmember}.
#------------------------------------------------------------------------------
sub zjistit_znacky_podstromu
{
    my $anot = shift; # odkaz na pole hashů
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        $anot->[$i]{coordmember} = 0;
    }
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Koordinace a apozice dědí značky svých členů (nikoli všech svých
        # dětí). Vnořené koordinace a apozice se procházejí opakovaně (jednou
        # kvůli své morfologické značce a jednou nebo víckrát kvůli značkám
        # svých nadřízených), ale rezignuju na efektivitu výpočtu ve prospěch
        # efektivity programování: hlavně když to bude jednoduché a snadno
        # rozšiřitelné.
#        if($anot->[$i]{afun}=~m/^(Coord|Apos)/)
        if($anot->[$i]{afun}=~m/^Coord/)
        {
            my @clenove = zjistit_skutecne_cleny_koordinace($anot, $i);
            for(my $j = 0; $j<=$#clenove; $j++)
            {
                # Až se bude dědit i jinde než u koordinací a apozic, bude asi
                # potřeba tady brát zděděnou značku místo původní, to se pak
                # ale bude taky muset ošetřit, které dědění proběhne dřív.
                $anot->[$i]{mznpodstrom} .= "|".$anot->[$clenove[$j]]{uznacka};
                $anot->[$clenove[$j]]{coordmember} = 1;
            }
            # Odstranit svislítko před první značkou.
            $anot->[$i]{mznpodstrom} =~ s/^\|//;
        }
        else
        {
            $anot->[$i]{mznpodstrom} = $anot->[$i]{uznacka};
        }
    }
}



#------------------------------------------------------------------------------
# Vrátí seznam indexů členů koordinace, nebo apozice. Jako parametr požaduje
# index kořene dotyčné koordinace nebo apozice. Podstrom projde rekurzivně,
# takže u vnořených koordinací nebo apozic vrátí seznam jejich členů, nikoli
# index jejich kořene (vhodné pro posuzování morfologických značek členů).
# Ví i o tom, že u předložek a podřadících spojek není informace o jejich
# členství v koordinacích nebo apozicích uložena a že je přesunuta do syntak-
# tické značky jejich dítěte. Pokud však jejich dítě skutečně vykazuje přísluš-
# nost ke koordinaci nebo apozici, funkce nevrátí index tohoto dítěte, ale
# index předložky či podřadící spojky, která ho řídí.
#------------------------------------------------------------------------------
sub zjistit_skutecne_cleny_koordinace
{
    my $anot = shift; # odkaz na pole hashů
    my $koren = shift; # index kořene koordinace
    my @clenove;
    # Projít všechny uzly stromu, hledat děti kořene.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Členy koordinace mohou být některé děti kořene.
        if($anot->[$i]{rodic_vzor}==$koren)
        {
            # Člen koordinace se pozná podle syntaktické značky končící na _Co.
            # Člen apozice se pozná podle syntaktické značky končící na _Ap.
            if($anot->[$i]{afun} =~ m/_(Co|Ap)$/)
            {
                # Pokud je členem vnořená koordinace nebo apozice, zajímají nás
                # její členy, ne její kořen.
                if($anot->[$i]{afun} =~ m/^(Coord|Apos)/)
                {
                    splice(@clenove, $#clenove+1, 0,
                    zjistit_skutecne_cleny_koordinace($anot, $i));
                }
                # Jinak přidat do seznamu přímo dotyčné dítě.
                else
                {
                    $clenove[++$#clenove] = $i;
                }
            }
            # Předložky a podřadící spojky mohou být členy koordinace nebo apo-
            # zice, ale nikdy nepřibírají příponu _Co nebo _Ap. Tu místo toho
            # dostane jejich (obvykle jediné) dítě. Využijeme znalosti vnitř-
            # ního provedení této funkce (zejména toho, že nekontroluje, že
            # kořen koordinace nebo apozice má s-značku Coord, resp. Apos) a
            # necháme rekurzivně vyhledat všechny členy "koordinace řízené
            # předložkou (podřadící spojkou)".
            elsif($anot->[$i]{afun} =~ m/Aux[PC]/)
            {
                # Zjistit, zda alespoň jedno dítě předložky má s-značku končící
                # na _Co nebo _Ap.
                my @clenove_pod_predl = zjistit_skutecne_cleny_koordinace($anot, $i);
                # Pokud se takové dítě najde, je to důkaz, že tato větev je
                # členem koordinace a ne jejím rozvitím. Ale pro nás, na rozdíl
                # od anotátorů PDT, bude členem kořen této větve, tedy
                # předložka, ne její dítě!
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
# Vymaže všechny globální proměnné popisující větu, které vznikly v proceduře
# zpracovat_slovo. Typicky se volá na začátku procedury zpracovat_vetu, aby
# bylo kam načítat další větu. Tato funkce také rovnou vyplní některé údaje o
# kořeni, protože ty jsou ve všech větách stejné, ale z dat se je nedozvíme.
#------------------------------------------------------------------------------
sub vymazat_vetu
{
    my $stav = shift; # různé informace o tom, kde v datech se nacházíme
    my $anot = shift; # odkaz na pole hashů s informacemi o slovech věty (0 je kořen)
    $stav->{predel} = "S"; # D pro dokument, P pro odstavec, S pro větu (default), K pro poslední větu
    # Jestliže to byla první věta souboru, o příští větě už se nesmí tvrdit totéž.
    $stav->{novy_soubor} = 0;
    # Zvýšit číslo aktuální věty v rámci aktuálního souboru.
    $stav->{cvvrs}++;
    splice(@{$anot});
    $anot->[0]{slovo} = "#";
    $anot->[0]{heslo} = "#";
    $anot->[0]{znacka} = "Z#-------------";
    $anot->[0]{uznacka} = "#";
    $anot->[0]{rodic_vzor} = -1;
    $anot->[0]{afun} = "AuxS";
    # Informace o větě.
    $sloveso = 0; # Zda věta obsahuje sloveso.
    $vynechat_vetu = 0;
}



#------------------------------------------------------------------------------
# Strom je v souboru reprezentován číselnými odkazy od závislého uzlu k řídící-
# mu. Takto lze ovšem zapsat i struktury, které nejsou stromy. Pokud se bojíme,
# že načítaná data mohou být nekorektní, tato funkce je zkontroluje.
#------------------------------------------------------------------------------
sub je_strom
{
    my $anot = shift;
    my $zdroj = shift; # pokud je více struktur, která se má kontrolovat?
    $zdroj = "rodic_vzor" if($zdroj eq "");
    # Zjistit, zda všechny odkazy vedou na existující uzel, zda všechny končí
    # v nule, a netvoří tudíž cykly ani nejde o nesouvislý les.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        # Kvůli cyklům si evidovat všechny uzly, kterými jsme prošli na cestě
        # ke kořeni. Do cyklu totiž můžeme vstoupit až u některého předka!
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
