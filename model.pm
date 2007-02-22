package model;
use povol;
use plodnost;



#------------------------------------------------------------------------------
# Zjist� dopl�kov� parametry z�vislosti.
#------------------------------------------------------------------------------
sub zjistit_smer_a_delku
{
    my $r = shift; # index ��d�c�ho uzlu z�vislosti
    my $z = shift; # index z�visl�ho uzlu z�vislosti
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # V�stupn� prom�nn�.
    my $smer;
    my $delka;
    if($r==0 && $konfig->{pod_korenem_sloveso_misto_smeru})
    {
        # U ko�ene n�s nezaj�m� sm�r, ale zaj�m� n�s existence slovesa.
        my $sloveso = join("", map{substr($_->{znacka}, 0, 1)}(@{$anot})) =~ m/V/;
        $smer = $sloveso ? "V" : "N";
    }
    else
    {
        # Zjistit sm�r z�vislosti (doprava nebo doleva).
        $smer = $r<$z ? "P" : "L";
    }
    # Zjistit d�lku z�vislosti (daleko nebo bl�zko (v sousedstv�)).
    if($konfig->{vzdalenost})
    {
        $delka = abs($r-$z)>1 ? "D" : "B";
        # Roz���it d�lku o informaci, zda se mezi $r a $z nach�z� ��rka.
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
# Zjist� pravd�podobnost z�vislosti nebo koordinace pro informaci, nikoli pro
# rozhodov�n� p�i budov�n� stromu. Pravd�podobnost tedy nebude zkreslena snahou
# p�inutit n�kter� v�ci k d��v�j��mu spojen�. D�ky tomu by m�la b�t vyu�iteln�
# p�i snaze ohodnotit cel� strom.
#------------------------------------------------------------------------------
sub zjistit_nezkreslenou_pravdepodobnost
{
    my $r = shift; # index ��d�c�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $z = shift; # index z�visl�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $stav = shift; # pot�ebujeme ho ke zji�t�n� zd�d�n�ch zna�ek u koordinac�
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    my($smer, $delka);
    my($hrana, $c, $p);
    ($smer, $delka) = zjistit_smer_a_delku($r, $z);
    my $prm = "$smer $delka";
    # Nyn� po��t�m pouze s modelem, kter� obvykle pou��v�m.
    # Pokud n�kdo v konfiguraci zapne jin� model, ohl�sit chybu!
    if($konfig->{"model"} eq "ls*slova+lz*znacky")
    {
        my $ls = $konfig->{ls};
        my $lz = 1-$ls;
        # Zjistit �etnosti v�ech relevantn�ch ud�lost� v tr�novac�ch datech.
        my $coss = ud("OSS $anot->[$r]{slovo} $anot->[$z]{slovo} $prm");
        # Pokusn� voliteln� roz���en�: m� uzel sourozence stejn�ho druhu?
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
        # Zkombinovat slovn� a zna�kovou �etnost do jedn�.
        $c = $ls*$coss+$lz*$cozz;
        # Na z�klad� �etnosti odhadnout pravd�podobnost.
        # P��stup 1: m�sto pravd�podobnost� porovn�vat p��mo �etnosti.
        if($konfig->{abscetnost})
        {
            $p = $c;
        }
        # P��stup 2: "relativn� pravd�podobnost", tj. relativn� �etnost v r�mci
        # pouze t�ch ud�lost�, kter� jsou pro dan� z�visl� uzel relevantn�.
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
        die("V konfiguraci byl zapnut nepodporovan� model \"$konfig{model}\"!\n");
    }
    if($konfig->{nekoord})
    {
        # Zjistit, zda ��d�c� �len m��e b�t koordina�n� spojkou.
        my $ckoord = ud("KJJ $anot->[$r]{slovo}");
        my $prk;
        # Zjistit, v jak�m procentu pr�v� toto heslo ��d� koordinaci.
        $prk = 0;
        my $cuss = ud("USS $anot->[$r]{slovo}");
        $prk = $ckoord/$cuss unless($cuss==0);
        # Pravd�podobnost z�vislosti pak bude vyn�sobena (1-$prk), aby byla
        # srovnateln� s pravd�podobnostmi koordinac�.
        $p *= 1-$prk;
    }
    return($p, $c);
}



#------------------------------------------------------------------------------
# Zjist� pravd�podobnost z�vislosti ve zvolen�m modelu.
# Vr�t� pravd�podobnost hrany, �etnost hrany a popis hrany (pro lad�c� ��ely).
# Proto�e se pou��v� pro vlastn� budov�n� stromu, m� dovoleno pravd�podobnost
# r�zn� zkreslovat, tak�e to, co z n�j pad�, vlastn� prav� pravd�podobnost nen�.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost
{
    my $r = shift; # index ��d�c�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $z = shift; # index z�visl�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $stav = shift; # odkaz na hash se stavem anal�zy; umo��uje podm�nit pravd�podobnost z�vislosti vlastnostmi jin�ch z�vislost�
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    # T�m�� vylou�it z�vislost �ehokoli na p�edlo�ce, na kter� u� n�co vis�.
    if($rznacka=~m/^R/ && $stav->{ndeti}[$r]>0)
    {
        return(0, 0, "$r $z NA PREDLOZCE UZ NECO VISI");
    }
    # Zvl�tn� zach�zen� se vzta�n�mi vedlej��mi v�tami.
    if($konfig->{vztaz})
    {
        if(jde_o_vztaznou_vetu($r, $z, $stav))
        {
            return(1, 0, "$r $z VZTAZNA VETA");
        }
    }
    # Pokus: zak�zat podstatn�m jm�n�m ve 2. p�d� p�eskakovat sourozence p�i zav�ov�n� doleva.
    if($konfig->{nepreskocg} && $zznacka eq "N2" && $z-$r>1)
    {
        # Proj�t uzly napravo od ��d�c�ho, po��naje z�visl�m zprava doleva.
        for(my $i = $z; $i>$r; $i--)
        {
            # Zjistit, na kter�m konci dvojice uzel z�vis� (��d�c�, nebo
            # z�visl�?) Pokud z�vis� na z�visl�m konci (vpravo), je to OK.
            # Pokud z�vis� na ��d�c�m (vlevo), byl by p�esko�en, a tomu zde
            # chceme br�nit (z�visl� by m�l rad�ji z�viset na n�m ne� na
            # ��d�c�m). Pozor, na jednom z dvojice z�viset mus�, jinak by
            # ��d�c� a z�visl� nebyli soused� z hlediska projektivity a
            # doty�n� z�vislost by v�bec nem�la b�t povolena!
            my $j;
            for($j = $i; $j!=$r && $j!=$z && $j!=-1; $j = $stav->{rodic}[$j]) {}
            if($j==-1 && $r!=0)
            {
                # Z�vislost by nem�la b�t v�bec povolena, proto�e mezi
                # ��d�c�m a z�visl�m le�� uzel, kter� zat�m nen� pod��zen
                # ani jednomu z nich. Zde to nem��eme ohl�sit jako chybu,
                # proto�e se n�kdo mohl zeptat i na pravd�podobnost
                # nepovolen� z�vislosti, ale ka�dop�dn� vr�t�me nulu.
                return(0, 0, "NEPOVOLENO KVULI PROJEKTIVITE, $i NENI PODRIZENO ANI $r, ANI $z");
            }
            if($j==$r)
            {
                return(0, 0, "$r $z BY PRESKOCILO $i");
            }
        }
    }
    # Zjistit skute�nou pravd�podobnost, nezkreslenou snahami n�co spojit d��ve a n�co pozd�ji.
    my ($p, $c) = zjistit_nezkreslenou_pravdepodobnost($r, $z, $stav);
    return($p, $c);
}



#------------------------------------------------------------------------------
# Zjist� pravd�podobnost hrany jako sou��sti koordinace.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost_koordinace
{
    my $r = shift; # index ��d�c�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $z = shift; # index z�visl�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $stav = shift; # odkaz na hash se stavem anal�zy; umo��uje podm�nit pravd�podobnost z�vislosti vlastnostmi jin�ch z�vislost�
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    # Zjistit, zda ��d�c� �len m��e b�t koordina�n� spojkou.
    my $c = ud("KJJ $anot->[$r]{slovo}");
    if($c==0)
    {
        return(0, 0, "");
    }
    # Zjistit, v jak�m procentu pr�v� toto heslo ��d� koordinaci.
    my $uss = ud("USS $anot->[$r]{slovo}");
    die("CHYBA! Rozpor: USS=0, KJJ=$c pro slovo $anot->[$r]{slovo}\n") if($uss==0);
    my $prk = $c/$uss;
    # Zna�ka prvn�ho �lena koordinace. Pokud vytv���m novou koordinaci, je to
    # zna�ka uzlu $z, pokud roz�i�uju existuj�c� koordinaci, mus�m ji p�e��st
    # v uzlu t�to koordinace.
    my $ja;
    my $sourozenec;
    # Pokud tato spojka u� byla pou�ita v n�jak� koordinaci, nen� mo�n� na ni
    # pov�sit novou koordinaci, ale je mo�n� st�vaj�c� koordinaci roz���it.
    if($stav->{coord}[$r])
    {
        $ja = $rznacka;
        # Roz���en� existuj�c� koordinace. Z�visl� mus� b�t ��rka a mus� viset
        # nalevo od spojky.
        if($anot->[$z]{slovo} eq "," && $z<$r)
        {
            # Zjistit, kdo by pak byl dal��m �lenem koordinace.
            for(my $i = $z-1; $i>=0; $i--)
            {
                if($stav->{rodic}[$i]==-1)
                {
                    # Zav�en� nov�ho �lena na spojku bude typicky povoleno a�
                    # d�ky zav�en� ��rky, ale mus�me zkontrolovat, �e k tomu
                    # opravdu dojde. P�i backtrackingu to nen� zaru�eno,
                    # proto�e mezi ��rkou a nov�m �lenem mohl z�stat uzel,
                    # kter� vis� na nule.
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
            # Nebyl-li nalezen potenci�ln� sourozenec, nelze koordinaci
            # roz���it a ��rka m� jinou funkci.
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
        # Zjistit m�ru koordina�n� ekvivalence mezi z�visl�m �lenem a
        # nejbli���m voln�m uzlem na druh� stran� od spojky.
        # Naj�t voln� uzel na druh� stran� od spojky.
        if($z<$r)
        {
            for(my $i = $r+1; $i<=$#{$anot}; $i++)
            {
                if($stav->{rodic}[$i]==-1)
                {
                    # Zkontrolovat, �e zav�en� partnera pod spojku je
                    # povoleno. P�i b�n�m v�po�tu to tak sice b�t mus�, ale
                    # p�i backtrackingu nikoli, proto�e mezi spojkou a
                    # partnerem mohl z�stat uzel, kter� vis� na nule.
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
                # Zkontrolovat, �e zav�en� partnera pod spojku je
                # povoleno. P�i b�n�m v�po�tu to tak sice b�t mus�, ale
                # p�i backtrackingu nikoli, proto�e mezi spojkou a
                # partnerem mohl z�stat uzel, kter� vis� na nule.
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
        # Na druh� stran� od spojky nen� ��dn� voln� uzel.
        return(0, 0, "");
    }
nalezeno:
    # Zjistit, zda potenci�ln� sourozenec nen� ve skute�nosti nad��zen� spojky.
    for(my $i = $stav->{rodic}[$r]; $i!=-1; $i = $stav->{rodic}[$i])
    {
        if($i==$sourozenec)
        {
            return(0, 0, "");
        }
    }
    # Zjistit m�ru ekvivalence potenci�ln�ch sourozenc�.
    my $hrana = "KZZ $ja $stav->{uznck}[$sourozenec]";
    my $j = ud("UZZ $ja");
    # Zv�hodnit koordinace slov s toto�nou zna�kou. D�t jim do �itatele tot�, co budou m�t ve jmenovateli, aby jim vy�la
    # pravd�podobnost 1.
    $c = $ja eq $stav->{uznck}[$sourozenec] ? $j : ud($hrana);
    my $ls = $konfig->{ls};
    my $p = $j!=0 ? $prk*(1-$ls)*$c/$j : 0;
    if($p>0 && $prk>0.5 && $ja eq $stav->{uznck}[$sourozenec] && $ja=~m/^A/)
    {
        $p += 1;
    }
    # Vr�tit nejen pravd�podobnost a �etnost, ale i hranu, kter� mus� zv�t�zit
    # v p��t�m kole, pokud nyn� zv�t�z� tato.
    return($p, $c, "$r-$sourozenec");
}



#------------------------------------------------------------------------------
# Zjist�, zda dan� z�vislost je v dan� v�t� z�vislost� ko�enov�ho slovesa
# vzta�n� vedlej�� v�ty na nejbli��� jmenn� fr�zi vlevo. Vzta�n� z�jmeno u�
# mus� v tuto chv�li viset na slovesu.
#------------------------------------------------------------------------------
sub jde_o_vztaznou_vetu
{
    my $r = shift; # index ��d�c�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $z = shift; # index z�visl�ho uzlu hrany, jej� pravd�podobnost se zji��uje
    my $stav = shift; # odkaz na hash se stavem anal�zy; umo��uje podm�nit pravd�podobnost z�vislosti vlastnostmi jin�ch z�vislost�
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rznacka = $stav->{uznck}[$r];
    my $zznacka = $stav->{uznck}[$z];
    my $zajmeno;
    # Slovn� druhy rad�ji zji��ujeme podle upraven�ch zna�ek, jako NP se p�ece m��e chovat i ��slovka apod.!
    if($r<$z && $zznacka=~m/^V/ && $rznacka=~m/^[NP]/)
    {
        my $s = 0;
        for(my $i = $z-1; $i>=0; $i--)
        {
            if($s==0 &&
            # Mezi ��d�c�m podstatn�m jm�nem a z�visl�m slovesem se nach�z� tvar z�jmena "kter�".
               $anot->[$i]{heslo} eq "kter�" &&
            # Toto z�jmeno bu� p��mo vis� na doty�n�m slovese,
               ($stav->{rodic}[$i]==$z ||
            # nebo vis� na p�edlo�ce a ta vis� na doty�n�m slovese.
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
            # Mus�me dojet a� k ��d�c�mu podstatn�mu jm�nu. Pokud toti� cestou
            # naraz�me na jin� pasuj�c� podstatn� jm�no, m�lo by dostat p�ednost!
            elsif($s==2 && $stav->{uznck}[$i]=~m/^[NP]/ &&
                  shoda_jmeno_vztazne_zajmeno($anot->[$i]{znacka}, $zajmeno))
            {
                if($i==$r)
                {
                    # Je�t� zkontrolovat, �e toto zav�en� je spr�vn�.
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
# Zjist�, zda je shoda v rod� a ��sle (ne v p�d�) mezi jm�nem, jeho� morfolo-
# gickou zna�ku p�in�� prvn� parametr, a vzta�n�m z�jmenem, jeho� tvar p�in��
# druh� parametr.
#------------------------------------------------------------------------------
sub shoda_jmeno_vztazne_zajmeno
{
    my $znr = $_[0];
    my $slz = $_[1];
    my $vysledek =
    $slz=~m/(�|�ho|�mu|�m|�m)$/ && $znr=~m/^..[MI]S/ ||
    $slz=~m/(�|�ch|�m|�|�mi)$/ && $znr=~m/^..MP/ ||
    $slz=~m/(�|�ch|�m|�mi)$/ && $znr=~m/^..[IF]P/ ||
    $slz=~m/(�|�|ou)$/ && $znr=~m/^..FS/ ||
    $slz=~m/(�|�ho|�mu|�m|�m)$/ && $znr=~m/^..NS/ ||
    $slz=~m/(�|�ch|�m|�mi)$/ && $znr=~m/^..NP/;
    return $vysledek;
}



#------------------------------------------------------------------------------
# Zjist� �etnost a pravd�podobnost hrany. Zhodnot� zvlṻ mo�nost, �e jde o
# pravou z�vislost, a zvlṻ, �e jde o ��st koordinace. V�sledek vr�t� zabalen�
# v hashi (v�etn� sv�ch vstupn�ch parametr� $r a $z).
#------------------------------------------------------------------------------
sub ohodnotit_hranu
{
    my $r = shift; # index ��d�c�ho uzlu hodnocen� hrany
    my $z = shift; # index z�visl�ho uzlu hodnocen� hrany
    my $stav = shift; # odkaz na hash se stavem anal�zy; umo��uje podm�nit pravd�podobnost z�vislosti vlastnostmi jin�ch z�vislost�
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
    # Experiment�ln� zohlednit t� plodnost.
    if($konfig->{plodnost})
    {
        my $pp = plodnost::ohodnotit($main::anot[$r]{uznacka}, $stav->{ndeti}[$r]);
        $zaznam{p} *= $pp;
        $zaznam{c} *= $pp;
    }
    # Experiment�ln� zohlednit vzd�lenost je�t� jin�m zp�sobem: vyd�lit pravd�podobnost vzd�lenost�.
    if($konfig->{vzdalenost_delitel})
    {
        my $vzdalenost = abs($r-$z);
        $zaznam{p} /= $vzdalenost;
        $zaznam{c} /= $vzdalenost;
    }
    return \%zaznam;
}



#------------------------------------------------------------------------------
# Vr�t� po�et v�skyt� ud�losti.
#------------------------------------------------------------------------------
sub ud
{
    my $ud = shift; # ud�lost, jej� �etnost chceme zn�t
    my $statref = shift; # odkaz na hash, v n�m� se m� hledat
    # Jestli�e volaj�c� nedodal statistick� model, pou��t glob�ln� prom�nnou.
    if(!$statref)
    {
        $statref = \%main::stat;
    }
    # Rozd�lit alternativy do samostatn�ch ud�lost�.
    my @alt; # seznam alternativn�ch ud�lost�
    if(!$main::konfig{morfologicke_alternativy})
    {
        $alt[0] = $ud;
    }
    else
    {
        @alt = rozepsat_alternativy($ud);
#        @alt = rozepsat_alternativy0($ud);
    }
    # Se��st v�skyty jednotliv�ch d�l��ch ud�lost�.
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
# P�e�te ud�lost ur�enou k tr�nov�n� nebo zji�t�n� �etnosti. Najde v n� �et�zce
# alternativn�ch zna�ek, tj. pod�et�zce neobsahuj�c� mezerov� znak (mezera,
# tabul�tor aj.) a obsahuj�c� alespo� jedno svisl�tko. Ka�d� takov� �et�zec
# rozd�l� na jednotliv� alternativy. Vr�t� pole ud�lost�, z nich� ka�d�
# obsahuje pr�v� jednu kombinaci alternativ. Nap�. pro ud�lost "ZZZ N2|N4 A1|A5"
# vr�t� ud�losti "ZZZ N2 A1", "ZZZ N2 A5", "ZZZ N4 A1" a "ZZZ N4 A5".
#------------------------------------------------------------------------------
sub rozepsat_alternativy
{
    my $ud = shift;
    # Zd� se, �e �e�en� pomoc� regul�rn�ch v�raz� n�m n�kde ztr�c� pam�.
    # Pokus�m se to tedy napsat konzervativn�ji.
    # Rozsekat ud�lost na bloky mezi mezerami. V�etn� p��padn�ch pr�zdn�ch
    # �et�zc� tam, kde byly dv� mezery vedle sebe. Aby po slo�en� ud�lost
    # vypadala v�rn�.
    my @bloky = split(/ /, $ud);
    # Proj�t v�echny bloky a zpracovat ty, kter� obsahuj� svisl�tko.
    my @alternativy;
    for(my $i = 0; $i<=$#bloky; $i++)
    {
        # Rozd�lit blok na alternativy.
        my @alternativy_blok = split(/\|/, $bloky[$i]);
        # Ulo�it alternativy do dvojrozm�rn�ho pole bloky-alternativy.
        @alternativy[$i] = \@alternativy_blok;
    }
    # Sestavit v�echny kombinace v�ech alternativ v�ech blok�.
    my @alt;
    # Pole index� alternativ jednotliv�ch blok�.
    for(my @indexy = map{0}(0..$#bloky);;)
    {
        # Vybrat alternativy blok� pro aktu�ln� kombinaci.
        my @vyber;
        for(my $i = 0; $i<=$#bloky; $i++)
        {
            $vyber[$i] = $alternativy[$i][$indexy[$i]];
        }
        # Slepit p��slu�nou alternativu.
        my $alternativa = join(" ", @vyber);
        # Ulo�it alternativu do v�stupn�ho pole.
        push(@alt, $alternativa);
        last unless(zvysit_index(\@indexy, \@alternativy));
    }
    return @alt;
}



#------------------------------------------------------------------------------
# Zv��� vektorov� index do dvourozm�rn�ho pole. Pokud u� jsou v�echny slo�ky na
# maximu, vektor se vynuluje a funkce vr�t� nulu (ne�sp�ch).
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
    # Dostali-li jsme se a� sem, v�echny indexy byly na maximu a te� jsou vynulovan�.
    return 0;
}



#------------------------------------------------------------------------------
# P�e�te ud�lost ur�enou k tr�nov�n� nebo zji�t�n� �etnosti. Najde v n� �et�zce
# alternativn�ch zna�ek, tj. pod�et�zce neobsahuj�c� mezerov� znak (mezera,
# tabul�tor aj.) a obsahuj�c� alespo� jedno svisl�tko. Ka�d� takov� �et�zec
# rozd�l� na jednotliv� alternativy. Vr�t� pole ud�lost�, z nich� ka�d�
# obsahuje pr�v� jednu kombinaci alternativ. Nap�. pro ud�lost "ZZZ N2|N4 A1|A5"
# vr�t� ud�losti "ZZZ N2 A1", "ZZZ N2 A5", "ZZZ N4 A1" a "ZZZ N4 A5".
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
            # Aby se dal zbytek pou��vat v regul�rn�ch v�razech, v�echna svisl�tka v n�m zne�kodnit.
            my $zbytekr = $zbytek;
            $zbytekr =~ s/\|/\\\|/g;
            $zbytekr =~ s/\^/\\\^/g;
            $zbytekr =~ s/\*/\\\*/g;
            my $hlavar = $hlava;
            $hlavar =~ s/\^/\\\^/g;
            $hlavar =~ s/\*/\\\*/g;
            # Alternativu se zbytkem bez hlavy zkop�rovat na konec.
            push(@alt, $alt[$i]);
            $alt[$#alt] =~ s/ $hlavar\|$zbytekr/ $zbytek/;
            # V aktu�ln� alternativ� nechat jenom hlavu.
            $alt[$i] =~ s/ $hlavar\|$zbytekr/ $hlava/;
        }
    }
    return @alt;
}



#------------------------------------------------------------------------------
# Pro danou dvojici r-z zjist�, zda na r je�t� vis� jin� uzel se stejnou
# zna�kou jako z.
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
