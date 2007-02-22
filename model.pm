package model;
use povol;
use plodnost;



#------------------------------------------------------------------------------
# Zjistí doplòkové parametry závislosti.
#------------------------------------------------------------------------------
sub zjistit_smer_a_delku
{
    my $r = shift; # index øídícího uzlu závislosti
    my $z = shift; # index závislého uzlu závislosti
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Výstupní promìnné.
    my $smer;
    my $delka;
    if($r==0 && $konfig->{pod_korenem_sloveso_misto_smeru})
    {
        # U koøene nás nezajímá smìr, ale zajímá nás existence slovesa.
        my $sloveso = join("", map{substr($_->{znacka}, 0, 1)}(@{$anot})) =~ m/V/;
        $smer = $sloveso ? "V" : "N";
    }
    else
    {
        # Zjistit smìr závislosti (doprava nebo doleva).
        $smer = $r<$z ? "P" : "L";
    }
    # Zjistit délku závislosti (daleko nebo blízko (v sousedství)).
    if($konfig->{vzdalenost})
    {
        $delka = abs($r-$z)>1 ? "D" : "B";
        # Roz¹íøit délku o informaci, zda se mezi $r a $z nachází èárka.
        if($konfig->{vzdalenost}==3)
        {
            my($j0, $j1, $j);
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
                for(my $j = $j0; $j<=$j1; $j++)
                {
                    if($anot->[$j]{slovo} eq ",")
                    {
                        $delka = ",";
                        last;
                    }
                }
            }
        }
    }
    else
    {
        $delka = "X";
    }
    return $smer, $delka;
}



#------------------------------------------------------------------------------
# Zjistí pravdìpodobnost závislosti nebo koordinace pro informaci, nikoli pro
# rozhodování pøi budování stromu. Pravdìpodobnost tedy nebude zkreslena snahou
# pøinutit nìkteré vìci k døívìj¹ímu spojení. Díky tomu by mìla být vyu¾itelná
# pøi snaze ohodnotit celý strom.
#------------------------------------------------------------------------------
sub zjistit_nezkreslenou_pravdepodobnost
{
    my $r = shift; # index øídícího uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $z = shift; # index závislého uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $stav = shift; # potøebujeme ho ke zji¹tìní zdìdìných znaèek u koordinací
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    my($smer, $delka);
    my($hrana, $c, $p);
    ($smer, $delka) = zjistit_smer_a_delku($r, $z);
    my $prm = "$smer $delka";
    # Nyní poèítám pouze s modelem, který obvykle pou¾ívám.
    # Pokud nìkdo v konfiguraci zapne jiný model, ohlásit chybu!
    if($konfig->{"model"} eq "ls*slova+lz*znacky")
    {
        my $ls = $konfig->{ls};
        my $lz = 1-$ls;
        # Zjistit èetnosti v¹ech relevantních událostí v trénovacích datech.
        my $coss = ud("OSS $anot->[$r]{slovo} $anot->[$z]{slovo} $prm");
        # Pokusné volitelné roz¹íøení: má uzel sourozence stejného druhu?
        my $zarlivost = $konfig{zarlivost} ? (ma_sourozence_stejneho_druhu($anot, $stav->{rodic}, $r, $z) ? " N" : " Z") : "";
        my $cozz = ud("OZZ $rznacka $zznacka $prm$zarlivost");
        my $czpv = 0;
        if($konfig->{pseudoval})
        {
            if($rznacka=~m/^V/)
            {
                my $rrr = $rznacka.$anot->[$r]{heslo};
                $rrr =~ s/_.*//;
                $czpv = ud("ZPV $rrr $zznacka $prm");
            }
        }
        $cozz += $czpv;
        # Zkombinovat slovní a znaèkovou èetnost do jedné.
        $c = $ls*$coss+$lz*$cozz;
        # Na základì èetnosti odhadnout pravdìpodobnost.
        # Pøístup 1: místo pravdìpodobností porovnávat pøímo èetnosti.
        if($konfig->{abscetnost})
        {
            $p = $c;
        }
        # Pøístup 2: "relativní pravdìpodobnost", tj. relativní èetnost v rámci
        # pouze tìch událostí, které jsou pro daný závislý uzel relevantní.
        else
        {
            my $jmenovatel = ud("USS $anot->[$z]{slovo}");
            my $ps = $jmenovatel!=0 ? $coss/$jmenovatel : 0;
            my $pz = ($cozz+1)/(ud("UZZ $zznacka")+1);
            $p = $ls*$ps+$lz*$pz;
        }
    }
    else
    {
        die("V konfiguraci byl zapnut nepodporovaný model \"$konfig{model}\"!\n");
    }
    if($konfig->{nekoord})
    {
        # Zjistit, zda øídící èlen mù¾e být koordinaèní spojkou.
        my $ckoord = ud("KJJ $anot->[$r]{slovo}");
        my $prk;
        # Zjistit, v jakém procentu právì toto heslo øídí koordinaci.
        $prk = 0;
        my $cuss = ud("USS $anot->[$r]{slovo}");
        $prk = $ckoord/$cuss unless($cuss==0);
        # Pravdìpodobnost závislosti pak bude vynásobena (1-$prk), aby byla
        # srovnatelná s pravdìpodobnostmi koordinací.
        $p *= 1-$prk;
    }
    return($p, $c);
}



#------------------------------------------------------------------------------
# Zjistí pravdìpodobnost závislosti ve zvoleném modelu.
# Vrátí pravdìpodobnost hrany, èetnost hrany a popis hrany (pro ladící úèely).
# Proto¾e se pou¾ívá pro vlastní budování stromu, má dovoleno pravdìpodobnost
# rùznì zkreslovat, tak¾e to, co z nìj padá, vlastnì pravá pravdìpodobnost není.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost
{
    my $r = shift; # index øídícího uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $z = shift; # index závislého uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $stav = shift; # odkaz na hash se stavem analýzy; umo¾òuje podmínit pravdìpodobnost závislosti vlastnostmi jiných závislostí
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    # Témìø vylouèit závislost èehokoli na pøedlo¾ce, na které u¾ nìco visí.
    if($rznacka=~m/^R/ && $stav->{ndeti}[$r]>0)
    {
        return(0, 0, "$r $z NA PREDLOZCE UZ NECO VISI");
    }
    # Zvlá¹tní zacházení se vzta¾nými vedlej¹ími vìtami.
    if($konfig->{vztaz})
    {
        if(jde_o_vztaznou_vetu($r, $z, $stav))
        {
            return(1, 0, "$r $z VZTAZNA VETA");
        }
    }
    # Pokus: zakázat podstatným jménùm ve 2. pádì pøeskakovat sourozence pøi zavì¹ování doleva.
    if($konfig->{nepreskocg} && $zznacka eq "N2" && $z-$r>1)
    {
        # Projít uzly napravo od øídícího, poèínaje závislým zprava doleva.
        for(my $i = $z; $i>$r; $i--)
        {
            # Zjistit, na kterém konci dvojice uzel závisí (øídící, nebo
            # závislý?) Pokud závisí na závislém konci (vpravo), je to OK.
            # Pokud závisí na øídícím (vlevo), byl by pøeskoèen, a tomu zde
            # chceme bránit (závislý by mìl radìji záviset na nìm ne¾ na
            # øídícím). Pozor, na jednom z dvojice záviset musí, jinak by
            # øídící a závislý nebyli sousedé z hlediska projektivity a
            # dotyèná závislost by vùbec nemìla být povolena!
            my $j;
            for($j = $i; $j!=$r && $j!=$z && $j!=-1; $j = $stav->{rodic}[$j]) {}
            if($j==-1 && $r!=0)
            {
                # Závislost by nemìla být vùbec povolena, proto¾e mezi
                # øídícím a závislým le¾í uzel, který zatím není podøízen
                # ani jednomu z nich. Zde to nemù¾eme ohlásit jako chybu,
                # proto¾e se nìkdo mohl zeptat i na pravdìpodobnost
                # nepovolené závislosti, ale ka¾dopádnì vrátíme nulu.
                return(0, 0, "NEPOVOLENO KVULI PROJEKTIVITE, $i NENI PODRIZENO ANI $r, ANI $z");
            }
            if($j==$r)
            {
                return(0, 0, "$r $z BY PRESKOCILO $i");
            }
        }
    }
    # Zjistit skuteènou pravdìpodobnost, nezkreslenou snahami nìco spojit døíve a nìco pozdìji.
    my ($p, $c) = zjistit_nezkreslenou_pravdepodobnost($r, $z, $stav);
    return($p, $c);
}



#------------------------------------------------------------------------------
# Zjistí pravdìpodobnost hrany jako souèásti koordinace.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost_koordinace
{
    my $r = shift; # index øídícího uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $z = shift; # index závislého uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $stav = shift; # odkaz na hash se stavem analýzy; umo¾òuje podmínit pravdìpodobnost závislosti vlastnostmi jiných závislostí
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    # Zjistit, zda øídící èlen mù¾e být koordinaèní spojkou.
    my $c = ud("KJJ $anot->[$r]{slovo}");
    if($c==0)
    {
        return(0, 0, "");
    }
    # Zjistit, v jakém procentu právì toto heslo øídí koordinaci.
    my $uss = ud("USS $anot->[$r]{slovo}");
    die("CHYBA! Rozpor: USS=0, KJJ=$c pro slovo $anot->[$r]{slovo}\n") if($uss==0);
    my $prk = $c/$uss;
    # Znaèka prvního èlena koordinace. Pokud vytváøím novou koordinaci, je to
    # znaèka uzlu $z, pokud roz¹iøuju existující koordinaci, musím ji pøeèíst
    # v uzlu této koordinace.
    my $ja;
    my $sourozenec;
    # Pokud tato spojka u¾ byla pou¾ita v nìjaké koordinaci, není mo¾né na ni
    # povìsit novou koordinaci, ale je mo¾né stávající koordinaci roz¹íøit.
    if($stav->{coord}[$r])
    {
        $ja = $rznacka;
        # Roz¹íøení existující koordinace. Závislá musí být èárka a musí viset
        # nalevo od spojky.
        if($anot->[$z]{slovo} eq "," && $z<$r)
        {
            # Zjistit, kdo by pak byl dal¹ím èlenem koordinace.
            for(my $i = $z-1; $i>=0; $i--)
            {
                if($stav->{rodic}[$i]==-1)
                {
                    # Zavì¹ení nového èlena na spojku bude typicky povoleno a¾
                    # díky zavì¹ení èárky, ale musíme zkontrolovat, ¾e k tomu
                    # opravdu dojde. Pøi backtrackingu to není zaruèeno,
                    # proto¾e mezi èárkou a novým èlenem mohl zùstat uzel,
                    # který visí na nule.
                    my @rodic1 = @{$stav->{rodic}};
                    $rodic1[$z] = $r;
                    my @povol = povol::zjistit_povol(\@rodic1);
                    for(my $j = 0; $j<=$#povol; $j++)
                    {
                        if($povol[$j] eq "$r-$i")
                        {
                            $sourozenec = $i;
                            goto nalezeno;
                        }
                    }
                    last;
                }
            }
            # Nebyl-li nalezen potenciální sourozenec, nelze koordinaci
            # roz¹íøit a èárka má jinou funkci.
            return(0, 0, "");
        nalezeno1:
        }
        else
        {
            return(0, 0, "");
        }
    }
    else
    {
        $ja = $zznacka;
        # Zjistit míru koordinaèní ekvivalence mezi závislým èlenem a
        # nejbli¾¹ím volným uzlem na druhé stranì od spojky.
        # Najít volný uzel na druhé stranì od spojky.
        if($z<$r)
        {
            for(my $i = $r+1; $i<=$#{$anot}; $i++)
            {
                if($stav->{rodic}[$i]==-1)
                {
                    # Zkontrolovat, ¾e zavì¹ení partnera pod spojku je
                    # povoleno. Pøi bì¾ném výpoètu to tak sice být musí, ale
                    # pøi backtrackingu nikoli, proto¾e mezi spojkou a
                    # partnerem mohl zùstat uzel, který visí na nule.
                    for(my $j = 0; $j<=$#{$stav->{povol}}; $j++)
                    {
                        if($stav->{povol}[$j] eq "$r-$i")
                        {
                            $sourozenec = $i;
                            goto nalezeno;
                        }
                    }
                    last;
                }
            }
        }
        else
        {
            for(my $i = $r-1; $i>=0; $i--)
            {
                # Zkontrolovat, ¾e zavì¹ení partnera pod spojku je
                # povoleno. Pøi bì¾ném výpoètu to tak sice být musí, ale
                # pøi backtrackingu nikoli, proto¾e mezi spojkou a
                # partnerem mohl zùstat uzel, který visí na nule.
                my @povol = povol::zjistit_povol($stav->{rodic});
                for(my $j = 0; $j<=$#povol; $j++)
                {
                    if($povol[$j] eq "$r-$i")
                    {
                        $sourozenec = $i;
                        goto nalezeno;
                    }
                }
                last;
            }
        }
        # Na druhé stranì od spojky není ¾ádný volný uzel.
        return(0, 0, "");
    }
nalezeno:
    # Zjistit, zda potenciální sourozenec není ve skuteènosti nadøízený spojky.
    for(my $i = $stav->{rodic}[$r]; $i!=-1; $i = $stav->{rodic}[$i])
    {
        if($i==$sourozenec)
        {
            return(0, 0, "");
        }
    }
    # Zjistit míru ekvivalence potenciálních sourozencù.
    my $hrana = "KZZ $ja $stav->{uznck}[$sourozenec]";
    my $j = ud("UZZ $ja");
    # Zvýhodnit koordinace slov s toto¾nou znaèkou. Dát jim do èitatele toté¾, co budou mít ve jmenovateli, aby jim vy¹la
    # pravdìpodobnost 1.
    $c = $ja eq $stav->{uznck}[$sourozenec] ? $j : ud($hrana);
    my $ls = $konfig->{ls};
    my $p = $j!=0 ? $prk*(1-$ls)*$c/$j : 0;
    if($p>0 && $prk>0.5 && $ja eq $stav->{uznck}[$sourozenec] && $ja=~m/^A/)
    {
        $p += 1;
    }
    # Vrátit nejen pravdìpodobnost a èetnost, ale i hranu, která musí zvítìzit
    # v pøí¹tím kole, pokud nyní zvítìzí tato.
    return($p, $c, "$r-$sourozenec");
}



#------------------------------------------------------------------------------
# Zjistí, zda daná závislost je v dané vìtì závislostí koøenového slovesa
# vzta¾né vedlej¹í vìty na nejbli¾¹í jmenné frázi vlevo. Vzta¾né zájmeno u¾
# musí v tuto chvíli viset na slovesu.
#------------------------------------------------------------------------------
sub jde_o_vztaznou_vetu
{
    my $r = shift; # index øídícího uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $z = shift; # index závislého uzlu hrany, její¾ pravdìpodobnost se zji¹»uje
    my $stav = shift; # odkaz na hash se stavem analýzy; umo¾òuje podmínit pravdìpodobnost závislosti vlastnostmi jiných závislostí
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    my $zajmeno;
    # Slovní druhy radìji zji¹»ujeme podle upravených znaèek, jako NP se pøece mù¾e chovat i èíslovka apod.!
    if($r<$z && $zznacka=~m/^V/ && $rznacka=~m/^[NP]/)
    {
        my $s = 0;
        for(my $i = $z-1; $i>=0; $i--)
        {
            if($s==0 &&
            # Mezi øídícím podstatným jménem a závislým slovesem se nachází tvar zájmena "který".
               $anot->[$i]{heslo} eq "který" &&
            # Toto zájmeno buï pøímo visí na dotyèném slovese,
               ($stav->{rodic}[$i]==$z ||
            # nebo visí na pøedlo¾ce a ta visí na dotyèném slovese.
                $stav->{rodic}[$stav->{rodic}[$i]]==$z &&
                $stav->{uznck}[$stav->{rodic}[$i]]=~m/^R/))
            {
                # Test shody.
                if(shoda_jmeno_vztazne_zajmeno($anot->[$r]{znacka}, $anot->[$i]{slovo}))
                {
                    $zajmeno = $anot->[$i]{slovo};
                    $s++;
                }
                else
                {
                    return 0;
                }
            }
            elsif($s==1 && $anot->[$i]{slovo} eq "," && $stav->{rodic}[$i]==$z)
            {
                $s++;
            }
            # Musíme dojet a¾ k øídícímu podstatnému jménu. Pokud toti¾ cestou
            # narazíme na jiné pasující podstatné jméno, mìlo by dostat pøednost!
            elsif($s==2 && $stav->{uznck}[$i]=~m/^[NP]/ &&
                  shoda_jmeno_vztazne_zajmeno($anot->[$i]{znacka}, $zajmeno))
            {
                if($i==$r)
                {
                    # Je¹tì zkontrolovat, ¾e toto zavì¹ení je správné.
                    if($anot->[$z]{rodic_vzor}==$r)
                    {
                        $spravne_vztaz++;
                        $chyba_vztaz = 0;
                    }
                    else
                    {
                        $chyba_vztaz = 1;
                    }
                    $celkem_vztaz++;
                    return 1;
                }
                last;
            }
            elsif($i==$r && $s!=2)
            {
                last;
            }
        }
    }
    return 0;
}



#------------------------------------------------------------------------------
# Zjistí, zda je shoda v rodì a èísle (ne v pádì) mezi jménem, jeho¾ morfolo-
# gickou znaèku pøiná¹í první parametr, a vzta¾ným zájmenem, jeho¾ tvar pøiná¹í
# druhý parametr.
#------------------------------------------------------------------------------
sub shoda_jmeno_vztazne_zajmeno
{
    my $znr = $_[0];
    my $slz = $_[1];
    my $vysledek =
    $slz=~m/(ý|ého|ému|ém|ým)$/ && $znr=~m/^..[MI]S/ ||
    $slz=~m/(í|ých|ým|é|ými)$/ && $znr=~m/^..MP/ ||
    $slz=~m/(é|ých|ým|ými)$/ && $znr=~m/^..[IF]P/ ||
    $slz=~m/(á|é|ou)$/ && $znr=~m/^..FS/ ||
    $slz=~m/(é|ého|ému|ém|ým)$/ && $znr=~m/^..NS/ ||
    $slz=~m/(á|ých|ým|ými)$/ && $znr=~m/^..NP/;
    return $vysledek;
}



#------------------------------------------------------------------------------
# Zjistí èetnost a pravdìpodobnost hrany. Zhodnotí zvlá¹» mo¾nost, ¾e jde o
# pravou závislost, a zvlá¹», ¾e jde o èást koordinace. Výsledek vrátí zabalený
# v hashi (vèetnì svých vstupních parametrù $r a $z).
#------------------------------------------------------------------------------
sub ohodnotit_hranu
{
    my $r = shift; # index øídícího uzlu hodnocené hrany
    my $z = shift; # index závislého uzlu hodnocené hrany
    my $stav = shift; # odkaz na hash se stavem analýzy; umo¾òuje podmínit pravdìpodobnost závislosti vlastnostmi jiných závislostí
    my $konfig = \%main::konfig;
    my ($p, $c) = zjistit_pravdepodobnost($r, $z, $stav);
    my ($pk, $ck, $priste) = zjistit_pravdepodobnost_koordinace($r, $z, $stav);
    my %zaznam;
    $zaznam{r} = $r;
    $zaznam{z} = $z;
    if($pk>$p)
    {
        $zaznam{p} = $pk;
        $zaznam{c} = $ck;
        $zaznam{priste} = $priste;
    }
    else
    {
        $zaznam{p} = $p;
        $zaznam{c} = $c;
    }
    # Experimentálnì zohlednit té¾ plodnost.
    if($konfig->{plodnost})
    {
        my $pp = plodnost::ohodnotit($main::anot[$r]{uznacka}, $stav->{ndeti}[$r]);
        $zaznam{p} *= $pp;
        $zaznam{c} *= $pp;
    }
    # Experimentálnì zohlednit vzdálenost je¹tì jiným zpùsobem: vydìlit pravdìpodobnost vzdáleností.
    if($konfig->{vzdalenost_delitel})
    {
        my $vzdalenost = abs($r-$z);
        $zaznam{p} /= $vzdalenost;
        $zaznam{c} /= $vzdalenost;
    }
    return \%zaznam;
}



#------------------------------------------------------------------------------
# Vrátí poèet výskytù události.
#------------------------------------------------------------------------------
sub ud
{
    my $ud = shift; # událost, její¾ èetnost chceme znát
    my $statref = shift; # odkaz na hash, v nìm¾ se má hledat
    # Jestli¾e volající nedodal statistický model, pou¾ít globální promìnnou.
    if(!$statref)
    {
        $statref = \%main::stat;
    }
    # Rozdìlit alternativy do samostatných událostí.
    my @alt; # seznam alternativních událostí
    if(!$main::konfig{morfologicke_alternativy})
    {
        $alt[0] = $ud;
    }
    else
    {
        @alt = rozepsat_alternativy($ud);
#        @alt = rozepsat_alternativy0($ud);
    }
    # Seèíst výskyty jednotlivých dílèích událostí.
    my $n;
    for(my $i = 0; $i<=$#alt; $i++)
    {
        if(exists($statref->{$alt[$i]}))
        {
            $n += $statref->{$alt[$i]};
        }
    }
    return $n;
}



#------------------------------------------------------------------------------
# Pøeète událost urèenou k trénování nebo zji¹tìní èetnosti. Najde v ní øetìzce
# alternativních znaèek, tj. podøetìzce neobsahující mezerový znak (mezera,
# tabulátor aj.) a obsahující alespoò jedno svislítko. Ka¾dý takový øetìzec
# rozdìlí na jednotlivé alternativy. Vrátí pole událostí, z nich¾ ka¾dá
# obsahuje právì jednu kombinaci alternativ. Napø. pro událost "ZZZ N2|N4 A1|A5"
# vrátí události "ZZZ N2 A1", "ZZZ N2 A5", "ZZZ N4 A1" a "ZZZ N4 A5".
#------------------------------------------------------------------------------
sub rozepsat_alternativy
{
    my $ud = shift;
    # Zdá se, ¾e øe¹ení pomocí regulárních výrazù nám nìkde ztrácí pamì».
    # Pokusím se to tedy napsat konzervativnìji.
    # Rozsekat událost na bloky mezi mezerami. Vèetnì pøípadných prázdných
    # øetìzcù tam, kde byly dvì mezery vedle sebe. Aby po slo¾ení událost
    # vypadala vìrnì.
    my @bloky = split(/ /, $ud);
    # Projít v¹echny bloky a zpracovat ty, které obsahují svislítko.
    my @alternativy;
    for(my $i = 0; $i<=$#bloky; $i++)
    {
        # Rozdìlit blok na alternativy.
        my @alternativy_blok = split(/\|/, $bloky[$i]);
        # Ulo¾it alternativy do dvojrozmìrného pole bloky-alternativy.
        @alternativy[$i] = \@alternativy_blok;
    }
    # Sestavit v¹echny kombinace v¹ech alternativ v¹ech blokù.
    my @alt;
    # Pole indexù alternativ jednotlivých blokù.
    for(my @indexy = map{0}(0..$#bloky);;)
    {
        # Vybrat alternativy blokù pro aktuální kombinaci.
        my @vyber;
        for(my $i = 0; $i<=$#bloky; $i++)
        {
            $vyber[$i] = $alternativy[$i][$indexy[$i]];
        }
        # Slepit pøíslu¹nou alternativu.
        my $alternativa = join(" ", @vyber);
        # Ulo¾it alternativu do výstupního pole.
        push(@alt, $alternativa);
        last unless(zvysit_index(\@indexy, \@alternativy));
    }
    return @alt;
}



#------------------------------------------------------------------------------
# Zvý¹í vektorový index do dvourozmìrného pole. Pokud u¾ jsou v¹echny slo¾ky na
# maximu, vektor se vynuluje a funkce vrátí nulu (neúspìch).
#------------------------------------------------------------------------------
sub zvysit_index
{
    my $index = shift;
    my $pole = shift;
    for(my $i = $#{$index}; $i>=0; $i--)
    {
        if($index->[$i]<$#{$pole->[$i]})
        {
            $index->[$i]++;
            return 1;
        }
        else
        {
            $index->[$i] = 0;
        }
    }
    # Dostali-li jsme se a¾ sem, v¹echny indexy byly na maximu a teï jsou vynulované.
    return 0;
}



#------------------------------------------------------------------------------
# Pøeète událost urèenou k trénování nebo zji¹tìní èetnosti. Najde v ní øetìzce
# alternativních znaèek, tj. podøetìzce neobsahující mezerový znak (mezera,
# tabulátor aj.) a obsahující alespoò jedno svislítko. Ka¾dý takový øetìzec
# rozdìlí na jednotlivé alternativy. Vrátí pole událostí, z nich¾ ka¾dá
# obsahuje právì jednu kombinaci alternativ. Napø. pro událost "ZZZ N2|N4 A1|A5"
# vrátí události "ZZZ N2 A1", "ZZZ N2 A5", "ZZZ N4 A1" a "ZZZ N4 A5".
#------------------------------------------------------------------------------
sub rozepsat_alternativy0
{
    my $ud = shift;
    my @alt;
    $alt[0] = $ud;
    for(my $i = 0; $i<=$#alt; $i++)
    {
        while($alt[$i] =~ m/ ([^\| ]+)\|(\S+)/)
        {
            my $hlava = $1;
            my $zbytek = $2;
            # Aby se dal zbytek pou¾ívat v regulárních výrazech, v¹echna svislítka v nìm zne¹kodnit.
            my $zbytekr = $zbytek;
            $zbytekr =~ s/\|/\\\|/g;
            $zbytekr =~ s/\^/\\\^/g;
            $zbytekr =~ s/\*/\\\*/g;
            my $hlavar = $hlava;
            $hlavar =~ s/\^/\\\^/g;
            $hlavar =~ s/\*/\\\*/g;
            # Alternativu se zbytkem bez hlavy zkopírovat na konec.
            push(@alt, $alt[$i]);
            $alt[$#alt] =~ s/ $hlavar\|$zbytekr/ $zbytek/;
            # V aktuální alternativì nechat jenom hlavu.
            $alt[$i] =~ s/ $hlavar\|$zbytekr/ $hlava/;
        }
    }
    return @alt;
}



#------------------------------------------------------------------------------
# Pro danou dvojici r-z zjistí, zda na r je¹tì visí jiný uzel se stejnou
# znaèkou jako z.
#------------------------------------------------------------------------------
sub ma_sourozence_stejneho_druhu
{
    my $anot = shift;
    my $rodic = shift;
    my $r = shift;
    my $z = shift;
    for(my $i = 0; $i<=$#{$rodic}; $i++)
    {
        if($i!=$z && $rodic->[$i]==$r && $anot->[$i]{uznacka} eq $anot->[$z]{uznacka})
        {
            return 1;
        }
    }
    return 0;
}



1;
