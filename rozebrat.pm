package rozebrat;
use debug;
use zakaz;
use genstav;
use stav;
use subkat;
use nepreskocv;



#------------------------------------------------------------------------------
# Vybuduje z�vislostn� strukturu v�ty.
# Tady se sna��m oprostit p�vodn� funkci rozebrat_vetu() od glob�ln�ch prom�nn�ch.
#------------------------------------------------------------------------------
sub rozebrat_vetu
{
    # Voliteln� lze jako parametr dodat v�sledek ��ste�n� anal�zy jin�mi
    # prost�edky. V tom p��pad� funkce dopln� rodi�e jen t�m uzl�m, kter� je
    # dosud nemaj�.
    my $analyza0 = shift;
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zalo�it strukturu se stavem anal�zy a vyplnit do n� po��te�n� hodnoty.
    my $stav = vytvorit_pocatecni_stav($analyza0);
    while($stav->{zbyva}>0)
    {
        # Pro ka�dou povolenou hranu vygenerovat stav odpov�daj�c� p�id�n� t�to hrany do stromu.
        my $nove_stavy = genstav::generovat_stavy($stav, 0);
        # Prvn� prvek pole je stav, kter� m� zv�t�zit. Z�lo�n� n�vrhy zat�m ignorovat a zahodit.
        $stav = $nove_stavy->[0];
    }
    # Prov��it, zda se n�co nem�lo ud�lat rad�ji jinak.
    $stav = backtrack($stav);
    return $stav;
}



#------------------------------------------------------------------------------
# Zjist�, zda je ve strom� n�co v nepo��dku, co by si zaslou�ilo p�ehodnocen�
# anal�zy, a doporu�� stav, ke kter�mu by se anal�za m�la vr�tit. Pokud strom
# vypad� dob�e, vr�t� 0.
#------------------------------------------------------------------------------
sub backtrack
{
    my $stav = shift; # odkaz na hash s dosavadn�m stavem anal�zy
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    ### Prov��it napln�nost subkategoriza�n�ch r�mc� - zat�m hodn� pokusn�!
    # Jestli�e se zjist�, �e n�kter� sloveso nem� napln�n� subkategoriza�n� r�mec,
    # ve v�t� je materi�l, kter�m by mohlo j�t tento r�mec naplnit, a je�t�
    # existuj� n�jak� nevyzkou�en� stavy anal�zy, vr�tit se k t�mto stav�m.
    if($konfig->{valence1} && subkat::najit_nenaplnene_ramce($konfig->{nacteny_subkategorizacni_slovnik}, $stav))
    {
        # Zat�m lad�n�. Zjistit, co p�esn� by n�m ve v�t� mohlo pomoci s napln�n�m valence.
        my $evidence = subkat::najit_valencni_rezervy($anot, $stav, $konfig->{nacteny_subkategorizacni_slovnik});
        if(join("", @{$evidence}) =~ m/1/)
        {
            print("\n", join("", @{$evidence}), "\n");
            # Tady si budeme pamatovat zpracovan� i z�lo�n� stavy.
            my %prehled;
            # Nejd��v zopakovat anal�zu a zapamatovat si stavy, ke kter�m bychom se mohli vr�tit.
            # Standardn� to ned�l�me, proto�e to zab�r� moc �asu.
            $stav = vytvorit_pocatecni_stav($analyza0);
            while($stav->{zbyva}>0)
            {
                # Pro ka�dou povolenou hranu vygenerovat stav odpov�daj�c� p�id�n� t�to hrany do stromu.
                my $nove_stavy = genstav::generovat_stavy($stav, 1);
                # Zapamatovat si, �e dosavadn� stav byl zpracov�n a vy�d�m�n.
                $stav->{zpracovano} = 1;
                # Zapamatovat si odkazy na v�echny nov� stavy. Pokud n�kter� nov� stav
                # obsahuje stejn� strom jako n�kter� u� zn�m� stav, neukl�dat strom dvakr�t.
                # Pouze se pod�vat, jestli nov� stav neposkytuje dan�mu stromu lep�� v�hu,
                # v�t�ze schovat a pora�en�ho zahodit.
                for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
                {
                    my $hashvalue = join(",", @{$nove_stavy->[$i]{rodic}});
                    if(exists($prehled{$hashvalue}))
                    {
                        if($prehled{$hashvalue}{vaha}<$nove_stavy->[$i]{vaha} &&
                           !$prehled{$hashvalue}{zpracovano})
                        {
                            $prehled{$hashvalue} = $nove_stavy->[$i];
                        }
                    }
                    else
                    {
                        $prehled{$hashvalue} = $nove_stavy->[$i];
                    }
                }
                # Prvn� prvek pole je stav, kter� m� zv�t�zit.
                $stav = $nove_stavy->[0];
            }
            my $puvodni_vysledny_stav = $stav;
            my @fronta_stavu;
            my $n_navratu;
            print("\n");
            while(subkat::najit_nenaplnene_ramce($konfig->{nacteny_subkategorizacni_slovnik}, $stav))
            {
                print("NAVRAT CISLO ", ++$n_navratu, "\n");
                # Se�adit z�lo�n� stavy sestupn� podle v�hy (pozor, odfiltrovat zpracovan� stavy!)
                @fronta_stavu = keys(%prehled);
                my $n_stavu_celkem = $#fronta_stavu+1;
                print("V prehledu je $n_stavu_celkem stavu.\n");
                @fronta_stavu = grep{!$prehled{$_}{zpracovano}}(@fronta_stavu);
                # Proj�t nezpracovan� stavy a ozna�it ty, kter� n�m neslibuj� nic
                # nov�ho, za zpracovan�.
                foreach my $stavstrom (@fronta_stavu)
                {
                    my $stav = $prehled{$stavstrom};
                    if(1)
                    {
                        # Zaj�mav� jsou pouze stavy t�sn� po zav�en� n�kter�ho nad�jn�ho uzlu.
                        unless($evidence->[$stav->{poslz}]==1)
                        {
                            # Kv�li �spo�e pam�ti �pln� vypr�zdnit zavr�en� stav t�m, �e zalo��me
                            # nov� hash, kter� bude obsahovat pouze p��znak {zpracovano}, a odkazem
                            # na n�j p�ep�eme odkaz na dosavadn� hash.
                            my %stav1;
                            $stav1{zpracovano} = 1;
                            $prehled{$stavstrom} = $stav = \%stav1;
                        }
                    }
                    else
                    {
                        my $nalezeno = 0;
                        for(my $i = 0; $i<=$#{$evidence}; $i++)
                        {
                            # Naj�t aspo� jeden uzel, kter� je veden jako nad�jn� a v tomto stavu je�t� nen� zav�en.
                            if($evidence->[$i]==1 && $stav->{rodic}[$i]==-1)
                            {
                                $nalezeno = 1;
                                last;
                            }
                        }
                        unless($nalezeno)
                        {
                            $stav->{zpracovano} = 1;
                        }
                    }
                }
                # Znova vyh�zet z fronty zpracovan� stavy.
                @fronta_stavu = grep{!$prehled{$_}{zpracovano}}(@fronta_stavu);
                print("Z toho ", $#fronta_stavu+1, " jeste nebylo zpracovano.\n");
                @fronta_stavu = sort{$prehled{$b}{vaha}<=>$prehled{$a}{vaha}}(@fronta_stavu);
                # Jestli�e nezb�vaj� ��dn� z�lo�n� stavy a st�le nen� spln�na valen�n� podm�nka, vr�tit se k p�vodn�mu v�sledku.
                # Tot� ud�lat, jestli�e jsme dos�hli maxim�ln�ho povolen�ho po�tu n�vrat�
                # nebo maxim�ln�ho povolen�ho po�tu nagenerovan�ch stav�.
                if(!@fronta_stavu ||
                   $konfig->{valence1_maxnavratu} ne "" && $n_navratu>$konfig->{valence1_maxnavratu} ||
                   $konfig->{valence1_maxgenstav} ne "" && $n_stavu_celkem>$konfig->{valence1_maxgenstav})
                {
                    print("Bu� do�ly stavy, nebo byl p�ekro�en povolen� po�et n�vrat�.\n");
                    $stav = $puvodni_vysledny_stav;
                    last;
                }
                # Vr�tit se k dosud nevyzkou�en�mu stavu.
                $stav = $prehled{$fronta_stavu[0]};
                # Znova od tohoto stavu budovat strom. (Cel� while je kopi� obdobn�ho k�du o p�r ��dk� v��e,
                # m�la by na to b�t funkce.)
                while($stav->{zbyva}>0)
                {
                    # Pro ka�dou povolenou hranu vygenerovat stav odpov�daj�c� p�id�n� t�to hrany do stromu.
                    my $nove_stavy = genstav::generovat_stavy($stav, 1);
                    # Zapamatovat si, �e dosavadn� stav byl zpracov�n a vy�d�m�n.
                    $stav->{zpracovano} = 1;
                    # Zapamatovat si odkazy na v�echny nov� stavy. Pokud n�kter� nov� stav
                    # obsahuje stejn� strom jako n�kter� u� zn�m� stav, neukl�dat strom dvakr�t.
                    # Pouze se pod�vat, jestli nov� stav neposkytuje dan�mu stromu lep�� v�hu,
                    # v�t�ze schovat a pora�en�ho zahodit.
                    for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
                    {
                        my $hashvalue = join(",", @{$nove_stavy->[$i]{rodic}});
                        if(exists($prehled{$hashvalue}))
                        {
                            # Jestli�e jsme p�irozen�m procesem z�skali stav, kter� u� byl v n�jak�m minul�m procesu
                            # nalezen a zpracov�n, vylou�it ho z nov�ch stav�. Na �adu p�ijde dal�� n�hradn�k.
                            if($prehled{$hashvalue}{zpracovano})
                            {
                                if($i==0)
                                {
                                    shift(@{$nove_stavy});
                                    $i--;
                                }
                            }
                            else
                            {
                                if($prehled{$hashvalue}{vaha}<$nove_stavy->[$i]{vaha})
                                {
                                    $prehled{$hashvalue} = $nove_stavy->[$i];
                                }
                            }
                        }
                        else
                        {
                            $prehled{$hashvalue} = $nove_stavy->[$i];
                        }
                    }
                    # Prvn� prvek pole je stav, kter� m� zv�t�zit.
                    # Pokud n�m ov�em po p�edch�zej�c� �istce v�bec n�jak� zbyl.
                    if($#{$nove_stavy}>=0)
                    {
                        $stav = $nove_stavy->[0];
                    }
                    else
                    {
                        $stav = $puvodni_vysledny_stav;
                    }
                }
                # Pokud jsme do p�edch�zej�c� smy�ky v�bec nevkro�ili, n� stav nen� ozna�en jako zpracovan�!
                # Ozna�it ho, nebo ho budeme dost�vat po��d dokola!
                $stav->{zpracovano} = 1;
            }
            print("Jsme venku z valencni smycky. Pokud nedosly stavy, valence je naplnena!\n");
            print("zasmyckou:", join(",", @{$stav->{rodic}}), "\n");
        }
    }
konec_valencniho_backtrackingu:
    # Zjistit, kolik d�t� m� ko�en. Pokud jich bude m�t v�c ne� 2, �e�it.
    my $n_deti_korene = $stav->{ndeti}[0];
    if($konfig->{koren_2_deti} && $n_deti_korene>2)
    {
        # Vybrat z d�t� to nejpravd�podobn�j��. Posledn� uzel vynechat, mohla
        # by to b�t koncov� interpunkce.
        my $maxp;
        my $imaxp;
        for(my $i = 0; $i<$#{$anot}; $i++)
        {
            if($stav->{rodic}[$i]==0)
            {
                my $p = model::ud("OZZ $stav->{uznck}[0] $stav->{uznck}[$i] V D");
                if($maxp eq "" || $p>$maxp)
                {
                    $maxp = $p;
                    $imaxp = $i;
                }
            }
        }
        # V�echny d�ti krom� v�t�ze a posledn�ho uzlu odpojit. Jejich z�vislost
        # na ko�eni d�t na �ernou listinu.
        for(my $i = 0; $i<$#{$anot}; $i++)
        {
            if($stav->{rodic}[$i]==0 && $i!=$imaxp)
            {
                stav::zrusit_zavislost($stav, $i);
                zakaz::pridat_zakaz(\$stav->{zakaz}, 0, $i, "ko�en");
            }
        }
        # Odpojen� uzly znova n�kam zav�sit.
        while($stav->{zbyva}>0)
        {
            # Pro ka�dou povolenou hranu vygenerovat stav odpov�daj�c� p�id�n� t�to hrany do stromu.
            my $nove_stavy = genstav::generovat_stavy($stav, 0);
            # Prvn� prvek pole je stav, kter� m� zv�t�zit. Z�lo�n� n�vrhy zat�m ignorovat a zahodit.
            $stav = $nove_stavy->[0];
        }
    }
    return $stav;
}



#------------------------------------------------------------------------------
# Nastav� po��te�n� stav anal�zy.
#------------------------------------------------------------------------------
sub vytvorit_pocatecni_stav
{
    # Voliteln� lze jako parametr dodat v�sledek ��ste�n� anal�zy jin�mi
    # prost�edky. V tom p��pad� funkce dopln� rodi�e jen t�m uzl�m, kter� je
    # dosud nemaj�.
    my $analyza0 = shift;
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zalo�it bal��ek se v�emi �daji o stavu anal�zy.
    my %stav;
    # Nejd�le�it�j�� ��st stavu je ��ste�n� vybudovan� strom. Reprezentuje ho pole odkaz� na rodi�e.
    # Na za��tku nastavit index rodi�e ka�d�ho uzlu na -1.
    @{$stav{rodic}} = map{-1}(0..$#{$anot});
    $stav{nprid} = 0; # po�ad� naposledy p�idan�ho uzlu (prvn� p�idan� uzel m� jedni�ku)
    $stav{zbyva} = $#{$anot}; # Pokrok v anal�ze je ��zen touto prom�nnou. P�edpokl�d�, �e po�et uzl� ve v�t� se nem�n�!
    # Stav anal�zy si udr�uje svou vlastn� kopii morfologick�ch zna�ek jednotliv�ch
    # uzl�. Tyto zna�ky se mohou m�nit i v pr�b�hu syntaktick� anal�zy. Nap�. se
    # m��e zjistit, �e zna�ka navr�en� taggerem by poru�ovala shodu. U ko�en� koordinace
    # se ihned po sestaven� koordinace vypln� morfologick� zna�ka n�kter�ho �lena
    # koordinace. Atd. Ve�ker� pravidla a statistick� modely by se b�hem anal�zy
    # m�la d�vat na zna�ku ulo�enou ve stavu. Pro pou�it� p�vodn� zna�ky by musel
    # b�t dobr� d�vod.
    @{$stav{uznck}} = map{$_->{uznacka}}(@{$anot});
    # P�id�n� n�kter�ch z�vislost� m��e b�t zak�z�no, pokud nebo dokud nejsou spln�ny ur�it� podm�nky. Tyto z�kazy
    # jsou v�t�inou motivov�ny lingvisticky, z�vis� na konkr�tn�m obsahu v�ty a maj� p�ednost p�ed seznamem povolen�ch
    # z�vislost� (kter� je vymezen matematicky, aby to byl projektivn� strom). Na konci mohou b�t z�kazy zru�eny, pokud
    # by br�nili dokon�en� alespo� n�jak�ho stromu. Nyn� vytvo��me po��te�n� mno�inu z�kaz�.
    my @prislusnost_k_useku; $stav{prislusnost_k_useku} = \@prislusnost_k_useku; # pro ka�d� uzel ��slo mezi��rkov�ho �seku
    my @hotovost_useku; $stav{hotovost_useku} = \@hotovost_useku; # pro ka�d� �sek p��znak, zda u� je jeho podstrom hotov�
    zakaz::formulovat_zakazy(\%stav);
    # Jestli�e u� m�me ��ste�n� rozbor v�ty, zapracovat ho do stavu.
    for(my $i = 0; $i<=$#{$analyza0}; $i++)
    {
        if($analyza0->[$i] ne "" && $analyza0->[$i]!=-1)
        {
            stav::pridat_zavislost(\%stav, {"r" => $analyza0->[$i], "z" => $i, "c" => 0, "p" => 1});
        }
    }
    # Vytipovat z�vislosti, kter� by mohly naplnit subkategoriza�n� r�mce sloves.
    if($konfig->{valence})
    {
        $stav{valencni} = subkat::vytipovat_valencni_zavislosti($konfig->{nacteny_subkategorizacni_slovnik});
    }
    # Naj�t z�vislosti, kter�m nem� b�t dovoleno p�esko�it sloveso.
    if($konfig->{nepreskocv})
    {
        $stav{zakaz} = nepreskocv::najit_ve_vete($konfig->{nacteny_seznam_zakazu_preskoceni_slovesa}, $anot, $stav{zakaz});
    }
    $stav{zpracovano} = 0;
    return \%stav;
}



1;
