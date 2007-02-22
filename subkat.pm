# Funkce souvisej�c� se subkategorizac� sloves.
package subkat;
use model;



#------------------------------------------------------------------------------
# Na�te seznam subkategoriza�n�ch r�mc� sloves.
#------------------------------------------------------------------------------
sub cist
{
    my $jmeno_souboru = shift;
    my %subcat; # v�stupn� hash (subkategoriza�n� slovn�k)
    open(SUBCAT, $jmeno_souboru) or die("Nelze otevrit soubor $jmeno_souboru se seznamem ramcu: $!\n");
    while(<SUBCAT>)
    {
        chomp;
        # Na ��dku je nejd��ve sloveso, pak dv� (?) mezery, pak r�mec.
        # R�mec mezery neobsahuje. �leny jsou odd�leny dv�ma vlnovkami.
        # Pr�zdn� r�mec nep�echodn�ch sloves je zastoupen zna�kou <INTR>.
        if(m/(.+?)\s+(.+)$/)
        {
            my $sloveso = $1;
            next if($sloveso eq "b�t");
            my $ramec = $2;
            # Rozd�lit r�mce na jednotliv� vazby.
            my @vazby = split(/~~/, $ramec);
            for(my $i = 0; $i<=$#vazby; $i++)
            {
                # Vazba se skl�d� ze subkategoriza�n� zna�ky a
                # z analytick� funkce (s-zna�ky), odd�len� jsou
                # lom�tkem. Odstranit lom�tko a s-zna�ku.
                $vazby[$i] =~ s-/.*--;
                $subcat{"$sloveso $vazby[$i]"}++;
            }
            # Zapamatovat si, �e sloveso je slovn�kem v�bec n�jak pokryto.
            $subcat{"SLO $sloveso"}++;
            # Zapamatovat si cel� r�mec slovesa (v��e jsme si pamatovali jen jednotliv�
            # vazby) tak, aby bylo mo�n� naj�t v�echny r�mce ur�it�ho slovesa.
            push(@{$subcat{"RAM $sloveso"}}, "$sloveso $ramec");
        }
    }
    close(SUBCAT);
    return \%subcat;
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



#------------------------------------------------------------------------------
# Vytipuje valen�n� z�vislosti ve v�t�. Vol� se p�ed vlastn� anal�zou v�ty.
# Vrac� pole @valencni, jeho� prvek m� tvar $r-$z($p), r a z jsou indexy
# ��d�c�ho a z�visl�ho uzlu a p je pravd�podobnost takov� z�vislosti (podle
# norm�ln�ho modelu, nem� zat�m nic spole�n�ho s pravd�podobnost� pou�it�ho
# r�mce).
#------------------------------------------------------------------------------
sub vytipovat_valencni_zavislosti
{
    my $subcat = shift; # odkaz na hash se subkategoriza�n�m slovn�kem
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zjistit, kter� potenci�ln� z�vislosti ve v�t� by mohly b�t valen�n�.
    my @valencni;
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{uznacka}=~m/^V/)
        {
            # Pro ka�d� sloveso proj�t v�echny ostatn� uzly a zkoumat,
            # jestli by mohly b�t jeho vazbami.
            for(my $j = 0; $j<=$#{$anot}; $j++)
            {
                if($j!=$i)
                {
                    my $zn = $anot->[$j]{uznacka};
                    $zn =~ s/P(\d)/N$1/;
                    $zn =~ s/V([Bp]|jsem|jsi|je|n�|jsme|jste|jsou|budu|bude�|bude|budeme|budete|budou|byl[aoiy]?)/S/;
                    $zn =~ s/V(f|b�t)/VINF/;
                    $zn =~ s/Pse(s)?/PR4/;
                    $zn =~ s/Psi(s)?/PR3/;
                    $zn =~ s/Db/DB/;
                    # P�edlo�ky se konvertuj� p�i na��t�n� valenc�,
                    # proto�e tady nezn�me jejich p�d.
                    $zn =~ s/J(,|�e|aby|zda)/JS($anot->[$j]{slovo})/;
                jeste_jako_n:
                    if(exists($subcat->{"$anot->[$i]{heslo} $zn"}))
                    {
                        # Z�vislost i-j by mohla b�t valen�n�.
                        # Zjistit jej� pravd�podobnost.
                        my ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($i, $j);
                        push(@valencni, "$i-$j($p)");
                    }
                    elsif($zn=~s/^PR/N/)
                    {
                        goto jeste_jako_n;
                    }
                }
            }
        }
    }
    # Set��dit seznam potenci�ln�ch valen�n�ch z�vislost� v t�to v�t� sestupn� podle pravd�podobnosti.
    @valencni = sort
    {
        $a =~ m/(\d+)-(\d+)\((.*)\)/;
        my $ap = $3;
        my $ad = abs($1-$2);
        $b =~ m/(\d+)-(\d+)\((.*)\)/;
        my $bp = $3;
        my $bd = abs($1-$2);
        if($ap!=$bp)
        {
            return $bp<=>$ap;
        }
        else
        {
            return $bd<=>$ad;
        }
    }
    (@valencni);
    return \@valencni;
}



#------------------------------------------------------------------------------
# Projde strom vytvo�en� parserem a pokus� se naj�t slovesa, kter�m chyb�
# n�jak� argument. Pokud takov� najde a pokud nav�c zjist�, �e ve v�t� existuje
# materi�l, kter�m by r�mce mohly j�t naplnit, vr�t� 1. Jinak vr�t� 0.
#------------------------------------------------------------------------------
sub najit_nenaplnene_ramce
{
    my $subcat = shift; # odkaz na hash se subkategoriza�n�m slovn�kem
    my $stav = shift; # odkaz na hash se stavem anal�zy (obsahuje mj. n�vrh stromu)
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Naj�t slovesa.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zaj�maj� n�s pouze slovesa pokryt� subkategoriza�n�m slovn�kem.
        # Nezaj�maj� n�s, pokud jsou v p���est� trpn�m (pak toti� asi chyb� N4 a nem� se dopl�ovat).
        if($anot->[$i]{znacka} =~ m/^V[^s]/ && exists($subcat->{"SLO $anot->[$i]{heslo}"}))
        {
            # Naj�t v�echny navrhovan� d�ti tohoto slovesa.
            my @deti;
            my %vazby_navrh;
            my %k_dispozici;
            for(my $j = 0; $j<=$#{$stav->{rodic}}; $j++)
            {
                # Zapamatovat si, jak� vazby by byly k dispozici.
                my $vznacka;
                if(exists($anot->[$j]{dedic}))
                {
                    $vznacka = prevest_mznacku_na_vazbu($anot->[$anot->[$j]{dedic}]{znacka}, $anot->[$anot->[$j]{dedic}]{heslo});
                }
                else
                {
                    $vznacka = prevest_mznacku_na_vazbu($anot->[$j]{znacka}, $anot->[$j]{heslo});
                }
                $k_dispozici{$vznacka}++;
                if($stav->{rodic}[$j]==$i)
                {
                    push(@deti, $anot->[$j]);
                    # Zapamatovat si, �e se v n�vrhu vyskytla ur�it� vazba.
                    # Bude se n�m to hodit p�i ov��ov�n� napln�nosti r�mc�.
                    $vazby_navrh{$vznacka}++;
                    my $spravne = $anot->[$j]{rodic_vzor}==$i ? 1 : 0;
                }
            }
            # Proj�t v�echny zn�m� r�mce tohoto slovesa a hledat n�jak� napln�n�.
            my $n_naplnenych = 0;
            my $n_lze_naplnit;
            foreach my $ramec (@{$subcat->{"RAM $anot->[$i]{heslo}"}})
            {
                # Zjistit, zda je tento r�mec v navrhovan�m stromu napln�n.
                # Ud�lat si kopii evidence navrhovan�ch vazeb, abychom si v n� mohli �m�rat.
                my %kopie_navrhovanych_vazeb = %vazby_navrh;
                my %kopie_vazeb_k_dispozici = %k_dispozici;
                # Rozd�lit r�mec na jednotliv� vazby.
                # Nejd��v z r�mce odstranit sloveso.
                my $ramec_bez_slovesa = $ramec;
                $ramec_bez_slovesa =~ s/^\S+ //;
                my $ok = 1;
                my $lze_naplnit = 1;
                # R�mec "<INTR>" znamen�, �e jde o nep�echodn� sloveso, kter� nevy�aduje ��dn� argumenty.
                unless($ramec_bez_slovesa eq "<INTR>")
                {
                    my @vazby = split(/~~/, $ramec_bez_slovesa);
                    foreach my $vazba (@vazby)
                    {
                        # Vazba se skl�d� ze subkategoriza�n� zna�ky a
                        # z analytick� funkce (s-zna�ky), odd�len� jsou
                        # lom�tkem. Odstranit lom�tko a s-zna�ku.
                        $vazba =~ s-/.*--;
                        # Zjistit, zda na tuto vazbu je�t� zb�v� n�jak� uzel z n�vrhu.
                        if($kopie_navrhovanych_vazeb{$vazba}>0)
                        {
                            $kopie_navrhovanych_vazeb{$vazba}--;
                            $kopie_vazeb_k_dispozici{$vazba}--;
                        }
                        else
                        {
                            # Zvl�tn� p��pad: PR4 m��e naplnit i N4, tak�e pokud nem��eme naj�t N4, zkus�me je�t� PR4.
                            if($vazba eq "N4" && $kopie_navrhovanych_vazeb{"PR4"}>0)
                            {
                                $kopie_navrhovanych_vazeb{"PR4"}--;
                                $kopie_vazeb_k_dispozici{"PR4"}--;
                            }
                            else
                            {
                                $ok = 0;
                                if($kopie_vazeb_k_dispozici{$vazba}<=0)
                                {
                                    $lze_naplnit = 0;
                                    last;
                                }
                                else
                                {
                                    $kopie_vazeb_k_dispozici{$vazba}--;
                                }
                            }
                        }
                    }
                }
                if($ok)
                {
                    $n_naplnenych++;
                }
                else
                {
                    if($lze_naplnit)
                    {
                        $n_lze_naplnit++;
                        return 1;
                    }
                }
            }
        }
    }
    return 0;
}



#==============================================================================
# Funkce pro zji�t�n�, co lze na sou�asn� anal�ze v�ty zlep�it, aby byly l�pe
# napln�ny valen�n� r�mce.
#==============================================================================



#------------------------------------------------------------------------------
# Z�sk� seznam slov, kter� v dan� anal�ze zapl�uj� n�kter� m�sto ve valen�n�ch
# r�mc�ch (a nen� tedy vhodn� na jejich zav�en� n�co m�nit) a seznam slov,
# kter� nepat�� do prvn� mno�iny a sou�asn� jejich p�ev�en� m��e v�st
# k zapln�n� dal��ch valen�n�ch m�st. Oba seznamy zak�duje do n�vratov�ho pole
# takto: 0 ... slovo u� zapl�uje valenci, nem�nit; 1 ... slovo nezapl�uje
# valenci, ale mohlo by; 2 ... slovo nezapl�uje valenci a ani nebylo zji�t�no,
# �e by mohlo.
#------------------------------------------------------------------------------
sub najit_valencni_rezervy
{
    my $anot = shift; # odkaz na pole hash�
    my $stav = shift; # odkaz na hash (pot�ebujeme z n�j zejm�na n�vrh stromu, ale nejen ten)
    my $subkat = shift; # odkaz na hash se subkategoriza�n�m slovn�kem
    my @evidence; # v�stupn� pole (0 u� pou�ito 1 lze pou��t 2 ostatn�)
    # Naplnit evidenci v�choz�mi hodnotami.
    @evidence = map{2}(0..$#{$anot});
    # Z�skat seznam sloves ve v�t�, pokryt�ch valen�n�m slovn�kem.
    my $slovesa = ziskat_seznam_sloves($anot, $subkat);
    # Z�skat dopl�uj�c� �daje ke v�em uzl�m navr�en�m za d�ti sloves.
    my $deti = obohatit_deti($anot, $stav);
    # Proj�t slovesa a zjistit, co maj� a co jim chyb�.
    foreach my $sloveso (@{$slovesa})
    {
        # Pro dan� sloveso vybrat r�mec, zjistit, kter� slova se v n�m anga�uj� a
        # jak� druhy slov r�mec je�t� sh�n�. Tato zji�t�n� rovnou p�ipsat do
        # centr�ln� evidence vyu�itelnosti slov pro valenci.
        vybrat_ramec_a_promitnout_ho_do_evidence($anot, $sloveso, $deti, $subkat, \@evidence);
    }
    return \@evidence;
}



#------------------------------------------------------------------------------
# D�l�� funkce pro kontrolu valence. Projde v�tu a najde slovesa, pro kter�
# zn�me alespo� jeden r�mec.
#------------------------------------------------------------------------------
sub ziskat_seznam_sloves
{
    my $anot = shift; # odkaz na pole hash�
    my $subcat = shift; # odkaz na hash se subkategoriza�n�m slovn�kem
    my @slovesa;
    # Naj�t slovesa.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zaj�maj� n�s pouze slovesa pokryt� subkategoriza�n�m slovn�kem.
        # Nezaj�maj� n�s, pokud jsou v p���est� trpn�m (pak toti� asi chyb� N4 a nem� se dopl�ovat).
        if($anot->[$i]{znacka} =~ m/^V[^s]/ && exists($subcat->{"SLO $anot->[$i]{heslo}"}))
        {
            push(@slovesa, $i);
        }
    }
    return \@slovesa;
}



#------------------------------------------------------------------------------
# Zjist� pro ka�d� d�t� slovesa informace, kter� mohou rozhodovat o jeho za�azen�
# mezi povinn� nebo voliteln� dopln�n�.
#------------------------------------------------------------------------------
sub obohatit_deti
{
    my $anot = shift; # odkaz na anotace jednotliv�ch slov
    my $stav = shift; # odkaz na hash; pot�ebujeme jen p�edat d�l do model::ohodnotit_hranu(), jinak sta�� pole navrhovan�ch rodi��
    my $navrhrod = $stav->{rodic}; # odkaz na pole index� navrhovan�ch rodi��
    my @hodnoceni; # v�stupn� pole hash�
    # Pot�ebujeme zjistit:
    # - pro ka�d� d�t� slovesa v�hu jeho z�vislosti na jeho rodi�i
    # - pro ka�d� d�t� slovesa po�et sloves mezi n�m a jeho rodi�em
    # - pro ka�d� d�t� slovesa po�et sloves od n�j sm�rem pry� od jeho rodi�e
    my @slovesa; # seznam index� dosud vid�n�ch sloves
    my @deti; # evidence rozpracovan�ch a zpracovan�ch d�t�
    # A te� vlastn� implementace.
    # Proch�zet slova ve v�t�.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zkonstruovat valen�n� zna�ku podle morfologick� zna�ky a d�t ji do hodnocen�.
        $hodnoceni[$i]{vznacka} = zjistit_valencni_znacku($anot, $i);
        # Zkop�rovat do hodnocen� index navrhovan�ho rodi�e, aby se v�em funkc�m nemusel p�ed�vat i stav anal�zy.
        $hodnoceni[$i]{index} = $i;
        $hodnoceni[$i]{rodic} = $navrhrod->[$i];
        $hodnoceni[$i]{vzdalenost} = abs($i-$navrhrod->[$i]);
        # Jsme na d�t�ti slovesa?
        if(je_sloveso($anot->[$navrhrod->[$i]]))
        {
            # Zjistit v�hu z�vislosti aktu�ln�ho d�t�te na slovese.
            $hodnoceni[$i]{vaha} = model::ohodnotit_hranu($i, $navrhrod->[$i], $stav);
            # Je rodi�ovsk� sloveso vpravo od n�s?
            if($navrhrod->[$i]>$i)
            {
                # V�echna dosud vid�n� slovesa p�i��st jako vn�j�� slovesa tohoto uzlu.
                $hodnoceni[$i]{vnejsi} += $#slovesa+1;
                # P�idat se do seznamu d�t� jako rozpracovan�.
                push(@deti, {"index" => $i, "stav" => "rozprac"});
            }
            # Rodi�ovsk� sloveso je vlevo od n�s.
            else
            {
                # Vr�tit se po seznamu vid�n�ch sloves a� k rodi�i tohoto uzlu a spo��tat vnit�n� slovesa.
                for(my $j = $#slovesa; $j>=0 && $slovesa[$j]!=$navrhrod->[$i]; $j--)
                {
                    $hodnoceni[$i]{vnitrni}++;
                }
                # P�idat se do seznamu d�t� rovnou jako zpracovan�.
                push(@deti, {"index" => $i, "stav" => "zprac"});
            }
        }
        # Jsme na slovese? (Pozor na po�ad� krok�, i sloveso m��e b�t d�t�tem jin�ho slovesa!)
        if(je_sloveso($anot->[$i]))
        {
            # P�ipsat se mezi vid�n� slovesa.
            push(@slovesa, $i);
            # Proj�t rozpracovan� d�ti. K ciz�m se p�i��st jako vnit�n�, sv� ukon�it, ke zpracovan�m p��padn� jako vn�j��.
            for(my $j = 0; $j<=$#deti; $j++)
            {
                # Ke zpracovan�m d�tem (nemohou b�t moje), jejich� rodi� le�� vlevo od nich, se p�i��st jako vn�j��.
                my $index = $deti[$j]{index};
                if($deti[$j]{stav} eq "zprac" && $navrhrod->[$index]<$index)
                {
                    $hodnoceni[$index]{vnejsi}++;
                }
                # Rozpracovan� d�ti.
                elsif($deti[$j]{stav} eq "rozprac")
                {
                    # Pokud jsou moje, ozna�it je za zpracovan�.
                    if($navrhrod->[$index]==$i)
                    {
                        $deti[$j]{stav} = "zprac";
                    }
                    # Pokud nejsou moje, p�i��st se k nim jako vnit�n�.
                    else
                    {
                        $hodnoceni[$index]{vnitrni}++;
                    }
                }
            }
        }
    }
    return \@hodnoceni;
}



#------------------------------------------------------------------------------
# D�l�� funkce pro kontrolu valence. Zjist� valen�n� zna�ku slova.
#------------------------------------------------------------------------------
sub zjistit_valencni_znacku
{
    my $anot = shift; # odkaz na pole hash� pro jednotliv� slova ve v�t�
    my $index = shift; # index slova, jeho� valen�n� zna�ka n�s zaj�m�
    my $vznacka;
    if(exists($anot->[$index]{dedic}))
    {
        $vznacka = prevest_mznacku_na_vazbu($anot->[$anot->[$index]{dedic}]{znacka}, $anot->[$anot->[$index]{dedic}]{heslo});
    }
    else
    {
        $vznacka = prevest_mznacku_na_vazbu($anot->[$index]{znacka}, $anot->[$index]{heslo});
    }
    return $vznacka;
}



#------------------------------------------------------------------------------
# Projde r�mce zadan�ho slovesa a porovn� je s d�tmi, kter� slovesu navrhl
# parser. Vybere r�mec, kter� je danou mno�inou d�t� nejl�pe napln�n. Vyhraje
# r�mec, kter�mu z�stalo nejm�n� nezapln�n�ch m�st. P�i rovnosti vyhraje prvn�
# takov� nalezen� r�mec. Mohli bychom je�t� br�t v �vahu, kolik je ve v�t�
# k dispozici uzl� s valen�n� zna�kou, kterou po�aduje n�kter� nezapln�n� m�sto
# r�mce, ale tento po�et nebudeme zn�t p�esn�, dokud v�em sloves�m nep�i�ad�me
# r�mce (n�kter� d�ti sloves mohou b�t ozna�eny za voln� dopln�n� a b�t tak
# k dispozici pro r�mce, kter� by z nich cht�ly ud�lat povinn� dopln�n�), a to
# je za�arovan� kruh. Funkce u� tak� nehled� na to, jak kvalitn�mi dopln�n�mi
# jsou jednotliv� m�sta r�mce zapln�na (nap�. jak daleko m� p��slu�n� d�t� ke
# slovesu), p�esto�e se tato krit�ria pou��vaj� p�i vlastn�m zapl�ov�n� jednoho
# r�mce a v�b�ru mezi n�kolika d�tmi, kter� by dan� m�sto mohly zaplnit.
#
# Funkce nevrac� p��mo vybran� r�mec, ale rovnou v�sledky jeho srovn�n� s d�tmi
# slovesa, proto�e to je to, co volaj�c� pot�ebuje, a my to v pr�b�hu vyb�r�n�
# tak jako tak mus�me z�skat.
#------------------------------------------------------------------------------
sub vybrat_ramec_a_promitnout_ho_do_evidence
{
    my $anot = shift; # odkaz na pole hash�
    my $sloveso = shift; # index do pole @{$anot}
    my $deti = shift; # odkaz na pole s dopl�uj�c�mi informacemi o d�tech sloves
    my $subcat = shift; # odkaz na hash se subkategoriza�n�m slovn�kem
    my $evidence = shift; # odkaz na c�lov� pole
    # Z�skat seznam r�mc� dan�ho slovesa ze slovn�ku.
    my $ramce = $subcat->{"RAM $anot->[$sloveso]{heslo}"};
    # Vybrat z pole informac� o d�tech sloves pouze d�ti na�eho slovesa.
    my @me_deti = grep{$_->{rodic}==$sloveso}(@{$deti});
    # Proj�t v�echny r�mce slovesa, hledat ten nejl�pe zapln�n�.
    my $min_nezaplnenych;
    my $srovnani_min;
    foreach my $ramec (@{$ramce})
    {
        my $vazby = pripravit_ramec_k_porovnani($ramec);
        my $srovnani = porovnat_deti_s_ramcem(\@me_deti, $vazby);
        # Jestli�e srovn�n� vy�lo l�pe ne� u dosud nejlep��ho r�mce, prohl�sit za nejlep�� tenhle.
        if($min_nezaplnenych eq "" || $srovnani->{n_chybi}<$min_nezaplnenych)
        {
            $min_nezaplnenych = $srovnani->{n_chybi};
            $srovnani_min = $srovnani;
        }
    }
    # P�ipsat nejlep�� r�mec do evidence.
    # Uzl�m, kter� se pod�lej� na zapln�n� r�mce, nastavit v evidenci 0.
    foreach my $i (@{$srovnani_min->{nalezeno}})
    {
        $evidence->[$i] = 0;
    }
    # Uzl�m, kter� ode mne ani od nikoho jin�ho nemaj� 0, ale mohly by mi pomoci k lep��mu zapln�n�, nastavit 1.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($srovnani_min->{chybi}{$deti->[$i]{vznacka}} && $evidence->[$i]!=0)
        {
            $evidence->[$i] = 1;
        }
    }
}



#------------------------------------------------------------------------------
# Zpracuje r�mec tak, aby bylo mo�n� s n�m porovnat seznam uzl�, kter� ho maj�
# naplnit.
#------------------------------------------------------------------------------
sub pripravit_ramec_k_porovnani
{
    my $ramec = shift; # �et�zec vazeb odd�len�ch ~~ nebo <INTR>
    # Odstranit z r�mce sloveso.
    my $ramec_bez_slovesa = $ramec;
    $ramec_bez_slovesa =~ s/^\S+ //;
    # P�ev�st r�mec na seznam vazeb. Seznam reprezentovat hashem, pro ka�dou vazbu po�et v�skyt�.
    # R�mec "<INTR>" znamen�, �e jde o nep�echodn� sloveso, kter� nem� ��dn� vazby.
    my %hash;
    unless($ramec_bez_slovesa eq "<INTR>")
    {
        my @vazby = split(/~~/, $ramec_bez_slovesa);
        # P�ev�st pole vazeb na reprezenta�n� hash.
        for(my $i = 0; $i<=$#vazby; $i++)
        {
            # Vazby jsou ulo�eny ve tvaru vznacka/afun. Odstranit analytickou funkci.
            $vazby[$i] =~ s-/.*--;
            $hash{$vazby[$i]}++;
        }
    }
    return \%hash;
}



#------------------------------------------------------------------------------
# D�l�� funkce pro kontrolu valence. Porovn� seznam navrhovan�ch d�t� slovesa
# s r�mcem tohoto slovesa.
#
# Vrac�:
# - seznam valen�n�ch zna�ek, kter� chyb�
# - seznam index� uzl�, kter� pln� roli argument�
#
# M��e se st�t, �e r�mec po�aduje men�� po�et dopln�n� ur�it�ho druhu (nap�. N4),
# ne� kolik takov�ch dopln�n� na slovesu podle n�vrhu vis�. V tom p��pad� je t�eba
# rozhodnout, kter� z navrhovan�ch d�t� je to nejlep�� a ostatn� prohl�sit za
# voln� dopln�n�. Za nejlep�� prohl�s�me to d�t�, jeho� z�vislosti model p�i�ad�
# nejv�t�� v�hu. P�i rovnosti vah rozhodne vzd�lenost d�t�te od slovesa: vyhr�v�
# d�t� odd�len� men��m po�tem jin�ch sloves, potom bli��� d�t�, potom d�t� na
# stran�, na kter� je m�n� dal��ch sloves, potom d�t� vpravo.
#
# Pozor, tato funkce nebere v �vahu, �e mohou existovat je�t� jin� r�mce t�ho�
# slovesa, kter� by seznam d�t� uspokojil.
#------------------------------------------------------------------------------
sub porovnat_deti_s_ramcem
{
    my $deti = shift; # odkaz na pole hash� o d�tech (obsahuj� mj. i odkaz do @anot na standardn� �daje)
    my $ramec = shift; # odkaz na hash indexovan� valen�n�mi zna�kami, hodnoty jsou po�et po�adovan�ch takov�ch vazeb
    # Se�adit d�ti sestupn� podle pravd�podobnosti, �e pr�v� ony jsou povinn�mi dopln�n�mi slovesa.
    # "Pravd�podobnost�" se zde nemysl� jen v�ha podle modelu, ale p�i nerozhodnosti i dal�� heuristiky.
    my @sdeti = sort
    {
        my $vysledek = $b->{vaha}<=>$a->{vaha};
        unless($vysledek)
        {
            $vysledek = $a->{vnitrni}<=>$b->{vnitrni};
            unless($vysledek)
            {
                $vysledek = $a->{vzdalenost}<=>$b->{vzdalenost};
                unless($vysledek)
                {
                    $vysledek = $a->{vnejsi}<=>$b->{vnejsi};
                    unless($vysledek)
                    {
                        $vysledek = $a->{index}<=>$b->{index};
                    }
                }
            }
        }
        return $vysledek;
    }
    (@{$deti});
    # Vytvo�it si kopii r�mce, abychom si v n� mohli �m�rat.
    my %ramec = %{$ramec};
    # Proch�zet d�ti a u ka�d�ho se zeptat, jestli je povinn� (umaz�v�n�m p��slu�n�ch zna�ek z r�mce).
    # PR4 uspokoj� p�ednostn� po�adavek na PR4, ale pokud takov� po�adavek nen�, zkus� uspokojit po�adavek na N4.
    for(my $i = 0; $i<=$#sdeti; $i++)
    {
        if($ramec{$sdeti[$i]{vznacka}})
        {
            # Poznamenat si, �e tento �len r�mce u� je napln�n.
            $ramec{$sdeti[$i]{vznacka}}--;
            # Poznamenat si, �e tento uzel u� je anga�ov�n jako povinn� dopln�n�.
            $sdeti[$i]{arg} = 1;
        }
        elsif($sdeti[$i]{vznacka} eq "PR4" && $ramec{"N4"})
        {
            # Poznamenat si, �e tento �len r�mce u� je napln�n.
            $ramec{"N4"}--;
            # Poznamenat si, �e tento uzel u� je anga�ov�n jako povinn� dopln�n�.
            $sdeti[$i]{arg} = 1;
        }
    }
    # Sestavit n�vratov� �daje a vr�tit je.
    my %srovnani;
    while(my ($klic, $hodnota) = each(%ramec))
    {
        $srovnani{n_chybi} += $hodnota;
    }
    $srovnani{chybi} = \%ramec;
    my @nalezeno = map{$_->{index}}(grep{$_->{arg}}(@sdeti));
    $srovnani{nalezeno} = \@nalezeno;
    return \%srovnani;
}



#==============================================================================
# Pomocn� funkce, ze kter�ch by se �asem m�l vytvo�it samostatn� modul pro
# odst�n�n� zvl�tnost� jazyka nebo zna�en� v konkr�tn�m korpusu.
#==============================================================================



#------------------------------------------------------------------------------
# Zjist� z anotace slova, zda jde o sloveso.
#------------------------------------------------------------------------------
sub je_sloveso
{
    my $anot = shift;
    return $anot->{znacka} =~ m/^V/;
}



1;
