package model;
use utf8;
use povol;
use plodnost;
use ud;



#------------------------------------------------------------------------------
# Zjistí doplňkové parametry závislosti.
#------------------------------------------------------------------------------
sub zjistit_smer_a_delku
{
    my $anot = shift; # odkaz na pole hashů
    my $r = shift; # index řídícího uzlu závislosti
    my $z = shift; # index závislého uzlu závislosti
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Výstupní proměnné.
    my $smer;
    my $delka;
    if($r==0 && $konfig->{pod_korenem_sloveso_misto_smeru})
    {
        # U kořene nás nezajímá směr, ale zajímá nás existence slovesa.
        my $sloveso = join("", map{substr($_->{znacka}, 0, 1)}(@{$anot})) =~ m/V/;
        $smer = $sloveso ? "V" : "N";
    }
    else
    {
        # Zjistit směr závislosti (doprava nebo doleva).
        $smer = $r<$z ? "P" : "L";
    }
    # Zjistit délku závislosti (daleko nebo blízko (v sousedství)).
    if($konfig->{vzdalenost})
    {
        $delka = abs($r-$z)>1 ? "D" : "B";
        # Rozšířit délku o informaci, zda se mezi $r a $z nachází čárka.
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
# Zjistí pravděpodobnost závislosti nebo koordinace pro informaci, nikoli pro
# rozhodování při budování stromu. Pravděpodobnost tedy nebude zkreslena snahou
# přinutit některé věci k dřívějšímu spojení. Díky tomu by měla být využitelná
# při snaze ohodnotit celý strom.
#------------------------------------------------------------------------------
sub zjistit_nezkreslenou_pravdepodobnost
{
    my $anot = shift; # odkaz na pole hashů
    my $r = shift; # index řídícího uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $z = shift; # index závislého uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $stav = shift; # potřebujeme ho ke zjištění zděděných značek u koordinací
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    my($smer, $delka);
    my($hrana, $c, $p);
    ($smer, $delka) = zjistit_smer_a_delku($anot, $r, $z);
    my $prm = "$smer $delka";
    # Nyní počítám pouze s modelem, který obvykle používám.
    # Pokud někdo v konfiguraci zapne jiný model, ohlásit chybu!
    if($konfig->{"model"} eq "ls*slova+lz*znacky")
    {
        my $ls = $konfig->{ls};
        my $lz = 1-$ls;
        # Zjistit četnosti všech relevantních událostí v trénovacích datech.
        my $coss = ud("OSS $anot->[$r]{slovo} $anot->[$z]{slovo} $prm");
        # Pokusné volitelné rozšíření: má uzel sourozence stejného druhu?
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
        # Zkombinovat slovní a značkovou četnost do jedné.
        $c = $ls*$coss+$lz*$cozz;
        # Na základě četnosti odhadnout pravděpodobnost.
        # Přístup 1: místo pravděpodobností porovnávat přímo četnosti.
        if($konfig->{abscetnost})
        {
            $p = $c;
        }
        # Přístup 2: "relativní pravděpodobnost", tj. relativní četnost v rámci
        # pouze těch událostí, které jsou pro daný závislý uzel relevantní.
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
        # Zjistit, zda řídící člen může být koordinační spojkou.
        my $ckoord = ud("KJJ $anot->[$r]{slovo}");
        my $prk;
        # Zjistit, v jakém procentu právě toto heslo řídí koordinaci.
        $prk = 0;
        my $cuss = ud("USS $anot->[$r]{slovo}");
        $prk = $ckoord/$cuss unless($cuss==0);
        # Pravděpodobnost závislosti pak bude vynásobena (1-$prk), aby byla
        # srovnatelná s pravděpodobnostmi koordinací.
        $p *= 1-$prk;
    }
    return($p, $c);
}



#------------------------------------------------------------------------------
# Zjistí pravděpodobnost závislosti ve zvoleném modelu.
# Vrátí pravděpodobnost hrany, četnost hrany a popis hrany (pro ladící účely).
# Protože se používá pro vlastní budování stromu, má dovoleno pravděpodobnost
# různě zkreslovat, takže to, co z něj padá, vlastně pravá pravděpodobnost není.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost
{
    my $anot = shift; # odkaz na pole hashů
    my $r = shift; # index řídícího uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $z = shift; # index závislého uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $stav = shift; # odkaz na hash se stavem analýzy; umožňuje podmínit pravděpodobnost závislosti vlastnostmi jiných závislostí
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    # Téměř vyloučit závislost čehokoli na předložce, na které už něco visí.
    if($rznacka=~m/^R/ && $stav->{ndeti}[$r]>0)
    {
        return(0, 0, "$r $z NA PREDLOZCE UZ NECO VISI");
    }
    # Zvláštní zacházení se vztažnými vedlejšími větami.
    if($konfig->{vztaz})
    {
        if(jde_o_vztaznou_vetu($anot, $r, $z, $stav))
        {
            return(1, 0, "$r $z VZTAZNA VETA");
        }
    }
    # Pokus: zakázat podstatným jménům ve 2. pádě přeskakovat sourozence při zavěšování doleva.
    if($konfig->{nepreskocg} && $zznacka eq "N2" && $z-$r>1)
    {
        # Projít uzly napravo od řídícího, počínaje závislým zprava doleva.
        for(my $i = $z; $i>$r; $i--)
        {
            # Zjistit, na kterém konci dvojice uzel závisí (řídící, nebo
            # závislý?) Pokud závisí na závislém konci (vpravo), je to OK.
            # Pokud závisí na řídícím (vlevo), byl by přeskočen, a tomu zde
            # chceme bránit (závislý by měl raději záviset na něm než na
            # řídícím). Pozor, na jednom z dvojice záviset musí, jinak by
            # řídící a závislý nebyli sousedé z hlediska projektivity a
            # dotyčná závislost by vůbec neměla být povolena!
            my $j;
            for($j = $i; $j!=$r && $j!=$z && $j!=-1; $j = $stav->{rodic}[$j]) {}
            if($j==-1 && $r!=0)
            {
                # Závislost by neměla být vůbec povolena, protože mezi
                # řídícím a závislým leží uzel, který zatím není podřízen
                # ani jednomu z nich. Zde to nemůžeme ohlásit jako chybu,
                # protože se někdo mohl zeptat i na pravděpodobnost
                # nepovolené závislosti, ale každopádně vrátíme nulu.
                return(0, 0, "NEPOVOLENO KVULI PROJEKTIVITE, $i NENI PODRIZENO ANI $r, ANI $z");
            }
            if($j==$r)
            {
                return(0, 0, "$r $z BY PRESKOCILO $i");
            }
        }
    }
    # Zjistit skutečnou pravděpodobnost, nezkreslenou snahami něco spojit dříve a něco později.
    my ($p, $c) = zjistit_nezkreslenou_pravdepodobnost($anot, $r, $z, $stav);
    return($p, $c);
}



#------------------------------------------------------------------------------
# Zjistí pravděpodobnost hrany jako součásti koordinace.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost_koordinace
{
    my $anot = shift; # odkaz na pole hashů
    my $r = shift; # index řídícího uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $z = shift; # index závislého uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $stav = shift; # odkaz na hash se stavem analýzy; umožňuje podmínit pravděpodobnost závislosti vlastnostmi jiných závislostí
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    # Zjistit, zda řídící člen může být koordinační spojkou.
    my $c = ud("KJJ $anot->[$r]{slovo}");
    if($c==0)
    {
        return(0, 0, "");
    }
    # Zjistit, v jakém procentu právě toto heslo řídí koordinaci.
    my $uss = ud("USS $anot->[$r]{slovo}");
    die("CHYBA! Rozpor: USS=0, KJJ=$c pro slovo $anot->[$r]{slovo}\n") if($uss==0);
    my $prk = $c/$uss;
    # Značka prvního člena koordinace. Pokud vytvářím novou koordinaci, je to
    # značka uzlu $z, pokud rozšiřuju existující koordinaci, musím ji přečíst
    # v uzlu této koordinace.
    my $ja;
    my $sourozenec;
    # Pokud tato spojka už byla použita v nějaké koordinaci, není možné na ni
    # pověsit novou koordinaci, ale je možné stávající koordinaci rozšířit.
    if($stav->{coord}[$r])
    {
        $ja = $rznacka;
        # Rozšíření existující koordinace. Závislá musí být čárka a musí viset
        # nalevo od spojky.
        if($anot->[$z]{slovo} eq "," && $z<$r)
        {
            # Zjistit, kdo by pak byl dalším členem koordinace.
            for(my $i = $z-1; $i>=0; $i--)
            {
                if($stav->{rodic}[$i]==-1)
                {
                    # Zavěšení nového člena na spojku bude typicky povoleno až
                    # díky zavěšení čárky, ale musíme zkontrolovat, že k tomu
                    # opravdu dojde. Při backtrackingu to není zaručeno,
                    # protože mezi čárkou a novým členem mohl zůstat uzel,
                    # který visí na nule.
                    my @rodic1 = @{$stav->{rodic}};
                    $rodic1[$z] = $r;
                    my @povol = povol::zjistit_povol($anot, \@rodic1);
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
            # rozšířit a čárka má jinou funkci.
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
        # Zjistit míru koordinační ekvivalence mezi závislým členem a
        # nejbližším volným uzlem na druhé straně od spojky.
        # Najít volný uzel na druhé straně od spojky.
        if($z<$r)
        {
            for(my $i = $r+1; $i<=$#{$anot}; $i++)
            {
                if($stav->{rodic}[$i]==-1)
                {
                    # Zkontrolovat, že zavěšení partnera pod spojku je
                    # povoleno. Při běžném výpočtu to tak sice být musí, ale
                    # při backtrackingu nikoli, protože mezi spojkou a
                    # partnerem mohl zůstat uzel, který visí na nule.
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
                # Zkontrolovat, že zavěšení partnera pod spojku je
                # povoleno. Při běžném výpočtu to tak sice být musí, ale
                # při backtrackingu nikoli, protože mezi spojkou a
                # partnerem mohl zůstat uzel, který visí na nule.
                my @povol = povol::zjistit_povol($anot, $stav->{rodic});
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
        # Na druhé straně od spojky není žádný volný uzel.
        return(0, 0, "");
    }
nalezeno:
    # Zjistit, zda potenciální sourozenec není ve skutečnosti nadřízený spojky.
    for(my $i = $stav->{rodic}[$r]; $i!=-1; $i = $stav->{rodic}[$i])
    {
        if($i==$sourozenec)
        {
            return(0, 0, "");
        }
    }
    # Zjistit míru ekvivalence potenciálních sourozenců.
    my $hrana = "KZZ $ja $stav->{uznck}[$sourozenec]";
    my $j = ud("UZZ $ja");
    # Zvýhodnit koordinace slov s totožnou značkou. Dát jim do čitatele totéž, co budou mít ve jmenovateli, aby jim vyšla
    # pravděpodobnost 1.
    $c = $ja eq $stav->{uznck}[$sourozenec] ? $j : ud($hrana);
    my $ls = $konfig->{ls};
    my $p = $j!=0 ? $prk*(1-$ls)*$c/$j : 0;
    if($p>0 && $prk>0.5 && $ja eq $stav->{uznck}[$sourozenec] && $ja=~m/^A/)
    {
        $p += 1;
    }
    # Vrátit nejen pravděpodobnost a četnost, ale i hranu, která musí zvítězit
    # v příštím kole, pokud nyní zvítězí tato.
    return($p, $c, "$r-$sourozenec");
}



#------------------------------------------------------------------------------
# Zjistí, zda daná závislost je v dané větě závislostí kořenového slovesa
# vztažné vedlejší věty na nejbližší jmenné frázi vlevo. Vztažné zájmeno už
# musí v tuto chvíli viset na slovesu.
#------------------------------------------------------------------------------
sub jde_o_vztaznou_vetu
{
    my $anot = shift; # odkaz na pole hashů
    my $r = shift; # index řídícího uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $z = shift; # index závislého uzlu hrany, jejíž pravděpodobnost se zjišťuje
    my $stav = shift; # odkaz na hash se stavem analýzy; umožňuje podmínit pravděpodobnost závislosti vlastnostmi jiných závislostí
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    my $zajmeno;
    # Slovní druhy raději zjišťujeme podle upravených značek, jako NP se přece může chovat i číslovka apod.!
    if($r<$z && $zznacka=~m/^V/ && $rznacka=~m/^[NP]/)
    {
        my $s = 0;
        for(my $i = $z-1; $i>=0; $i--)
        {
            if($s==0 &&
            # Mezi řídícím podstatným jménem a závislým slovesem se nachází tvar zájmena "který".
               $anot->[$i]{heslo} eq "který" &&
            # Toto zájmeno buď přímo visí na dotyčném slovese,
               ($stav->{rodic}[$i]==$z ||
            # nebo visí na předložce a ta visí na dotyčném slovese.
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
            # Musíme dojet až k řídícímu podstatnému jménu. Pokud totiž cestou
            # narazíme na jiné pasující podstatné jméno, mělo by dostat přednost!
            elsif($s==2 && $stav->{uznck}[$i]=~m/^[NP]/ &&
                  shoda_jmeno_vztazne_zajmeno($anot->[$i]{znacka}, $zajmeno))
            {
                if($i==$r)
                {
                    # Ještě zkontrolovat, že toto zavěšení je správné.
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
# Zjistí, zda je shoda v rodě a čísle (ne v pádě) mezi jménem, jehož morfolo-
# gickou značku přináší první parametr, a vztažným zájmenem, jehož tvar přináší
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
# Zjistí četnost a pravděpodobnost hrany. Zhodnotí zvlášť možnost, že jde o
# pravou závislost, a zvlášť, že jde o část koordinace. Výsledek vrátí zabalený
# v hashi (včetně svých vstupních parametrů $r a $z).
#------------------------------------------------------------------------------
sub ohodnotit_hranu
{
    my $anot = shift; # odkaz na pole hashů
    my $r = shift; # index řídícího uzlu hodnocené hrany
    my $z = shift; # index závislého uzlu hodnocené hrany
    my $stav = shift; # odkaz na hash se stavem analýzy; umožňuje podmínit pravděpodobnost závislosti vlastnostmi jiných závislostí
    my $konfig = \%main::konfig;
    my ($p, $c) = zjistit_pravdepodobnost($anot, $r, $z, $stav);
    my ($pk, $ck, $priste) = zjistit_pravdepodobnost_koordinace($anot, $r, $z, $stav);
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
    # Experimentálně zohlednit též plodnost.
    if($konfig->{plodnost})
    {
        my $pp = plodnost::ohodnotit($anot->[$r]{uznacka}, $stav->{ndeti}[$r]);
        $zaznam{p} *= $pp;
        $zaznam{c} *= $pp;
    }
    # Experimentálně zohlednit vzdálenost ještě jiným způsobem: vydělit pravděpodobnost vzdáleností.
    if($konfig->{vzdalenost_delitel})
    {
        my $vzdalenost = abs($r-$z);
        $zaznam{p} /= $vzdalenost;
        $zaznam{c} /= $vzdalenost;
    }
    return \%zaznam;
}



#------------------------------------------------------------------------------
# Vrátí počet výskytů události.
#------------------------------------------------------------------------------
sub ud
{
    my $ud = shift; # událost, jejíž četnost chceme znát
    my $statref = shift; # odkaz na hash, v němž se má hledat
    return ud::zjistit($ud, $statref);
}



#------------------------------------------------------------------------------
# Pro danou dvojici r-z zjistí, zda na r ještě visí jiný uzel se stejnou
# značkou jako z.
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
